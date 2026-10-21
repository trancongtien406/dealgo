import 'package:dealgo/core/storage/onboarding_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingStorage', () {
    test(
      'MemoryOnboardingStorage defaults to false and updates value',
      () async {
        final storage = MemoryOnboardingStorage();
        expect(await storage.hasSeenOnboarding(), isFalse);

        await storage.setSeenOnboarding(true);
        expect(await storage.hasSeenOnboarding(), isTrue);

        await storage.setSeenOnboarding(false);
        expect(await storage.hasSeenOnboarding(), isFalse);
      },
    );

    test('MemoryOnboardingStorage can initialize with true', () async {
      final storage = MemoryOnboardingStorage(initial: true);
      expect(await storage.hasSeenOnboarding(), isTrue);
    });

    test('profile and permissions flags default false and update', () async {
      final storage = MemoryOnboardingStorage();
      expect(await storage.hasCompletedProfileSetup(), isFalse);
      expect(await storage.hasCompletedPermissions(), isFalse);

      await storage.setCompletedProfileSetup(true);
      expect(await storage.hasCompletedProfileSetup(), isTrue);
      expect(await storage.hasCompletedPermissions(), isFalse);

      await storage.setCompletedPermissions(true);
      expect(await storage.hasCompletedPermissions(), isTrue);

      await storage.setCompletedProfileSetup(false);
      await storage.setCompletedPermissions(false);
      expect(await storage.hasCompletedProfileSetup(), isFalse);
      expect(await storage.hasCompletedPermissions(), isFalse);
    });

    test('MemoryOnboardingStorage can seed profile and permissions', () async {
      final storage = MemoryOnboardingStorage(
        profileSetupCompleted: true,
        permissionsCompleted: true,
      );
      expect(await storage.hasCompletedProfileSetup(), isTrue);
      expect(await storage.hasCompletedPermissions(), isTrue);
    });
  });
}
