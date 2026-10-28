import 'package:dealgo/core/format/date_time_format.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA smoke: home "Gần đây" showed raw ISO time and a doubled address; the
/// GPS pickup kept a postal code and "Hai Chau" without accents.
void main() {
  group('cleanPlaceText', () {
    test('drops postal codes, Việt Nam and restores district accents', () {
      expect(
        cleanPlaceText(
          'Đường Nguyễn Văn Linh, Bình Hiên, 50200, Hai Chau, Đà Nẵng, Việt Nam',
        ),
        'Đường Nguyễn Văn Linh, Bình Hiên, Hải Châu, Đà Nẵng',
      );
      expect(
        cleanPlaceText('Trần Phú, 50200 Hai Chau, Đà Nẵng 550000'),
        'Trần Phú, Hải Châu, Đà Nẵng',
      );
    });

    test('restores TP.HCM and Hà Nội district accents', () {
      expect(
        cleanPlaceText('12 Nguyễn Huệ, Quan 1, Ho Chi Minh City, 700000'),
        '12 Nguyễn Huệ, Quận 1, Thành phố Hồ Chí Minh',
      );
      expect(
        cleanPlaceText('Phan Xích Long, Phu Nhuan, Thu Duc'),
        'Phan Xích Long, Phú Nhuận, Thủ Đức',
      );
      expect(
        cleanPlaceText('Tràng Tiền, Hoan Kiem, Ha Noi 100000'),
        'Tràng Tiền, Hoàn Kiếm, Hà Nội',
      );
      expect(
        cleanPlaceText('Xuân Thủy, Quan Cau Giay, Hanoi'),
        'Xuân Thủy, Quận Cầu Giấy, Hà Nội',
      );
    });

    test('removes a segment repeated back to back, keeps house number', () {
      expect(
        cleanPlaceText(
          '3 Nguyễn Văn Linh, 3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
        ),
        '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      );
    });

    test('formatPlaceLabel applies the cleanup', () {
      expect(
        formatPlaceLabel(
          'Đường Nguyễn Văn Linh',
          'Đường Nguyễn Văn Linh, Bình Hiên, 50200, Hai Chau, Đà Nẵng, Việt Nam',
        ),
        'Đường Nguyễn Văn Linh, Bình Hiên, Hải Châu, Đà Nẵng',
      );
    });
  });

  group('formatRecentTime (Asia/Ho_Chi_Minh)', () {
    final now = DateTime.utc(2026, 10, 28, 14, 30); // 21:30 VN
    String? f(String iso) =>
        formatRecentTime(iso, today: 'Hôm nay', yesterday: 'Hôm qua', now: now);

    test('today / yesterday / older in Vietnam time', () {
      expect(f('2026-10-28T13:22:52.958Z'), 'Hôm nay · 20:22');
      expect(f('2026-10-27T16:59:00Z'), 'Hôm qua · 23:59');
      expect(f('2026-10-27T17:05:00Z'), 'Hôm nay · 00:05');
      expect(f('2026-10-20T01:00:00Z'), '20/10 · 08:00');
      expect(f('2025-12-31T01:00:00Z'), '31/12/2025 · 08:00');
    });

    test('non-timestamps return null', () {
      expect(f('ride-1'), isNull);
    });
  });
}
