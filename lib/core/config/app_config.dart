import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.creditApiBaseUrl,
    required this.captchaApiBaseUrl,
    required this.buildSha,
  });

  factory AppConfig.fromEnv() {
    return AppConfig(
      apiBaseUrl:
          dotenv.maybeGet('API_BASE_URL') ?? 'https://jcourse.yourtj.de',
      creditApiBaseUrl:
          dotenv.maybeGet('CREDIT_API_BASE_URL') ??
          'https://core.credit.yourtj.de',
      captchaApiBaseUrl:
          dotenv.maybeGet('CAPTCHA_API_BASE_URL') ??
          'https://captcha.07211024.xyz',
      buildSha: const String.fromEnvironment('APP_BUILD_SHA'),
    );
  }

  final String apiBaseUrl;
  final String creditApiBaseUrl;
  final String captchaApiBaseUrl;
  final String buildSha;
}
