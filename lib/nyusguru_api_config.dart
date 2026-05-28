/// Shared Supabase / NyusGuru API endpoints and auth headers for the mobile app.
abstract final class NyusGuruApiConfig {
  static const String projectRef = 'bmrnboonxzkyxgatwgbr';

  static const String supabaseHost = 'https://bmrnboonxzkyxgatwgbr.supabase.co';

  static const String appKey =
      'c1d315cb43d93c8530ea14e81ba0d4fe987f0ddf40f8c90229ef356f64fa369e';

  /// Pass at build/run time: `--dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String newsFeedUrl = '$supabaseHost/functions/v1/get-news-feed';

  static const String ensureAnimeImageUrl =
      '$supabaseHost/functions/v1/ensure-anime-image';

  static const String recordNewsSignalUrl =
      '$supabaseHost/functions/v1/record-news-signal';

  static const String registerDeviceTokenUrl =
      '$supabaseHost/functions/v1/register-device-token';

  static const String logUserTelemetryRpcUrl =
      '$supabaseHost/rest/v1/rpc/log_user_telemetry';

  static Map<String, String> apiHeaders({
    bool jsonContent = false,
    bool minimalResponse = false,
  }) {
    final headers = <String, String>{'x-nyusguru-key': appKey};
    if (jsonContent) {
      headers['content-type'] = 'application/json';
    }
    if (minimalResponse) {
      headers['prefer'] = 'return=minimal';
    }
    if (supabaseAnonKey.isNotEmpty) {
      headers['apikey'] = supabaseAnonKey;
      headers['authorization'] = 'Bearer $supabaseAnonKey';
    }
    return headers;
  }
}
