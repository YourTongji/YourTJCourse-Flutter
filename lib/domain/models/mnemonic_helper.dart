import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'credit_wordlist.dart';

/// Errors thrown by [MnemonicHelper].
class MnemonicError implements Exception {
  const MnemonicError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// iOS-equivalent MnemonicHelper: PBKDF2 → 3-word mnemonic → SHA-256 wallet.
///
/// Matches `YourTJCourse-iOS/Packages/DataKit/Sources/DataKit/Utilities/MnemonicHelper.swift`.
class MnemonicHelper {
  MnemonicHelper._();

  static const String _salt = 'tongji-course-salt-2026';
  static const int _iterations = 100_000;
  static const int _keyLength = 32;

  /// Generate wallet credentials from student ID and PIN.
  ///
  /// Same flow as iOS `MnemonicHelper.generate(studentId:pin:)`:
  /// 1. PBKDF2-HMAC-SHA256 on `"{studentId}:{pin}"`
  /// 2. Map first 6 bytes → 3 words from [CreditWordlist]
  /// 3. [restore] the mnemonic → userHash + userSecret
  static ({String mnemonic, String userHash, String userSecret}) generate({
    required String studentId,
    required String pin,
  }) {
    final normalizedId = studentId.trim();
    if (!_validateStudentId(normalizedId)) {
      throw const MnemonicError('学号格式无效（应为 7-10 位数字）');
    }
    if (!_validatePin(pin)) {
      throw const MnemonicError('PIN 码长度必须在 6-32 位之间');
    }

    final initialKey = _pbkdf2('$normalizedId:$pin');
    final mnemonic = _mnemonicFromBytes(initialKey, wordlist: CreditWordlist.words);
    final (:userHash, :userSecret) = _digest(mnemonic);
    return (mnemonic: mnemonic, userHash: userHash, userSecret: userSecret);
  }

  /// Restore wallet credentials from a 3-word mnemonic phrase.
  ///
  /// Same flow as iOS `MnemonicHelper.restore(mnemonic:)`:
  /// 1. Normalize the phrase
  /// 2. PBKDF2 on the mnemonic string
  /// 3. SHA-256 → userHash, base64 → userSecret
  static ({String mnemonic, String userHash, String userSecret}) restore(
    String phrase,
  ) {
    final normalized = normalize(phrase);
    if (!validate(normalized)) {
      throw const MnemonicError('助记词格式无效（应为 3 个词）');
    }

    // Validate all words are in the wordlist.
    final words = normalized.split('-');
    final wordlist = CreditWordlist.words.toSet();
    for (final word in words) {
      if (!wordlist.contains(word)) {
        throw MnemonicError('词库中不存在词语：$word');
      }
    }

    final (:userHash, :userSecret) = _digest(normalized);
    return (mnemonic: normalized, userHash: userHash, userSecret: userSecret);
  }

  /// Normalize a mnemonic phrase: trim, unify separators → `-`.
  static String normalize(String phrase) {
    return phrase
        .trim()
        .replaceAll('，', '-')
        .replaceAll(',', '-')
        .split(RegExp(r'[\s\-]+'))
        .where((w) => w.isNotEmpty)
        .join('-');
  }

  /// Validate a normalized phrase has exactly 3 non-empty words.
  static bool validate(String phrase) {
    return phrase.split('-').where((w) => w.isNotEmpty).length == 3;
  }

  /// Validate student ID: 7-10 digits.
  static bool _validateStudentId(String id) =>
      RegExp(r'^\d{7,10}$').hasMatch(id);

  /// Validate PIN: 6-32 characters.
  static bool _validatePin(String pin) => pin.length >= 6 && pin.length <= 32;

  /// PBKDF2-HMAC-SHA256 with the iOS salt and iteration count.
  static List<int> _pbkdf2(String input, {int? keyLength}) {
    final dkLen = keyLength ?? _keyLength;
    final passwordBytes = utf8.encode(input);
    final saltBytes = utf8.encode(_salt);
    final hLen = 32; // SHA-256 output length (bytes)
    final l = (dkLen + hLen - 1) ~/ hLen; // ceiling division
    final hmac = Hmac(sha256, passwordBytes);
    final result = <int>[];

    for (var block = 1; block <= l; block++) {
      // U1 = PRF(Password, Salt || INT_32_BE(i))
      final blockBytes = Uint8List(4);
      ByteData.view(blockBytes.buffer).setUint32(0, block, Endian.big);
      final combined = Uint8List(saltBytes.length + 4)
        ..setRange(0, saltBytes.length, saltBytes)
        ..setRange(saltBytes.length, saltBytes.length + 4, blockBytes);

      var u = hmac.convert(combined).bytes.toList();
      var t = List<int>.from(u); // T_i = U_1

      for (var j = 2; j <= _iterations; j++) {
        u = hmac.convert(u).bytes.toList();
        for (var k = 0; k < hLen; k++) {
          t[k] ^= u[k]; // XOR into T_i
        }
      }

      result.addAll(t);
    }

    return result.take(dkLen).toList();
  }

  /// Given a 32-byte key, produce 3 mnemonic words from the wordlist.
  ///
  /// Each word is selected by `(bytes[i*2] << 8 | bytes[i*2+1]) % wordlist.length`.
  static String _mnemonicFromBytes(List<int> key, {required List<String> wordlist}) {
    final words = <String>[];
    for (var i = 0; i < 3; i++) {
      final offset = i * 2;
      final value = (key[offset] << 8) | key[offset + 1];
      words.add(wordlist[value % wordlist.length]);
    }
    return words.join('-');
  }

  /// Derive userHash (64-char hex) and userSecret (base64) from a mnemonic.
  ///
  /// PBKDF2(mnemonic) → 32 bytes → SHA-256 → hex userHash
  ///                         → same 32 bytes → base64 → userSecret
  static ({String userHash, String userSecret}) _digest(String normalizedMnemonic) {
    final derivedKey = _pbkdf2(normalizedMnemonic);
    final hash = sha256.convert(derivedKey);
    final userHash = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final userSecret = base64Encode(derivedKey);
    return (userHash: userHash, userSecret: userSecret);
  }
}
