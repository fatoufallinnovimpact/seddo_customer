import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/data/services/activity_service.dart';

abstract class ActivityRepository {
  bool get isUsingRemoteData;
  Future<List<ActivityRideItem>> getRidesHistory({int limit = 50});
  Future<ActivityRideItem?> getRideDetails(String id);
  Future<ActivitySummary> getSummary({
    List<ActivityRideItem>? rides,
    List<ActivityRefundItem>? refunds,
  });
  Future<ActivityRideItem?> getRecentRide({List<ActivityRideItem>? rides});
  Future<List<ActivityRideItem>> getPastRides({
    List<ActivityRideItem>? allRides,
    int page = 1,
    int pageSize = 3,
  });
  Future<int> getTotalPastRidesCount({List<ActivityRideItem>? allRides});
  Future<List<ActivityRefundItem>> getRefunds({List<ActivityRideItem>? rides});
}

class ActivityRepositoryImpl implements ActivityRepository {
  final ActivityService _service;

  ActivityRepositoryImpl({
    ActivityService? service,
  }) : _service = service ?? ActivityService();

  @override
  bool get isUsingRemoteData => _service.usingRemoteData;

  @override
  Future<List<ActivityRideItem>> getRidesHistory({int limit = 50}) =>
      _service.getRidesHistory(limit: limit);

  @override
  Future<ActivityRideItem?> getRideDetails(String id) =>
      _service.getRideDetails(id);

  @override
  Future<ActivitySummary> getSummary({
    List<ActivityRideItem>? rides,
    List<ActivityRefundItem>? refunds,
  }) =>
      _service.getSummary(rides: rides, refunds: refunds);

  @override
  Future<ActivityRideItem?> getRecentRide({List<ActivityRideItem>? rides}) =>
      _service.getRecentRide(rides: rides);

  @override
  Future<List<ActivityRideItem>> getPastRides({
    List<ActivityRideItem>? allRides,
    int page = 1,
    int pageSize = 3,
  }) =>
      _service.getPastRides(
        allRides: allRides,
        page: page,
        pageSize: pageSize,
      );

  @override
  Future<int> getTotalPastRidesCount({List<ActivityRideItem>? allRides}) =>
      _service.getTotalPastRidesCount(allRides: allRides);

  @override
  Future<List<ActivityRefundItem>> getRefunds({List<ActivityRideItem>? rides}) =>
      _service.getRefunds(rides: rides);
}
