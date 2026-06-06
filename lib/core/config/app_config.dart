import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.creditApiBaseUrl});

  factory AppConfig.fromEnv() {
    return AppConfig(
      apiBaseUrl:
          dotenv.maybeGet('API_BASE_URL') ?? 'https://jcourse.yourtj.de',
      creditApiBaseUrl:
          dotenv.maybeGet('CREDIT_API_BASE_URL') ??
          'https://core.credit.yourtj.de',
    );
  }

  final String apiBaseUrl;
  final String creditApiBaseUrl;
}
