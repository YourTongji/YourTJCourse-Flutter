import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/core/config/app_config.dart';

void main() {
  test('defaults to the same real backend as the iOS client', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    final config = AppConfig.fromEnv();

    expect(config.apiBaseUrl, 'https://jcourse.yourtj.de');
    expect(config.creditApiBaseUrl, 'https://core.credit.yourtj.de');
  });
}
