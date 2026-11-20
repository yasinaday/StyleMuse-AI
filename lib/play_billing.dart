import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PlayVerification {
  const PlayVerification({required this.credited, required this.consumed});
  final bool credited;
  final bool consumed;
}

typedef VerifyPlayPurchase = Future<PlayVerification> Function(
    String product, String token);

/// Android only. Server owns credit and consumption; never credit local storage.
/// Create per authenticated account and dispose on logout/account change.
class PlayBillingController extends ChangeNotifier {
  PlayBillingController({required this.verify, InAppPurchase? billing})
      : _billing = billing;
  final VerifyPlayPurchase verify;
  final InAppPurchase? _billing;
  InAppPurchase get billing => _billing ?? InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, PurchaseDetails> _retry = {};
  List<ProductDetails> products = [];
  Map<String, int> tokensByProduct = {};

  ProductDetails? productFor(int count) {
    for (final product in products) {
      if (tokensByProduct.isNotEmpty
          ? tokensByProduct[product.id] == count
          : product.id == 'style_tokens_$count' || product.id == 'tokens_$count') {
        return product;
      }
    }
    return null;
  }
  String state = 'unavailable';
  String? _account;
  bool _disposed = false;

  Future<void> initialize(
      {required String accountId, required Set<String> productIds}) async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        kIsWeb ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(accountId) ||
        productIds.isEmpty) {
      throw StateError('play_not_configured');
    }
    _account = accountId;
    _subscription ??= billing.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        await handle(purchase);
      }
    }, onError: (Object _) => _setState('retry_required'));
    if (!await billing.isAvailable()) {
      _setState('unavailable');
      return;
    }
    final result = await billing.queryProductDetails(productIds);
    if (result.error != null ||
        result.productDetails.isEmpty) {
      products = [];
      _setState('catalog_unavailable');
      return;
    }
    products = result.productDetails;
    _setState('ready');
    await recover();
  }

  /// Display ProductDetails.price verbatim: currency/format come from Play.
  Future<bool> buy(ProductDetails product) async {
    if (_disposed || _account == null || !products.contains(product)) {
      throw StateError('play_not_ready');
    }
    if (!['ready', 'credited', 'cancelled', 'launch_failed'].contains(state)) return false;
    _setState('launching');
    try {
      final launched = await billing.buyConsumable(
      purchaseParam:
          PurchaseParam(productDetails: product, applicationUserName: _account),
        autoConsume: false,
      );
      if (!launched && state == 'launching') _setState('launch_failed');
      return launched;
    } catch (_) {
      if (state == 'launching') _setState('launch_failed');
      return false;
    }
  }

  Future<void> handle(PurchaseDetails purchase) async {
    if (_disposed) return;
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _setState('pending');
        return;
      case PurchaseStatus.canceled:
        _setState('cancelled');
        return;
      case PurchaseStatus.error:
        _setState('retry_required');
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final token = purchase.verificationData.serverVerificationData;
        if (token.isEmpty ||
            purchase.verificationData.source != 'google_play') {
          _setState('verification_failed');
          return;
        }
        _retry[token] = purchase;
        try {
          final result = await verify(purchase.productID, token);
          if (_disposed) return;
          if (!result.credited || !result.consumed) {
            _setState('retry_required');
            return;
          }
          // Server consume also acknowledges on Android. Do NOT acknowledge
          // separately on the client after a server-consumed token.
          _retry.remove(token);
          _setState('credited');
        } catch (_) {
          _setState('retry_required');
        }
    }
  }

  /// Invoke on app resume, reconnect, and explicit retry. Play redelivers
  /// unconsumed purchases after process death; ledger dedup handles replay.
  Future<void> recover() async {
    for (final purchase in _retry.values.toList()) {
      await handle(purchase);
    }
    if (_account != null && !_disposed) {
      await billing.restorePurchases(applicationUserName: _account);
    }
  }

  void _setState(String value) {
    if (_disposed) return;
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _retry.clear();
    super.dispose();
  }
}
