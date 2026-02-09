import 'package:flutter_test/flutter_test.dart';
import 'package:psygomoku/domain/entities/position.dart';
import 'package:psygomoku/domain/services/crypto_service.dart';

void main() {
  group('CryptoService', () {
    test('generates valid hash and salt and verifies commitment', () {
      final service = CryptoService();
      final position = Position(7, 7);

      final commitment = service.generateCommitment(position);

      expect(service.isValidSalt(commitment.salt), isTrue);
      expect(service.isValidHash(commitment.hash), isTrue);

      final verified = service.verifyMove(
        originalHash: commitment.hash,
        revealedPosition: position,
        revealedSalt: commitment.salt,
      );

      expect(verified, isTrue);
    });

    test('fails verification with wrong position', () {
      final service = CryptoService();
      final position = Position(3, 4);
      final wrongPosition = Position(4, 4);

      final commitment = service.generateCommitment(position);

      final verified = service.verifyMove(
        originalHash: commitment.hash,
        revealedPosition: wrongPosition,
        revealedSalt: commitment.salt,
      );

      expect(verified, isFalse);
    });
  });
}
