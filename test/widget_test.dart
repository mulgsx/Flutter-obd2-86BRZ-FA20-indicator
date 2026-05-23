import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/domains/obd_response_cleaner.dart';

void main() {
  test(
    'OBDResponseCleaner is available to tests without BLE platform setup',
    () {
      expect(OBDResponseCleaner.clean(['7E8', '02', '41', '05', '6E']), [
        '41',
        '05',
        '6E',
      ]);
    },
  );
}
