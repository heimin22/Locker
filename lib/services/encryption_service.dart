import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// AES-256 Encryption Service for secure file encryption
/// Uses AES-256-CBC mode with PKCS7 padding
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  // Using the new secure cipher defaults (RSA OAEP + AES-GCM)
  // instead of deprecated encryptedSharedPreferences
  // migrateOnAlgorithmChange ensures existing data is automatically migrated
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _masterKeyKey = 'vault_master_key';
  static const String _decoyKeyKey = 'vault_decoy_key';
  static const int _keySize = 32; // 256 bits
  static const int _ivSize = 16; // 128 bits

  Uint8List? _cachedMasterKey;
  Uint8List? _cachedDecoyKey;

  /// Initialize the encryption service
  /// Creates master key if not exists
  Future<void> initialize() async {
    await _ensureMasterKey();
  }

  /// Ensure master key exists, create if not
  Future<Uint8List> _ensureMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey!;

    try {
      final storedKey = await _storage.read(key: _masterKeyKey);
      if (storedKey != null) {
        _cachedMasterKey = base64Decode(storedKey);
        return _cachedMasterKey!;
      }
    } catch (e) {
      debugPrint('Error reading master key: $e');
    }

    // Generate new master key
    _cachedMasterKey = _generateRandomBytes(_keySize);
    await _storage.write(
        key: _masterKeyKey, value: base64Encode(_cachedMasterKey!));
    return _cachedMasterKey!;
  }

  /// Get or create decoy key (for decoy mode)
  Future<Uint8List> _ensureDecoyKey() async {
    if (_cachedDecoyKey != null) return _cachedDecoyKey!;

    try {
      final storedKey = await _storage.read(key: _decoyKeyKey);
      if (storedKey != null) {
        _cachedDecoyKey = base64Decode(storedKey);
        return _cachedDecoyKey!;
      }
    } catch (e) {
      debugPrint('Error reading decoy key: $e');
    }

    // Generate new decoy key
    _cachedDecoyKey = _generateRandomBytes(_keySize);
    await _storage.write(
        key: _decoyKeyKey, value: base64Encode(_cachedDecoyKey!));
    return _cachedDecoyKey!;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generate a random IV (Initialization Vector)
  Uint8List generateIV() {
    return _generateRandomBytes(_ivSize);
  }

  /// Derive key from password using PBKDF2
  Uint8List deriveKeyFromPassword(String password, {Uint8List? salt}) {
    salt ??= _generateRandomBytes(16);

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, _keySize));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Get the encryption cipher
  PaddedBlockCipher _getCipher(
      Uint8List key, Uint8List iv, bool forEncryption) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );

    cipher.init(
      forEncryption,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
        null,
      ),
    );

    return cipher;
  }

  /// Encrypt data using AES-256-CBC
  Future<EncryptionResult> encryptData(
    Uint8List data, {
    bool isDecoy = false,
    Uint8List? customKey,
  }) async {
    try {
      final key = customKey ??
          (isDecoy ? await _ensureDecoyKey() : await _ensureMasterKey());
      final iv = generateIV();

      final cipher = _getCipher(key, iv, true);
      final encrypted = cipher.process(data);

      return EncryptionResult(
        success: true,
        data: encrypted,
        iv: base64Encode(iv),
      );
    } catch (e) {
      debugPrint('Encryption error: $e');
      return EncryptionResult(
        success: false,
        error: 'Encryption failed: $e',
      );
    }
  }

  /// Decrypt data using AES-256-CBC
  Future<DecryptionResult> decryptData(
    Uint8List encryptedData,
    String ivBase64, {
    bool isDecoy = false,
    Uint8List? customKey,
  }) async {
    try {
      final key = customKey ??
          (isDecoy ? await _ensureDecoyKey() : await _ensureMasterKey());
      final iv = base64Decode(ivBase64);

      final cipher = _getCipher(key, iv, false);
      final decrypted = cipher.process(encryptedData);

      return DecryptionResult(
        success: true,
        data: decrypted,
      );
    } catch (e) {
      debugPrint('Decryption error: $e');
      return DecryptionResult(
        success: false,
        error: 'Decryption failed: $e',
      );
    }
  }

  /// Encrypt a file and return the encrypted file path
  Future<FileEncryptionResult> encryptFile(
    String sourcePath,
    String destinationPath, {
    bool isDecoy = false,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return FileEncryptionResult(
          success: false,
          error: 'Source file does not exist',
        );
      }

      final data = await sourceFile.readAsBytes();
      onProgress?.call(1, 3);

      final result =
          await encryptData(Uint8List.fromList(data), isDecoy: isDecoy);
      onProgress?.call(2, 3);

      if (!result.success || result.data == null) {
        return FileEncryptionResult(
          success: false,
          error: result.error ?? 'Encryption failed',
        );
      }

      final destFile = File(destinationPath);
      await destFile.writeAsBytes(result.data!);
      onProgress?.call(3, 3);

      return FileEncryptionResult(
        success: true,
        encryptedPath: destinationPath,
        iv: result.iv,
        originalSize: data.length,
        encryptedSize: result.data!.length,
      );
    } catch (e) {
      debugPrint('File encryption error: $e');
      return FileEncryptionResult(
        success: false,
        error: 'File encryption failed: $e',
      );
    }
  }

  /// Encrypt a file using chunked streaming (memory-efficient for large files)
  /// Processes file in chunks to avoid loading entire file into memory
  /// Uses CTR mode for streaming (CBC requires full blocks, not suitable for streaming)
  Future<FileEncryptionResult> encryptFileStreamed(
    String sourcePath,
    String destinationPath, {
    bool isDecoy = false,
    Function(int bytesProcessed, int totalBytes)? onProgress,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return FileEncryptionResult(
          success: false,
          error: 'Source file does not exist',
        );
      }

      final key = isDecoy ? await _ensureDecoyKey() : await _ensureMasterKey();
      final iv = generateIV();
      final totalBytes = await sourceFile.length();

      // Use CTR mode for streaming - it's a stream cipher that doesn't require padding
      final ctr = CTRStreamCipher(AESEngine())
        ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));

      final destFile = File(destinationPath);
      final sink = destFile.openWrite();

      // Write 8-byte header: 4 bytes magic + 4 bytes original file size
      // Magic bytes help identify streamed encrypted files
      final header = Uint8List(8);
      header[0] = 0x4C; // 'L'
      header[1] = 0x4B; // 'K'
      header[2] = 0x52; // 'R'
      header[3] = 0x53; // 'S' (Locker Streamed)
      // Store original file size (little-endian)
      header[4] = (totalBytes & 0xFF);
      header[5] = ((totalBytes >> 8) & 0xFF);
      header[6] = ((totalBytes >> 16) & 0xFF);
      header[7] = ((totalBytes >> 24) & 0xFF);
      sink.add(header);

      int bytesProcessed = 0;

      final inputStream = sourceFile.openRead();
      await for (final chunk in inputStream) {
        final encrypted = ctr.process(Uint8List.fromList(chunk));
        sink.add(encrypted);

        bytesProcessed += chunk.length;
        onProgress?.call(bytesProcessed, totalBytes);
      }

      await sink.flush();
      await sink.close();

      final encryptedSize = await destFile.length();

      return FileEncryptionResult(
        success: true,
        encryptedPath: destinationPath,
        iv: base64Encode(iv),
        originalSize: totalBytes,
        encryptedSize: encryptedSize,
      );
    } catch (e) {
      debugPrint('File streaming encryption error: $e');
      return FileEncryptionResult(
        success: false,
        error: 'File streaming encryption failed: $e',
      );
    }
  }

  /// Decrypt a file and return the decrypted file path
  Future<FileDecryptionResult> decryptFile(
    String encryptedPath,
    String destinationPath,
    String ivBase64, {
    bool isDecoy = false,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        return FileDecryptionResult(
          success: false,
          error: 'Encrypted file does not exist',
        );
      }

      final encryptedData = await encryptedFile.readAsBytes();
      onProgress?.call(1, 3);

      final result = await decryptData(
        Uint8List.fromList(encryptedData),
        ivBase64,
        isDecoy: isDecoy,
      );
      onProgress?.call(2, 3);

      if (!result.success || result.data == null) {
        return FileDecryptionResult(
          success: false,
          error: result.error ?? 'Decryption failed',
        );
      }

      final destFile = File(destinationPath);
      await destFile.writeAsBytes(result.data!);
      onProgress?.call(3, 3);

      return FileDecryptionResult(
        success: true,
        decryptedPath: destinationPath,
        decryptedSize: result.data!.length,
      );
    } catch (e) {
      debugPrint('File decryption error: $e');
      return FileDecryptionResult(
        success: false,
        error: 'File decryption failed: $e',
      );
    }
  }

  /// Decrypt a file using chunked streaming (memory-efficient for large files)
  /// Matches the format created by encryptFileStreamed (8-byte header + CTR encrypted data)
  Future<FileDecryptionResult> decryptFileStreamed(
    String encryptedPath,
    String destinationPath,
    String ivBase64, {
    bool isDecoy = false,
    Function(int bytesProcessed, int totalBytes)? onProgress,
  }) async {
    try {
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        return FileDecryptionResult(
          success: false,
          error: 'Encrypted file does not exist',
        );
      }

      final key = isDecoy ? await _ensureDecoyKey() : await _ensureMasterKey();
      final iv = base64Decode(ivBase64);
      final encryptedSize = await encryptedFile.length();

      // Open file and read header
      final raf = await encryptedFile.open();
      final header = await raf.read(8);

      // Verify magic bytes
      if (header.length < 8 ||
          header[0] != 0x4C ||
          header[1] != 0x4B ||
          header[2] != 0x52 ||
          header[3] != 0x53) {
        await raf.close();
        return FileDecryptionResult(
          success: false,
          error: 'Invalid encrypted file format (not a streamed file)',
        );
      }

      // Read original file size from header (little-endian)
      final originalSize =
          header[4] | (header[5] << 8) | (header[6] << 16) | (header[7] << 24);

      await raf.close();

      // Use CTR mode for streaming decryption
      final ctr = CTRStreamCipher(AESEngine())
        ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));

      final destFile = File(destinationPath);
      final sink = destFile.openWrite();

      final totalBytes = encryptedSize - 8; // Subtract header size
      int bytesProcessed = 0;

      // Read encrypted data after header
      final inputStream = encryptedFile.openRead(8); // Skip 8-byte header
      await for (final chunk in inputStream) {
        final decrypted = ctr.process(Uint8List.fromList(chunk));
        sink.add(decrypted);

        bytesProcessed += chunk.length;
        onProgress?.call(bytesProcessed, totalBytes);
      }

      await sink.flush();
      await sink.close();

      return FileDecryptionResult(
        success: true,
        decryptedPath: destinationPath,
        decryptedSize: originalSize,
      );
    } catch (e) {
      debugPrint('File streaming decryption error: $e');
      return FileDecryptionResult(
        success: false,
        error: 'File streaming decryption failed: $e',
      );
    }
  }

  /// Decrypt streamed file to memory (for viewing without writing to disk)
  /// Supports both CBC-encrypted files (legacy) and CTR-encrypted streamed files
  Future<DecryptionResult> decryptStreamedFileToMemory(
    String encryptedPath,
    String ivBase64, {
    bool isDecoy = false,
  }) async {
    try {
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        return DecryptionResult(
          success: false,
          error: 'Encrypted file does not exist',
        );
      }

      final encryptedData = await encryptedFile.readAsBytes();

      // Check for streamed file magic bytes
      if (encryptedData.length >= 8 &&
          encryptedData[0] == 0x4C &&
          encryptedData[1] == 0x4B &&
          encryptedData[2] == 0x52 &&
          encryptedData[3] == 0x53) {
        // This is a CTR-encrypted streamed file
        final key =
            isDecoy ? await _ensureDecoyKey() : await _ensureMasterKey();
        final iv = base64Decode(ivBase64);

        final ctr = CTRStreamCipher(AESEngine())
          ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));

        // Skip 8-byte header and decrypt
        final dataToDecrypt = Uint8List.sublistView(encryptedData, 8);
        final decrypted = ctr.process(dataToDecrypt);

        return DecryptionResult(
          success: true,
          data: decrypted,
        );
      } else {
        // Fall back to CBC decryption for legacy files
        return await decryptData(
          encryptedData,
          ivBase64,
          isDecoy: isDecoy,
        );
      }
    } catch (e) {
      debugPrint('Streamed file decryption to memory error: $e');
      return DecryptionResult(
        success: false,
        error: 'File decryption failed: $e',
      );
    }
  }

  /// Decrypt file to memory (for viewing without writing to disk)
  Future<DecryptionResult> decryptFileToMemory(
    String encryptedPath,
    String ivBase64, {
    bool isDecoy = false,
  }) async {
    try {
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        return DecryptionResult(
          success: false,
          error: 'Encrypted file does not exist',
        );
      }

      final encryptedData = await encryptedFile.readAsBytes();
      return await decryptData(
        Uint8List.fromList(encryptedData),
        ivBase64,
        isDecoy: isDecoy,
      );
    } catch (e) {
      debugPrint('File decryption to memory error: $e');
      return DecryptionResult(
        success: false,
        error: 'File decryption failed: $e',
      );
    }
  }

  /// Generate a hash of the data (for integrity verification)
  String generateHash(Uint8List data) {
    return sha256.convert(data).toString();
  }

  /// Verify data integrity using hash
  bool verifyHash(Uint8List data, String expectedHash) {
    return generateHash(data) == expectedHash;
  }

  /// Securely delete a file (overwrite before delete)
  Future<bool> secureDelete(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return true;

      // Get file size
      final length = await file.length();

      // Overwrite with random data
      final randomData = _generateRandomBytes(length);
      await file.writeAsBytes(randomData);

      // Overwrite with zeros
      await file.writeAsBytes(List.filled(length, 0));

      // Delete the file
      await file.delete();
      return true;
    } catch (e) {
      debugPrint('Secure delete error: $e');
      try {
        // Try regular delete as fallback
        await File(filePath).delete();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Re-encrypt all files with a new key (for key rotation)
  Future<KeyRotationResult> rotateKey({
    required List<String> encryptedFilePaths,
    required List<String> ivs,
    required String tempDirectory,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      if (encryptedFilePaths.length != ivs.length) {
        return KeyRotationResult(
          success: false,
          error: 'File paths and IVs count mismatch',
        );
      }

      // Generate new key
      final newKey = _generateRandomBytes(_keySize);
      final newIvs = <String>[];

      // Re-encrypt each file
      for (int i = 0; i < encryptedFilePaths.length; i++) {
        onProgress?.call(i + 1, encryptedFilePaths.length);

        final path = encryptedFilePaths[i];
        final oldIv = ivs[i];

        // Decrypt with old key
        final decrypted = await decryptFileToMemory(path, oldIv);
        if (!decrypted.success || decrypted.data == null) {
          return KeyRotationResult(
            success: false,
            error: 'Failed to decrypt file at index $i',
            processedCount: i,
          );
        }

        // Encrypt with new key
        final newIv = generateIV();
        final cipher = _getCipher(newKey, newIv, true);
        final reEncrypted = cipher.process(decrypted.data!);

        // Write back
        await File(path).writeAsBytes(reEncrypted);
        newIvs.add(base64Encode(newIv));
      }

      // Save new key
      _cachedMasterKey = newKey;
      await _storage.write(key: _masterKeyKey, value: base64Encode(newKey));

      return KeyRotationResult(
        success: true,
        newIvs: newIvs,
        processedCount: encryptedFilePaths.length,
      );
    } catch (e) {
      debugPrint('Key rotation error: $e');
      return KeyRotationResult(
        success: false,
        error: 'Key rotation failed: $e',
      );
    }
  }

  /// Check if encryption is enabled
  Future<bool> hasEncryptionKey() async {
    try {
      final key = await _storage.read(key: _masterKeyKey);
      return key != null;
    } catch (e) {
      return false;
    }
  }

  /// Reset encryption keys (dangerous - all encrypted data will be lost!)
  Future<void> resetKeys() async {
    _cachedMasterKey = null;
    _cachedDecoyKey = null;
    await _storage.delete(key: _masterKeyKey);
    await _storage.delete(key: _decoyKeyKey);
  }
}

/// Result of data encryption
class EncryptionResult {
  final bool success;
  final Uint8List? data;
  final String? iv;
  final String? error;

  const EncryptionResult({
    required this.success,
    this.data,
    this.iv,
    this.error,
  });
}

/// Result of data decryption
class DecryptionResult {
  final bool success;
  final Uint8List? data;
  final String? error;

  const DecryptionResult({
    required this.success,
    this.data,
    this.error,
  });
}

/// Result of file encryption
class FileEncryptionResult {
  final bool success;
  final String? encryptedPath;
  final String? iv;
  final int? originalSize;
  final int? encryptedSize;
  final String? error;

  const FileEncryptionResult({
    required this.success,
    this.encryptedPath,
    this.iv,
    this.originalSize,
    this.encryptedSize,
    this.error,
  });
}

/// Result of file decryption
class FileDecryptionResult {
  final bool success;
  final String? decryptedPath;
  final int? decryptedSize;
  final String? error;

  const FileDecryptionResult({
    required this.success,
    this.decryptedPath,
    this.decryptedSize,
    this.error,
  });
}

/// Result of key rotation
class KeyRotationResult {
  final bool success;
  final List<String>? newIvs;
  final int processedCount;
  final String? error;

  const KeyRotationResult({
    required this.success,
    this.newIvs,
    this.processedCount = 0,
    this.error,
  });
}
