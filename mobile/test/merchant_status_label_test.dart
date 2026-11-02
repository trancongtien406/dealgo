import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:dealgo/features/merchant/presentation/widgets/merchant_widgets.dart';

void main() {
  test('merchant order statuses never expose raw API enum keys', () {
    final l10n = AppLocalizationsVi();
    expect(merchantStatusLabel(l10n, 'PLACED'), 'Chờ Shop xác nhận');
    expect(merchantStatusLabel(l10n, 'PREPARING'), 'Đang chuẩn bị');
    expect(merchantStatusLabel(l10n, 'READY'), 'Sẵn sàng giao');
    expect(merchantStatusLabel(l10n, 'ASSIGNED'), 'Đã có tài xế');
    expect(merchantStatusLabel(l10n, 'PICKED_UP'), 'Đang giao');
    expect(merchantStatusLabel(l10n, 'DELIVERED'), 'Đã giao');
    expect(merchantStatusLabel(l10n, 'FAILED'), 'Không thành công');
    expect(merchantStatusLabel(l10n, 'CANCELLED'), 'Đã hủy');
    expect(merchantStatusLabel(l10n, 'REJECTED'), 'Đã hủy');
    expect(merchantStatusLabel(l10n, 'NEW_SERVER_STATUS'), 'Đang cập nhật');
  });
}
