class AppConfig {
  const AppConfig({
    required this.apiUrl,
    required this.appName,
    required this.env,
  });

  final String apiUrl;
  final String appName;
  final String env;

  bool get isDev => env == 'dev';
  bool get isStaging => env == 'staging';
  bool get isProd => env == 'prod';

  static const AppConfig instance = AppConfig(
    apiUrl: String.fromEnvironment('API_URL', defaultValue: 'https://api-mobile.19t.vn'),
    appName: String.fromEnvironment('APP_NAME', defaultValue: '19T Dev'),
    env: String.fromEnvironment('ENV', defaultValue: 'dev'),
  );
}
