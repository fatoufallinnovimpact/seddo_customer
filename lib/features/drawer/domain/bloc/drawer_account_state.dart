import 'package:equatable/equatable.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';

class DrawerAccountState extends Equatable {
  final UserModel? user;
  final String? accessToken;
  final int tripsCount;
  final bool isLoading;

  const DrawerAccountState({
    this.user,
    this.accessToken,
    this.tripsCount = 0,
    this.isLoading = false,
  });

  DrawerAccountState copyWith({
    UserModel? user,
    String? accessToken,
    int? tripsCount,
    bool? isLoading,
  }) {
    return DrawerAccountState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      tripsCount: tripsCount ?? this.tripsCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        user,
        accessToken,
        tripsCount,
        isLoading,
      ];
}
