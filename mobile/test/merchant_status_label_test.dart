import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:dealgo/features/merchant/presentation/widgets/merchant_widgets.dart';

void main() {
  test(
    'cancelled/rejected orders show a localized label, not the raw enum',
    () {
      final l10n = AppLocalizationsVi();
      expect(merchantStatusLabel(l10n, 'CANCELLED'), 'Đã hủy');
      expect(merchantStatusLabel(l10n, 'REJECTED'), 'Đã hủy');
    },
  );
}
