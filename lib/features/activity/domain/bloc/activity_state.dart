import 'package:equatable/equatable.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/domain/bloc/activity_event.dart';

abstract class ActivityState extends Equatable {
  const ActivityState();

  @override
  List<Object?> get props => [];
}

class ActivityInitialState extends ActivityState {
  const ActivityInitialState();
}

class ActivityLoadingState extends ActivityState {
  const ActivityLoadingState();
}

class ActivityLoadedState extends ActivityState {
  final ActivityTab currentTab;
  final ActivitySummary summary;
  final ActivityRideItem recentRide;
  final List<ActivityRideItem> pastRides;
  final List<ActivityRefundItem> refunds;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;

  const ActivityLoadedState({
    required this.currentTab,
    required this.summary,
    required this.recentRide,
    required this.pastRides,
    required this.refunds,
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ActivityLoadedState copyWith({
    ActivityTab? currentTab,
    ActivitySummary? summary,
    ActivityRideItem? recentRide,
    List<ActivityRideItem>? pastRides,
    List<ActivityRefundItem>? refunds,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ActivityLoadedState(
      currentTab: currentTab ?? this.currentTab,
      summary: summary ?? this.summary,
      recentRide: recentRide ?? this.recentRide,
      pastRides: pastRides ?? this.pastRides,
      refunds: refunds ?? this.refunds,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        currentTab,
        summary,
        recentRide,
        pastRides,
        refunds,
        currentPage,
        hasMore,
        isLoadingMore,
      ];
}

class ActivityErrorState extends ActivityState {
  final String message;

  const ActivityErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
