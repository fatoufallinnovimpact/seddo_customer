import 'package:equatable/equatable.dart';

enum ActivityTab {
  courses,
  remboursements,
}

abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

class ActivityLoadInitialEvent extends ActivityEvent {
  final ActivityTab initialTab;

  const ActivityLoadInitialEvent({this.initialTab = ActivityTab.courses});

  @override
  List<Object?> get props => [initialTab];
}

class ActivityChangeTabEvent extends ActivityEvent {
  final ActivityTab tab;

  const ActivityChangeTabEvent(this.tab);

  @override
  List<Object?> get props => [tab];
}

class ActivityLoadMorePastRidesEvent extends ActivityEvent {
  const ActivityLoadMorePastRidesEvent();
}

class ActivityRefreshEvent extends ActivityEvent {
  const ActivityRefreshEvent();
}
