import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;

  void _init() {
    if (_encrypter != null) return;

    final keyString = dotenv.env['ENCRYPTION_KEY'] ?? 'default_key_must_be_32_bytes_long!!';
    final ivString = dotenv.env['ENCRYPTION_IV'] ?? 'default_iv_16byte';

    // 32바이트 Key, 16바이트 IV 보장
    final key = encrypt.Key.fromUtf8(keyString.padRight(32, ' ').substring(0, 32));
    _iv = encrypt.IV.fromUtf8(ivString.padRight(16, ' ').substring(0, 16));
    
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  /// 텍스트 암호화 (Base64 문자열 반환)
  String encryptText(String text) {
    _init();
    if (text.isEmpty) return text;
    try {
      final encrypted = _encrypter!.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      return text;
    }
  }

  /// 텍스트 복호화
  String decryptText(String encryptedBase64) {
    _init();
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      final decrypted = _encrypter!.decrypt64(encryptedBase64, iv: _iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      // 복호화 실패 시 원본(또는 오류 메시지)을 반환하거나 예외 처리
      // 여기서는 기존 데이터 호환을 위해 일단 원본을 반환해 봅니다.
      return encryptedBase64; 
    }
  }
}
