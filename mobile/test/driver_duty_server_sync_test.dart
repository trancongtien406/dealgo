import 'dart:async';

import 'package:dealgo/features/driver/presentation/cubit/driver_duty_cubit.dart';
import 'package:dealgo/features/presence/domain/entities/driver_service_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presence payload exposes the server online flag', () {
    expect(decodeDriverServicePrefs({'online': true}).online, isTrue);
    expect(decodeDriverServicePrefs({'rideEnabled': false}).online, isFalse);
  });

  test('duty toggle adopts server state on open and after reconnect', () async {
    bool? server = true;
    final reconnects = StreamController<void>.broadcast();
    final cubit = DriverDutyCubit(
      fetchServerOnline: () async => server,
      reconnects: reconnects.stream,
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isTrue, reason: 'app reopened while DB says online');

    server = false; // e.g. ops / auto-offline flipped it while the app slept
    reconnects.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isFalse);
    await cubit.close();
    await reconnects.close();
  });
}
