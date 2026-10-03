import 'group.dart';

/// How an expense was divided among participants.
class Split {
  final String personId;
  final double amount;

  const Split({required this.personId, required this.amount});

  Map<String, dynamic> toJson() => {'personId': personId, 'amount': amount};

  factory Split.fromJson(Map<String, dynamic> json) => Split(
    personId: json['personId'] as String,
    amount: (json['amount'] as num).toDouble(),
  );
}

/// A single expense that is shared between people.
class Expense {
  final String id;
  final String title;
  final String category;
  final double totalAmount;
  final String paidBy;
  final List<Split> splits;
  final DateTime date;
  final String note;
  final String groupId;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.totalAmount,
    required this.paidBy,
    required this.splits,
    required this.date,
    this.note = '',
    this.groupId = kGeneralGroupId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'totalAmount': totalAmount,
    'paidBy': paidBy,
    'splits': splits.map((s) => s.toJson()).toList(),
    'date': date.toIso8601String(),
    'note': note,
    'groupId': groupId,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    totalAmount: (json['totalAmount'] as num).toDouble(),
    paidBy: json['paidBy'] as String,
    splits: (json['splits'] as List)
        .map((s) => Split.fromJson(s as Map<String, dynamic>))
        .toList(),
    date: DateTime.parse(json['date'] as String),
    note: (json['note'] as String?) ?? '',
    groupId: (json['groupId'] as String?) ?? kGeneralGroupId,
  );
}
