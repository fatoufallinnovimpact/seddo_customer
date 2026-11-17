import 'package:equatable/equatable.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';

abstract class DrawerAccountEvent extends Equatable {
  const DrawerAccountEvent();

  @override
  List<Object?> get props => [];
}

class DrawerAccountLoadRequested extends DrawerAccountEvent {
  const DrawerAccountLoadRequested();
}

class DrawerAccountUserUpdated extends DrawerAccountEvent {
  final UserModel? updatedUser;

  const DrawerAccountUserUpdated({this.updatedUser});

  @override
  List<Object?> get props => [updatedUser];
}

class DrawerAccountNotificationsChanged extends DrawerAccountEvent {
  final bool? notifyPush;
  final bool? notifySms;

  const DrawerAccountNotificationsChanged({
    this.notifyPush,
    this.notifySms,
  });

  @override
  List<Object?> get props => [notifyPush, notifySms];
}
