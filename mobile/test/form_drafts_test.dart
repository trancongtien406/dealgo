import 'dart:typed_data';

import 'package:dealgo/core/drafts/draft_store.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/onboarding/data/datasources/fake_partner_applications_client.dart';
import 'package:dealgo/features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_onboarding.dart';
import 'package:dealgo/features/onboarding/domain/usecases/submit_partner_application.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/partner_draft_support.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:flutter_test/flutter_test.dart';

final _jpeg = PickedDocumentImage(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 9, 8, 7]),
  contentType: 'image/jpeg',
);

DriverKycCubit _driver(
  DraftStore store, {
  String? user = 'user-1',
  FakePartnerApplicationsClient? partners,
}) => DriverKycCubit(
  draftStore: store,
  draftOwner: () => user,
  submitPartnerApplication: partners == null
      ? null
      : SubmitPartnerApplication(PartnerApplicationsRepositoryImpl(partners)),
  accessToken: () => 'token',
  useMock: partners == null,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 350));

void main() {
  group('DraftCipher', () {
    test('round-trips and rejects tampering or a wrong key', () {
      final key = DraftCipher.randomBytes(32);
      final cipher = DraftCipher(key);
      final plain = Uint8List.fromList(List.generate(4000, (i) => i % 251));
      final sealed = cipher.seal(plain);
      expect(sealed.length, plain.length + 12 + 16);
      expect(cipher.open(sealed), plain);
      // Nonce is random: same input never yields the same file.
      expect(cipher.seal(plain), isNot(sealed));
      final tampered = Uint8List.fromList(sealed)..[40] ^= 1;
      expect(() => cipher.open(tampered), throwsA(anything));
      expect(
        () => DraftCipher(DraftCipher.randomBytes(32)).open(sealed),
        throwsA(anything),
      );
    });
  });

  group('DraftKeeper', () {
    test(
      'debounces, expires old drafts, and a clear beats a late write',
      () async {
        final store = MemoryDraftStore();
        final keeper = DraftKeeper(store: store, key: 'k');
        keeper.schedule({'a': '1'});
        keeper.schedule({'a': '2'});
        expect(store.fields, isEmpty);
        await keeper.flush();
        expect(store.fields['k']!['a'], '2');

        keeper.schedule({'a': '3'});
        await keeper.clear();
        await _settle();
        expect(store.fields, isEmpty);

        store.fields['k'] = {'a': 'old', 'savedAt': '2020-01-01T00:00:00.000'};
        expect(await keeper.load(), isNull);
        expect(store.fields, isEmpty);
      },
    );
  });

  group('driver KYC draft', () {
    test('survives an app kill and restores fields, step and photos', () async {
      final store = MemoryDraftStore();
      final first = _driver(store)
        ..startDraft()
        ..toggleRide()
        ..setFullName('Trần Công Tiến')
        ..setIdNumber('079123456789')
        ..setBankAccountNumber('0123456789')
        ..attachDocument(PartnerDocumentKind.idFront, _jpeg)
        ..goToStep(DriverKycStep.license);
      await first.close(); // app killed: pending save flushes
      final key = partnerDraftKey('DRIVER', 'user-1');
      expect(store.fields[key]!['step'], 'license');
      expect(store.blobs[key]![PartnerDocumentKind.idFront], _jpeg.bytes);

      final reopened = _driver(store);
      expect(await reopened.loadDraft(), isTrue);
      reopened.restoreDraft();
      final s = reopened.state;
      expect(s.status, PartnerApplicationStatus.draft);
      expect(s.step, DriverKycStep.license);
      expect(s.fullName, 'Trần Công Tiến');
      expect(s.idNumber, '079123456789');
      expect(s.bankAccountNumber, '0123456789');
      expect(
        s.documents.picked[PartnerDocumentKind.idFront]!.bytes,
        _jpeg.bytes,
      );
      await reopened.close();
    });

    test('drafts are per user and step-1 drafts are not offered', () async {
      final store = MemoryDraftStore();
      final a = _driver(store)
        ..startDraft()
        ..goToStep(DriverKycStep.bank);
      await a.close();
      expect(await _driver(store, user: 'user-2').loadDraft(), isFalse);
      expect(await _driver(store, user: null).loadDraft(), isFalse);

      final b = _driver(store, user: 'user-3')
        ..startDraft()
        ..setFullName('A');
      await b.close();
      expect(await _driver(store, user: 'user-3').loadDraft(), isFalse);
    });

    test('"Làm lại từ đầu" clears fields and photos', () async {
      final store = MemoryDraftStore();
      final first = _driver(store)
        ..startDraft()
        ..attachDocument(PartnerDocumentKind.selfie, _jpeg)
        ..goToStep(DriverKycStep.vehicle);
      await first.close();
      final again = _driver(store);
      expect(await again.loadDraft(), isTrue);
      await again.discardDraft();
      expect(store.fields, isEmpty);
      expect(store.blobs, isEmpty);
      expect(await _driver(store).loadDraft(), isFalse);
    });

    test('a successful submit clears the draft', () async {
      final store = MemoryDraftStore();
      final partners = FakePartnerApplicationsClient();
      final cubit = _driver(store, partners: partners)
        ..startDraft()
        ..setVehicleClass(code: 'MOTORBIKE', name: 'Xe máy')
        ..goToStep(DriverKycStep.review);
      await cubit.submit();
      await cubit.close();
      expect(partners.submitCalls, hasLength(1));
      expect(cubit.state.status, PartnerApplicationStatus.pending);
      expect(store.fields, isEmpty);
    });

    test(
      'a duplicate submit (409 already submitted) counts as success',
      () async {
        final store = MemoryDraftStore();
        final partners = FakePartnerApplicationsClient(
          submitError: const ApiException(
            statusCode: 409,
            message: 'already submitted',
            errorCode: partnerAlreadySubmitted,
          ),
        );
        final cubit = _driver(store, partners: partners)
          ..startDraft()
          ..setVehicleClass(code: 'MOTORBIKE', name: 'Xe máy')
          ..goToStep(DriverKycStep.review);
        await Future.wait([cubit.submit(), cubit.submit()]);
        await cubit.close();
        expect(partners.submitCalls, hasLength(1));
        expect(cubit.state.status, PartnerApplicationStatus.pending);
        expect(cubit.state.submitError, isNull);
        expect(store.fields, isEmpty);
      },
    );
  });

  group('merchant KYB draft', () {
    test('survives an app kill and restores shop fields', () async {
      final store = MemoryDraftStore();
      final first =
          MerchantKybCubit(
              draftStore: store,
              draftOwner: () => 'user-1',
              useMock: true,
            )
            ..startDraft()
            ..setShopName('Quán Bún Bò ')
            ..setShopAddress('12 Lê Lợi, Q1')
            ..setRepresentativeName('Tiến')
            ..attachDocument(PartnerDocumentKind.businessLicense, _jpeg)
            ..goToStep(MerchantKybStep.representative);
      await first.close();

      final reopened = MerchantKybCubit(
        draftStore: store,
        draftOwner: () => 'user-1',
        useMock: true,
      );
      expect(await reopened.loadDraft(), isTrue);
      reopened.restoreDraft();
      expect(reopened.state.step, MerchantKybStep.representative);
      expect(reopened.state.shopName, 'Quán Bún Bò ');
      expect(reopened.state.shopAddress, '12 Lê Lợi, Q1');
      expect(
        reopened.state.documents.picked[PartnerDocumentKind.businessLicense],
        isNotNull,
      );
      reopened.goToStep(MerchantKybStep.review);
      await reopened.submit();
      await reopened.close();
      expect(store.fields, isEmpty);
    });
  });
}
