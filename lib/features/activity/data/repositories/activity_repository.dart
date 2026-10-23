import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/data/services/activity_service.dart';

abstract class ActivityRepository {
  Future<ActivitySummary> getSummary();
  Future<ActivityRideItem> getRecentRide();
  Future<List<ActivityRideItem>> getPastRides({int page = 1, int pageSize = 3});
  Future<int> getTotalPastRidesCount();
  Future<List<ActivityRefundItem>> getRefunds();
}

class ActivityRepositoryImpl implements ActivityRepository {
  final ActivityService _service;

  ActivityRepositoryImpl({
    ActivityService? service,
  }) : _service = service ?? const ActivityService();

  @override
  Future<ActivitySummary> getSummary() => _service.getSummary();

  @override
  Future<ActivityRideItem> getRecentRide() => _service.getRecentRide();

  @override
  Future<List<ActivityRideItem>> getPastRides({
    int page = 1,
    int pageSize = 3,
  }) =>
      _service.getPastRides(page: page, pageSize: pageSize);

  @override
  Future<int> getTotalPastRidesCount() => _service.getTotalPastRidesCount();

  @override
  Future<List<ActivityRefundItem>> getRefunds() => _service.getRefunds();
}
