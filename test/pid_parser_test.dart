import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/domains/obd_response_cleaner.dart';
import 'package:obd2app/models/pid_parser.dart';

void main() {
  group('OBDResponseParser', () {
    test('parseUIntBigEndian 4バイト変換', () {
      final bytes = [0x40, 0x79, 0xC0, 0x01];
      expect(OBDResponseParser.parseUIntBigEndian(bytes, 0, 4), 0x4079C001);
    });

    test('parseUIntBigEndian 1バイト', () {
      expect(OBDResponseParser.parseUIntBigEndian([0xFF], 0, 1), 0xFF);
    });

    test('parseUIntBigEndian 2バイト', () {
      expect(OBDResponseParser.parseUIntBigEndian([0xA0, 0x00], 0, 2), 0xA000);
    });

    test('parseUIntBigEndian offset付き', () {
      final bytes = [0x00, 0x40, 0x79];
      expect(OBDResponseParser.parseUIntBigEndian(bytes, 1, 2), 0x4079);
    });

    test('parseUIntBigEndian count=0 で ArgumentError', () {
      expect(
        () => OBDResponseParser.parseUIntBigEndian([0x00], 0, 0),
        throwsArgumentError,
      );
    });

    test('parseUIntBigEndian count=9 で ArgumentError', () {
      expect(
        () => OBDResponseParser.parseUIntBigEndian([0x00], 0, 9),
        throwsArgumentError,
      );
    });

    test('parseHexBytes 空白区切り16進数文字列をパース', () {
      expect(OBDResponseParser.parseHexBytes('7E8 FF C0 00 03'), [
        0x7E8,
        0xFF,
        0xC0,
        0x00,
        0x03,
      ]);
    });

    test('parseHexBytes 余分な空白を無視', () {
      expect(OBDResponseParser.parseHexBytes('  41 0C  A0 00  '), [
        0x41,
        0x0C,
        0xA0,
        0x00,
      ]);
    });
  });

  group('OBDSupport', () {
    test('isPIDSupported MSB (bitNr=1)', () {
      expect(OBDSupport.isPIDSupported(0x80000000, 1), isTrue);
      expect(OBDSupport.isPIDSupported(0x40000000, 1), isFalse);
    });

    test('isPIDSupported LSB (bitNr=32)', () {
      expect(OBDSupport.isPIDSupported(0x00000001, 32), isTrue);
      expect(OBDSupport.isPIDSupported(0x00000002, 32), isFalse);
    });

    test('isPIDSupported bitNr=2 (Subaru diesel サンプル値)', () {
      // 0x4079C001: bit30 (bitNr=2) がセット
      expect(OBDSupport.isPIDSupported(0x4079C001, 2), isTrue);
    });

    test('isPIDSupported bitNr=0 で ArgumentError', () {
      expect(() => OBDSupport.isPIDSupported(0, 0), throwsArgumentError);
    });

    test('isPIDSupported bitNr=33 で ArgumentError', () {
      expect(() => OBDSupport.isPIDSupported(0, 33), throwsArgumentError);
    });

    test('getSupportedPIDs MSBのみセット', () {
      expect(OBDSupport.getSupportedPIDs(0x80000000, 0x0000), [0x0001]);
    });

    test('getSupportedPIDs bit1とbit32がセット', () {
      final supported = OBDSupport.getSupportedPIDs(0x80000001, 0x0020);
      expect(supported, containsAll([0x0021, 0x0040]));
      expect(supported.length, 2);
    });

    test('getSupportedPIDs すべて0 → 空リスト', () {
      expect(OBDSupport.getSupportedPIDs(0x00000000, 0x0000), isEmpty);
    });
  });

  group('PIDCSVParser', () {
    test('タブ区切りCSVをパース（全フィールド）', () {
      const csv =
          '0x0105\tCOOLANT\tCoolant Temperature\t1\t°C\tx - 40\t-40\t215';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 1);
      final d = defs[0];
      expect(d.pid, 0x0105);
      expect(d.shortName, 'COOLANT');
      expect(d.fullName, 'Coolant Temperature');
      expect(d.byteLength, 1);
      expect(d.unit, '°C');
      expect(d.formula, 'x - 40');
      expect(d.minDisplay, -40);
      expect(d.maxDisplay, 215);
    });

    test('カンマ区切りCSVをパース', () {
      const csv = '0x010C,RPM,Engine RPM,2,rpm';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 1);
      expect(defs[0].pid, 0x010C);
      expect(defs[0].shortName, 'RPM');
    });

    test('# コメント行をスキップ', () {
      const csv = '# This is a comment\n0x0105\tCOOLANT\tCoolant Temp\t1\t°C';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 1);
    });

    test('// コメント行をスキップ', () {
      const csv = '// header\n0x0105\tCOOLANT\tCoolant Temp\t1\t°C';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 1);
    });

    test('空行をスキップ', () {
      const csv = '\n\n0x0105\tCOOLANT\tCoolant Temp\t1\t°C\n\n';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 1);
    });

    test('複数行パース', () {
      const csv =
          '0x0105\tCOOLANT\tCoolant Temperature\t1\t°C\n'
          '0x010C\tRPM\tEngine RPM\t2\trpm\n'
          '0x2101\tOILTEMP\tOil Temperature\t1\t°C';
      final defs = PIDCSVParser.parseDefinitions(csv);
      expect(defs.length, 3);
      expect(defs[2].pid, 0x2101);
    });
  });

  group('油温パース（OBDResponseCleaner 適用後）', () {
    // obd_controller.dart の _parseOilTemp() と同じ index 基準を検証する。

    List<String> splitHex(String s) =>
        s.split(' ').where((p) => p.isNotEmpty).toList();

    int parseOilTemp(String response) {
      final parts = splitHex(response.trim().toUpperCase());
      final integrated = OBDResponseCleaner.clean(parts);
      const startIndex = 2;
      const oilTempOffset = 28;
      const targetIndex = startIndex + oilTempOffset;
      if (integrated.length <= targetIndex) throw FormatException('Too short');
      return int.parse(integrated[targetIndex], radix: 16) - 40;
    }

    test('BRZ ZC6 実車マルチフレーム応答 → 55℃', () {
      // cleaned[30]=DATA28=Frame4[3]: 0x5F=95, 95-40=55
      const response =
          '01F D0: 61 01 00 00 00 00 D1: 00 00 00 00 00 00 00 D2: 00 00 00 00 00 00 00 D3: 00 00 00 00 00 00 00 D4: 00 00 00 5F 00 00 00';
      expect(parseOilTemp(response), 55);
    });

    test('ヘッダあり形式 (7E8) → 55℃', () {
      const response =
          '7E8 07 61 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 5F 00';
      expect(parseOilTemp(response), 55);
    });

    test('ヘッダなし形式 → 55℃', () {
      const response =
          '61 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 5F 00';
      expect(parseOilTemp(response), 55);
    });

    test('油温 0℃ (0x28 = 40 → 40-40=0)', () {
      expect(
        parseOilTemp(
          '61 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 28 00',
        ),
        0,
      );
    });

    test('油温 100℃ (0x8C = 140 → 140-40=100)', () {
      expect(
        parseOilTemp(
          '61 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 8C 00',
        ),
        100,
      );
    });

    test('応答が短すぎる場合 FormatException', () {
      expect(
        () => parseOilTemp(
          '61 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00',
        ),
        throwsFormatException,
      );
    });
  });
}
