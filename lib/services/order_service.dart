import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import 'mail_service.dart';
import 'pricing_config.dart';

/// Thrown by [OrderService.createOrder] when the user already has an order
/// that isn't delivered/cancelled yet.
class ActiveOrderExistsException implements Exception {}

/// Outcome of [OrderService.applyPriceAdjustment]. The order is already
/// saved by the time this comes back; [emailError] is non-null only when the
/// customer notification couldn't be queued, which is worth telling the staff
/// about (so they can reach out another way) but never undoes the reprice —
/// the customer still sees the request in the app.
class PriceAdjustmentResult {
  final OrderTotals totals;
  final String? notifiedEmail;
  final String? emailError;

  const PriceAdjustmentResult({
    required this.totals,
    this.notifiedEmail,
    this.emailError,
  });

  bool get emailQueued => emailError == null;
}

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final _db = FirebaseFirestore.instance;

  /// The user's current active order (not delivered/cancelled), or null.
  Stream<CardOrder?> activeOrder(String uid) {
    return _db.collection('users').doc(uid).snapshots().asyncMap((
      userDoc,
    ) async {
      final activeOrderId = userDoc.data()?['activeOrderId'] as String?;
      if (activeOrderId == null || activeOrderId.isEmpty) return null;
      final orderDoc = await _db.collection('orders').doc(activeOrderId).get();
      if (!orderDoc.exists) return null;
      return CardOrder.fromFirestore(orderDoc);
    });
  }

  Stream<List<CardOrder>> orderHistory(String uid) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CardOrder.fromFirestore).toList());
  }

  Stream<List<CardOrder>> allOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CardOrder.fromFirestore).toList());
  }

  Stream<bool> isAdmin(String uid) {
    return _db
        .collection('roles')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['isAdmin'] == true);
  }

  /// Whether the app is closed to non-admin users — the switch that ends (or
  /// reopens) an intake period, toggled by the staff from the admin panel and
  /// stored at `config/settings.closed`. Defaults to false when the field or
  /// document is absent.
  Stream<bool> appClosed() {
    return _db
        .collection('config')
        .doc('settings')
        .snapshots()
        .map((doc) => doc.data()?['closed'] == true);
  }

  /// Admin-only: opens or closes the convocatoria for every non-admin user,
  /// live. Merged rather than overwritten so any other setting that ends up
  /// in this document survives the toggle, and it works whether or not the
  /// document exists yet.
  Future<void> setAppClosed(bool closed) async {
    await _db.collection('config').doc('settings').set({
      'closed': closed,
      'closedUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates a new order request (a cart of one or more [items]) in a single
  /// atomic transaction: it fails with [ActiveOrderExistsException] if the
  /// user already has one active. Firestore's own transaction
  /// retry-on-conflict is what makes this safe under concurrent submissions,
  /// not any server-side code.
  Future<void> createOrder({required List<OrderItem> items}) async {
    assert(items.isNotEmpty);
    final user = FirebaseAuth.instance.currentUser!;
    final roleSnap = await _db.collection('roles').doc(user.uid).get();
    final isAdminUser = roleSnap.data()?['isAdmin'] == true;
    final totals = OrderTotals.forItems(items, adminPricing: isAdminUser);

    final userRef = _db.collection('users').doc(user.uid);
    final orderRef = _db.collection('orders').doc();

    // Returning a sentinel (rather than throwing inside the transaction
    // callback) and throwing afterwards, in plain Dart, avoids a
    // cloud_firestore_web bug where an exception thrown inside a transaction
    // loses its type crossing the JS interop boundary — the caller then only
    // sees a generic "Dart exception thrown from converted Future" instead
    // of being able to catch ActiveOrderExistsException.
    final hasActiveOrder = await _db.runTransaction<bool>((tx) async {
      final userSnap = await tx.get(userRef);
      final currentActiveId = userSnap.data()?['activeOrderId'] as String?;
      if (currentActiveId != null && currentActiveId.isNotEmpty) {
        return true;
      }

      tx.set(orderRef, {
        'userId': user.uid,
        'userDisplayName': user.displayName ?? user.email ?? '',
        // Kept on the order itself so a later reprice can email the customer
        // without having to go read their profile doc.
        'userEmail': user.email ?? '',
        // Which fee schedule this quote was built on, so a reprice months
        // later reapplies the same one even if the user's role changed.
        'ownerIsAdmin': isAdminUser,
        'items': items.map((item) => item.toMap()).toList(),
        'estimatedTaxRate': totals.taxRate,
        'estimatedSubtotal': totals.subtotal,
        'estimatedTax': totals.tax,
        'estimatedMargin': totals.margin,
        'estimatedInternationalShipping': totals.internationalShipping,
        'estimatedTotal': totals.total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {'activeOrderId': orderRef.id});
      return false;
    });
    if (hasActiveOrder) throw ActiveOrderExistsException();
  }

  /// Admin-only: rewrites the prices of an already-placed order (TCGPlayer
  /// prices move constantly, so what the customer was quoted often isn't
  /// buyable by the time the staff gets to it), recalculates every derived
  /// figure with the exact schedule the order was originally quoted on, and
  /// parks it in [OrderStatus.priceReview] so the customer has to approve the
  /// new total before anyone buys it. The customer is emailed the difference.
  Future<PriceAdjustmentResult> applyPriceAdjustment({
    required CardOrder order,
    required List<OrderItem> items,
    String? note,
  }) async {
    assert(items.isNotEmpty);
    final admin = FirebaseAuth.instance.currentUser!;
    final totals = OrderTotals.forItems(
      items,
      adminPricing: order.usesAdminPricing,
    );
    final trimmedNote = note?.trim();
    final customerEmail = await _resolveCustomerEmail(order);

    await _db.collection('orders').doc(order.id).update({
      'items': items.map((item) => item.toMap()).toList(),
      'estimatedTaxRate': totals.taxRate,
      'estimatedSubtotal': totals.subtotal,
      'estimatedTax': totals.tax,
      'estimatedMargin': totals.margin,
      'estimatedInternationalShipping': totals.internationalShipping,
      'estimatedTotal': totals.total,
      'status': OrderStatus.priceReview.name,
      if (customerEmail != null && order.userEmail.isEmpty)
        'userEmail': customerEmail,
      'priceAdjustment': {
        'previousTotal': order.estimatedTotal,
        'newTotal': totals.total,
        'note': (trimmedNote == null || trimmedNote.isEmpty)
            ? null
            : trimmedNote,
        'adjustedByName': admin.displayName ?? admin.email ?? '',
        // Client clock rather than a server sentinel: this one is nested in a
        // map and only ever displayed, so it isn't worth relying on sentinel
        // support inside nested writes across the native/web SDKs.
        'adjustedAt': Timestamp.now(),
        'respondedAt': null,
        'accepted': null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (customerEmail == null || customerEmail.isEmpty) {
      return PriceAdjustmentResult(
        totals: totals,
        emailError: 'el pedido no tiene un correo asociado',
      );
    }

    // The order is already saved; a mail failure is reported, never rolled
    // back — the customer still gets the same request inside the app.
    try {
      await MailService.instance.sendPriceAdjustmentNotice(
        to: customerEmail,
        order: order,
        items: items,
        totals: OrderTotalsSummary(
          subtotal: totals.subtotal,
          tax: totals.tax,
          margin: totals.margin,
          internationalShipping: totals.internationalShipping,
          previousTotal: order.estimatedTotal,
          newTotal: totals.total,
        ),
        note: trimmedNote,
      );
      return PriceAdjustmentResult(
        totals: totals,
        notifiedEmail: customerEmail,
      );
    } catch (e) {
      return PriceAdjustmentResult(
        totals: totals,
        notifiedEmail: customerEmail,
        emailError: '$e',
      );
    }
  }

  /// The email a price-adjustment notice should go to: the copy stored on the
  /// order, falling back to the profile doc for orders placed before that
  /// field existed. Never throws — a missing address is reported by
  /// [applyPriceAdjustment] instead of blocking the reprice.
  Future<String?> _resolveCustomerEmail(CardOrder order) async {
    if (order.userEmail.isNotEmpty) return order.userEmail;
    try {
      final userSnap = await _db.collection('users').doc(order.userId).get();
      final email = userSnap.data()?['email'] as String?;
      return (email == null || email.isEmpty) ? null : email;
    } catch (_) {
      return null;
    }
  }

  /// Customer-side answer to a staff reprice: accepting clears the order for
  /// the staff to buy ([OrderStatus.priceConfirmed]), rejecting cancels it
  /// and frees the customer to place a new one.
  Future<void> respondToPriceAdjustment(
    CardOrder order, {
    required bool accepted,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('orders').doc(order.id).update({
      'status': accepted
          ? OrderStatus.priceConfirmed.name
          : OrderStatus.cancelled.name,
      'priceAdjustment.accepted': accepted,
      'priceAdjustment.respondedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accepted) return;
    // Release the one-active-order lock. Done as a separate write, after the
    // order is already cancelled, because that's exactly what the security
    // rule checks: a user may only null out a lock that points at a finished
    // order.
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    if (userSnap.data()?['activeOrderId'] == order.id) {
      await userRef.update({'activeOrderId': null});
    }
  }

  /// Admin-only: changes an order's status. Firestore rules enforce the
  /// admin check server-side regardless of what the client sends.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final clearsLock =
        newStatus == OrderStatus.delivered ||
        newStatus == OrderStatus.cancelled;

    await _db.runTransaction((tx) async {
      // All reads must happen before any writes in a Firestore transaction,
      // so resolve the conditional user lookup before writing anything.
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) return;
      final orderData = orderSnap.data()!;

      DocumentReference<Map<String, dynamic>>? userRef;
      DocumentSnapshot<Map<String, dynamic>>? userSnap;
      if (clearsLock) {
        userRef = _db.collection('users').doc(orderData['userId'] as String);
        userSnap = await tx.get(userRef);
      }

      tx.update(orderRef, {
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userRef != null && userSnap?.data()?['activeOrderId'] == orderId) {
        tx.update(userRef, {'activeOrderId': null});
      }
    });
  }
}
