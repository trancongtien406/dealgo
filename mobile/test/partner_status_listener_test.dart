import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/onboarding/presentation/utils/partner_status_listener.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with WidgetsBindingObserver, PartnerStatusListener<_Probe> {
  @override
  String get partnerStatusRole => 'MERCHANT';
  @override
  bool get pendingStatusActive => true;
  @override
  Future<void> refreshPendingStatus() async => widget.onRefresh();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  Future<(FakeSnapshotRealtime, List<int>)> mount(WidgetTester tester) async {
    final rt = FakeSnapshotRealtime();
    final calls = <int>[];
    await tester.pumpWidget(
      RepositoryProvider<SnapshotRealtime>.value(
        value: rt,
        child: _Probe(() => calls.add(1)),
      ),
    );
    return (rt, calls);
  }

  testWidgets('does not poll: no refresh while time passes', (tester) async {
    final (_, calls) = await mount(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, isEmpty);
  });

  testWidgets('refreshes on partnerStatus push for its role only', (
    tester,
  ) async {
    final (rt, calls) = await mount(tester);
    rt.emitPartnerStatus(
      const PartnerStatusHint(
        applicationId: 'a',
        role: 'DRIVER',
        status: 'APPROVED',
      ),
    );
    await tester.pump();
    expect(calls, isEmpty);
    rt.emitPartnerStatus(
      const PartnerStatusHint(
        applicationId: 'a',
        role: 'MERCHANT',
        status: 'APPROVED',
      ),
    );
    await tester.pump();
    expect(calls, hasLength(1));
  });

  testWidgets('refreshes on socket reconnect and app resume', (tester) async {
    final (rt, calls) = await mount(tester);
    rt.emitReconnect();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, hasLength(2));
  });

  test('parsePartnerStatusHint validates payload', () {
    expect(
      parsePartnerStatusHint({
        'applicationId': 'a',
        'role': 'DRIVER',
        'status': 'REJECTED',
      })?.status,
      'REJECTED',
    );
    expect(parsePartnerStatusHint({'role': 'DRIVER'}), isNull);
    expect(parsePartnerStatusHint('x'), isNull);
  });
}
