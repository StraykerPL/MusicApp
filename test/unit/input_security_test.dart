import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Shared/input_security.dart';

void main() {
  group('InputSecurity', () {
    test('accepts normal user text', () {
      expect(InputSecurity.isSafeUserText('Road Trip 2026'), isTrue);
      expect(InputSecurity.isSafeUserText('ambient_mix-01'), isTrue);
    });

    test('rejects common injection patterns', () {
      expect(
        InputSecurity.isSafeUserText('name; DROP TABLE playlists'),
        isFalse,
      );
      expect(
          InputSecurity.isSafeUserText('<script>alert(1)</script>'), isFalse);
      expect(InputSecurity.isSafeUserText('test OR 1=1'), isFalse);
      expect(InputSecurity.isSafeUserText('playlist && rm -rf /'), isFalse);
    });

    test('rejects control characters and oversized input', () {
      expect(InputSecurity.isSafeUserText('name\u0001'), isFalse);
      expect(
        InputSecurity.isSafeUserText(
          List.filled(InputSecurity.maxTextLength + 1, 'a').join(),
        ),
        isFalse,
      );
    });
  });

  group('SecureTextInputFormatter', () {
    const formatter = SecureTextInputFormatter();

    test('keeps safe edits', () {
      const oldValue = TextEditingValue(text: 'Road');
      const newValue = TextEditingValue(text: 'Road Trip');

      expect(formatter.formatEditUpdate(oldValue, newValue), newValue);
    });

    test('rejects unsafe edits', () {
      const oldValue = TextEditingValue(text: 'Road');
      const newValue = TextEditingValue(text: 'Road; DROP TABLE playlists');

      expect(formatter.formatEditUpdate(oldValue, newValue), oldValue);
    });
  });
}
