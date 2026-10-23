import 'package:equatable/equatable.dart';

/// Model representing a FAQ entry in the Help Center.
/// Follows Innov & Impact Africa guidelines (data/models/).
class FaqItemModel extends Equatable {
  final String id;
  final String questionKey;
  final String answerKey;
  final bool isExpanded;

  const FaqItemModel({
    required this.id,
    required this.questionKey,
    required this.answerKey,
    this.isExpanded = false,
  });

  factory FaqItemModel.fromJson(Map<String, dynamic> json) {
    return FaqItemModel(
      id: json['id'] as String? ?? '',
      questionKey: json['question_key'] as String? ?? '',
      answerKey: json['answer_key'] as String? ?? '',
      isExpanded: json['is_expanded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_key': questionKey,
      'answer_key': answerKey,
      'is_expanded': isExpanded,
    };
  }

  FaqItemModel copyWith({
    String? id,
    String? questionKey,
    String? answerKey,
    bool? isExpanded,
  }) {
    return FaqItemModel(
      id: id ?? this.id,
      questionKey: questionKey ?? this.questionKey,
      answerKey: answerKey ?? this.answerKey,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  List<Object?> get props => [id, questionKey, answerKey, isExpanded];
}
