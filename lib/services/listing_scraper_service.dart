import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// One seller listing scraped from a TCGPlayer product page.
class ScrapedListing {
  final String sellerName;
  final String condition;
  final double itemPrice;
  final double shipping;

  /// Units the seller has in stock, or null if the page didn't expose it
  /// (in which case the quantity picker in the UI is left unbounded).
  final int? stock;

  const ScrapedListing({
    required this.sellerName,
    required this.condition,
    required this.itemPrice,
    required this.shipping,
    this.stock,
  });

  double get totalPrice => itemPrice + shipping;
}

/// Result of scraping a TCGPlayer product page: the card/set name (read once
/// from the page itself) plus whatever seller listings were found.
class ScrapeResult {
  final String cardName;
  final String setName;
  final List<ScrapedListing> listings;

  const ScrapeResult({
    required this.cardName,
    required this.setName,
    required this.listings,
  });

  static const empty = ScrapeResult(cardName: '', setName: '', listings: []);
}

/// JS extraction script for TCGPlayer's product listing page, based on the
/// real DOM structure (`section.listing-item`, etc.) and the page's own
/// schema.org JSON-LD block for the card name — this is a best-effort
/// scrape: TCGPlayer can change this markup at any time without notice, in
/// which case this returns no listings and the caller falls back to the
/// manual entry form. There is no guarantee this keeps working.
const _extractionScript = '''
(function() {
  function parseMoney(text) {
    var m = (text || '').replace(/,/g, '').match(/\\d+\\.\\d{2}/);
    return m ? parseFloat(m[0]) : null;
  }

  var cardName = '';
  var setName = '';
  try {
    var ld = document.querySelector('script[type="application/ld+json"]');
    if (ld) {
      var data = JSON.parse(ld.textContent);
      cardName = (data.name || '').trim();
    }
  } catch (e) {}
  // The page <title> is "{cardName} - {setName} - {game} - TCGplayer.com".
  // Some card names contain their own " - " (e.g. "Hero - Subtitle"), so
  // strip the already-known cardName off the front first instead of just
  // splitting the whole title — otherwise the set name extraction picks up
  // a fragment of the card name.
  var title = document.title || '';
  if (!cardName) {
    var titleParts = title.split(' - ');
    if (titleParts.length > 0) cardName = titleParts[0].trim();
  }
  var rest = title;
  if (cardName && rest.indexOf(cardName) === 0) {
    rest = rest.slice(cardName.length);
  }
  var restParts = rest.split(' - ').map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
  if (restParts.length > 0) setName = restParts[0];

  var items = Array.from(document.querySelectorAll('section.listing-item')).slice(0, 10).map(function(item) {
    var priceEl = item.querySelector('.listing-item__listing-data__info__price');
    var shippingEl = item.querySelector('.listing-item__listing-data__info__shipping-message');
    var conditionEl = item.querySelector('.listing-item__condition');
    var sellerEl = item.querySelector('.seller-info__name');
    var availEl = item.querySelector('.add-to-cart__available');
    var price = priceEl ? parseMoney(priceEl.textContent) : null;
    var shippingText = shippingEl ? shippingEl.textContent : '';
    var shipping = /included/i.test(shippingText) ? 0 : (parseMoney(shippingText) || 0);
    var stockMatch = availEl ? availEl.textContent.match(/\\d+/) : null;
    return {
      seller: sellerEl ? sellerEl.textContent.trim() : '',
      condition: conditionEl ? conditionEl.textContent.trim().replace(/\\s+/g, ' ') : '',
      price: price,
      shipping: shipping,
      stock: stockMatch ? parseInt(stockMatch[0], 10) : null
    };
  }).filter(function(x) { return x.seller && x.price != null; });

  return JSON.stringify({ cardName: cardName, setName: setName, listings: items });
})();
''';

class ListingScraperService {
  ListingScraperService._();
  static final ListingScraperService instance = ListingScraperService._();

  bool looksLikeTcgplayerUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.host == 'www.tcgplayer.com' || uri.host == 'tcgplayer.com') &&
        uri.path.contains('/product/');
  }

  /// Best-effort scrape: loads [url] in an off-screen WebView on the user's
  /// own device (no server involved) and reads the already-rendered card
  /// name/set and listing rows. Always returns — empty listings means
  /// "couldn't get it, use the manual form", never throws for a scrape
  /// failure.
  Future<ScrapeResult> fetchListings(BuildContext context, String url) async {
    if (!looksLikeTcgplayerUrl(url)) return ScrapeResult.empty;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    final pageFinished = Completer<void>();
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!pageFinished.isCompleted) pageFinished.complete();
        },
      ),
    );

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: WebViewWidget(controller: controller),
        ),
      ),
    );
    overlay.insert(entry);

    try {
      await pageFinished.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );

      // The listings table renders asynchronously after the initial page
      // load, so poll for it instead of trusting a single fixed delay.
      var result = ScrapeResult.empty;
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (DateTime.now().isBefore(deadline)) {
        result = await _extract(controller);
        if (result.listings.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }
      return result;
    } catch (_) {
      return ScrapeResult.empty;
    } finally {
      entry.remove();
    }
  }

  Future<ScrapeResult> _extract(WebViewController controller) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        _extractionScript,
      );
      var jsonText = raw.toString();
      // Android's webview_flutter wraps string results in an extra layer of
      // JSON-encoded quotes; unwrap it if present.
      if (jsonText.startsWith('"') && jsonText.endsWith('"')) {
        jsonText = jsonDecode(jsonText) as String;
      }
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final listings = (decoded['listings'] as List<dynamic>).map((raw) {
        final map = raw as Map<String, dynamic>;
        return ScrapedListing(
          sellerName: map['seller'] as String,
          condition: map['condition'] as String? ?? '',
          itemPrice: (map['price'] as num).toDouble(),
          shipping: (map['shipping'] as num?)?.toDouble() ?? 0,
          stock: (map['stock'] as num?)?.toInt(),
        );
      }).toList();
      return ScrapeResult(
        cardName: decoded['cardName'] as String? ?? '',
        setName: decoded['setName'] as String? ?? '',
        listings: listings,
      );
    } catch (_) {
      return ScrapeResult.empty;
    }
  }
}
