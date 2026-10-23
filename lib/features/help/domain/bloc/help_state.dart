import 'package:equatable/equatable.dart';
import 'package:seddo/features/help/data/models/faq_item_model.dart';

enum HelpStatus { initial, loading, success, failure }

class HelpState extends Equatable {
  final HelpStatus status;
  final List<FaqItemModel> faqItems;
  final String searchQuery;
  final String? errorMessage;

  const HelpState({
    this.status = HelpStatus.initial,
    this.faqItems = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  HelpState copyWith({
    HelpStatus? status,
    List<FaqItemModel>? faqItems,
    String? searchQuery,
    String? errorMessage,
  }) {
    return HelpState(
      status: status ?? this.status,
      faqItems: faqItems ?? this.faqItems,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, faqItems, searchQuery, errorMessage];
}
