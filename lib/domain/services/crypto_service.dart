import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../entities/position.dart';

/// Cryptography service for Mental Poker protocol
/// Implements SHA-256 based commitment scheme for secret moves
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _random = Random.secure();

  /// Generates a random salt (32 bytes = 64 hex characters)
  /// Used to prevent rainbow table attacks on position hashes
  String generateSalt() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Computes SHA-256 hash of position + salt
  /// Hash = SHA256(x + "," + y + ":" + salt)
  /// 
  /// Example:
  ///   position = (7, 8)
  ///   salt = "a1b2c3..."
  ///   input = "7,8:a1b2c3..."
  ///   output = "e3b0c442..." (64 hex chars)
  String hashMove(Position position, String salt) {
    if (!position.isValid) {
      throw ArgumentError('Invalid position: $position');
    }
    
    // Format: "x,y:salt"
    final input = '${position.toHashString()}:$salt';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Verifies that revealed position and salt match the original hash
  /// Returns true if hash is valid, false if cheating detected
  bool verifyMove({
    required String originalHash,
    required Position revealedPosition,
    required String revealedSalt,
  }) {
    if (!revealedPosition.isValid) {
      return false; // Invalid position is considered cheating
    }
    
    try {
      final computedHash = hashMove(revealedPosition, revealedSalt);
      return computedHash == originalHash;
    } catch (e) {
      return false; // Any error during verification is treated as invalid
    }
  }

  /// Generates a new move commitment (hash + salt pair)
  /// Returns a record with (hash, salt)
  ({String hash, String salt}) generateCommitment(Position position) {
    final salt = generateSalt();
    final hash = hashMove(position, salt);
    return (hash: hash, salt: salt);
  }

  /// Validates that a salt has the correct format (64 hex characters)
  bool isValidSalt(String salt) {
    if (salt.length != 64) return false;
    
    // Check if all characters are valid hex digits
    final hexPattern = RegExp(r'^[0-9a-f]{64}$');
    return hexPattern.hasMatch(salt);
  }

  /// Validates that a hash has the correct format (64 hex characters)
  bool isValidHash(String hash) {
    if (hash.length != 64) return false;
    
    // SHA-256 produces 64 hex characters
    final hexPattern = RegExp(r'^[0-9a-f]{64}$');
    return hexPattern.hasMatch(hash);
  }
}
