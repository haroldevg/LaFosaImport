import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import 'pricing_config.dart';

/// Thrown by [OrderService.createOrder] when the user already has an order
/// that isn't delivered/cancelled yet.
class ActiveOrderExistsException implements Exception {}

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

  /// Whether the app is closed to non-admin users (set manually in Firestore
  /// at `config/settings.closed`, e.g. once a promotional intake period
  /// ends). Defaults to false when the field or document is absent.
  Stream<bool> appClosed() {
    return _db
        .collection('config')
        .doc('settings')
        .snapshots()
        .map((doc) => doc.data()?['closed'] == true);
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
    final rate = fixedTaxRate;
    final rawSubtotal = items.fold<double>(
      0,
      (acc, item) => acc + item.lineTotal,
    );
    final subtotal = double.parse(rawSubtotal.toStringAsFixed(2));
    final tax = double.parse((subtotal * rate).toStringAsFixed(2));
    final margin = isAdminUser
        ? 0.0
        : double.parse(
            items
                .fold<double>(0, (acc, item) => acc + marginAmountForItem(item))
                .toStringAsFixed(2),
          );
    final totalQuantity = items.fold<int>(
      0,
      (acc, item) => acc + item.quantity,
    );
    final internationalShipping = double.parse(
      (totalQuantity * internationalShippingFeeFor(isAdminUser))
          .toStringAsFixed(2),
    );
    final total = double.parse(
      (subtotal + tax + margin + internationalShipping).toStringAsFixed(2),
    );

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
        'items': items.map((item) => item.toMap()).toList(),
        'estimatedTaxRate': rate,
        'estimatedSubtotal': subtotal,
        'estimatedTax': tax,
        'estimatedMargin': margin,
        'estimatedInternationalShipping': internationalShipping,
        'estimatedTotal': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {'activeOrderId': orderRef.id});
      return false;
    });
    if (hasActiveOrder) throw ActiveOrderExistsException();
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
