import '../../domain/entities/history_models.dart';
import 'history_remote_datasource.dart';

class FakeHistoryClient implements HistoryClient {
  FakeHistoryClient({
    this.rides = const [
      HistoryItem(
        id: 'ride-hist-1',
        kind: HistoryKind.ride,
        title: 'Chuyến đi đến sân bay',
        meta: 'Hôm qua · 14:32 · Xe máy',
        status: 'COMPLETED',
        amountVnd: 72000,
      ),
    ],
    this.food = const [
      HistoryItem(
        id: 'food-hist-1',
        kind: HistoryKind.food,
        title: 'Bún Bò Huế Ô Cồ',
        meta: '10/10 · 12:45 · 3 món',
        status: 'DELIVERED',
        amountVnd: 130000,
      ),
    ],
  });

  List<HistoryItem> rides;
  List<HistoryItem> food;
  final List<String> rideCalls = [];
  final List<String> foodCalls = [];

  @override
  Future<List<HistoryItem>> listRideHistory(String accessToken) async {
    rideCalls.add(accessToken);
    return rides;
  }

  @override
  Future<List<HistoryItem>> listFoodHistory(String accessToken) async {
    foodCalls.add(accessToken);
    return food;
  }
}
