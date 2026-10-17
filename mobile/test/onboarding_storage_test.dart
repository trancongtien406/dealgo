import 'package:dealgo/core/storage/onboarding_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingStorage', () {
    test('MemoryOnboardingStorage defaults to false and updates value', () async {
      final storage = MemoryOnboardingStorage();
      expect(await storage.hasSeenOnboarding(), isFalse);

      await storage.setSeenOnboarding(true);
      expect(await storage.hasSeenOnboarding(), isTrue);

      await storage.setSeenOnboarding(false);
      expect(await storage.hasSeenOnboarding(), isFalse);
    });

    test('MemoryOnboardingStorage can initialize with true', () async {
      final storage = MemoryOnboardingStorage(initial: true);
      expect(await storage.hasSeenOnboarding(), isTrue);
    });
  });
}
