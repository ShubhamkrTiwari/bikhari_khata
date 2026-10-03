import 'group.dart';

/// A real money transfer between two people that settles part of a debt.
/// [from] pays [to] the [amount], which reduces [from]'s debt.
class Payment {
  final String id;
  final String from;
  final String to;
  final double amount;
  final DateTime date;
  final String note;
  final String groupId;

  const Payment({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.note = '',
    this.groupId = kGeneralGroupId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
    'groupId': groupId,
  };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    note: (json['note'] as String?) ?? '',
    groupId: (json['groupId'] as String?) ?? kGeneralGroupId,
  );
}
