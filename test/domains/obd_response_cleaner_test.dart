import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/domains/obd_response_cleaner.dart';

void main() {
  group('OBDResponseCleaner.clean の単体テスト', () {
    test(
      'マルチフレームデータからデータ長とすべての行番号が正しく除去され、油温のターゲットになる index: 4 が正しいデータを指すこと',
      () {
        final input = [
          '01F',
          '\r0:',
          '61',
          '01',
          '3E',
          '00',
          '2B',
          '00',
          '\r1:',
          'E8',
          '20',
          '4E',
          '48',
          '66',
          '7E',
          '0B',
        ];

        final result = OBDResponseCleaner.clean(input);

        expect(result, [
          '61',
          '01',
          '3E',
          '00',
          '2B',
          '00',
          'E8',
          '20',
          '4E',
          '48',
          '66',
          '7E',
          '0B',
        ]);
        expect(result[4], '2B');
      },
    );

    test('ヘッダあり単一フレームデータからヘッダとデータ長が正しく除去されること', () {
      final input = ['7E8', '02', '41', '05', '6E'];
      final result = OBDResponseCleaner.clean(input);

      expect(result, ['41', '05', '6E']);
    });

    test('通常の単一フレームデータはそのまま返されること', () {
      final input = ['41', '0C', '12', 'A4'];
      final result = OBDResponseCleaner.clean(input);

      expect(result, ['41', '0C', '12', 'A4']);
    });
  });
}
