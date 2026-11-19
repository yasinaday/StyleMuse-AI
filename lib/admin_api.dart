import 'stylemuse_api.dart';

/// All authorization remains server-side; no client-supplied admin flag.
abstract interface class AdminApi {
  Future<Map<String, dynamic>> overview();
  Future<Map<String, dynamic>> falCredit();
  Future<Map<String, dynamic>> replicateCredit();
  Future<Map<String, dynamic>> recordReplicateCredit(String amount, String id);
  Future<Map<String, dynamic>> requestTokens(int amount);
  Future<Map<String, dynamic>> confirmTokens(String id, String code);
}

class StyleMuseAdminApi implements AdminApi {
  StyleMuseAdminApi(this.api);
  final StyleMuseApi api;
  @override
  Future<Map<String, dynamic>> overview() =>
      api.post('/api/admin/overview', {});
  @override
  Future<Map<String, dynamic>> falCredit() =>
      api.post('/api/admin/fal-credit/status', {});
  @override
  Future<Map<String, dynamic>> replicateCredit() =>
      api.post('/api/admin/replicate-credit/status', {});
  @override
  Future<Map<String, dynamic>> recordReplicateCredit(
          String amount, String id) =>
      api.post('/api/admin/replicate-credit',
          {'amount_usd': amount, 'request_id': id});
  @override
  Future<Map<String, dynamic>> requestTokens(int amount) =>
      api.post('/api/admin/tokens/request', {'amount': amount});
  @override
  Future<Map<String, dynamic>> confirmTokens(String id, String code) =>
      api.post('/api/admin/tokens/confirm', {'request_id': id, 'code': code});
}
