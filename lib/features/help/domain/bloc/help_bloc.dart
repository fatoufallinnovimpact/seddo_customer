import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/help/domain/bloc/help_event.dart';
import 'package:seddo/features/help/domain/bloc/help_state.dart';

export 'help_event.dart';
export 'help_state.dart';

/// BLoC for Help feature following Innov & Impact Africa guidelines:
/// - Un feature = un BLoC
/// - Séparer clairement : Event, State, Bloc
/// - Communique uniquement avec les repositories
class HelpBloc extends Bloc<HelpEvent, HelpState> {
  final HelpRepository _repository;

  HelpBloc({HelpRepository? repository})
      : _repository = repository ?? HelpRepository(),
        super(const HelpState()) {
    on<HelpLoadRequested>(_onLoadRequested);
    on<HelpSearchQueryChanged>(_onSearchQueryChanged);
    on<HelpFaqToggled>(_onFaqToggled);
  }

  Future<void> _onLoadRequested(
    HelpLoadRequested event,
    Emitter<HelpState> emit,
  ) async {
    emit(state.copyWith(status: HelpStatus.loading));
    try {
      final items = await _repository.getFaqItems();
      emit(state.copyWith(
        status: HelpStatus.success,
        faqItems: items,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HelpStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSearchQueryChanged(
    HelpSearchQueryChanged event,
    Emitter<HelpState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFaqToggled(
    HelpFaqToggled event,
    Emitter<HelpState> emit,
  ) {
    final updated = state.faqItems.map((item) {
      if (item.id == event.id) {
        return item.copyWith(isExpanded: !item.isExpanded);
      }
      return item;
    }).toList();
    emit(state.copyWith(faqItems: updated));
  }
}
