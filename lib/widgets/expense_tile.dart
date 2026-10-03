import 'package:flutter/material.dart';

import '../models/categories.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../utils/format.dart';

/// A tappable summary card for a single expense.
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final Person? Function(String id) resolvePerson;
  final VoidCallback onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.resolvePerson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = categoryByName(expense.category);
    final payer = resolvePerson(expense.paidBy);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.15),
          foregroundColor: category.color,
          child: Icon(category.icon),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${expense.splits.length} people • '
          '${formatDate(expense.date)}'
          '${payer != null ? ' • paid by ${payer.name}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          formatMoney(expense.totalAmount),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
