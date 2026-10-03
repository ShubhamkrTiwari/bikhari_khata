import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/categories.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  static Future<void> open(BuildContext context, Expense expense) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final category = categoryByName(expense.category);
    final theme = Theme.of(context);

    Person? resolve(String id) => controller.personById(id);
    final payer = resolve(expense.paidBy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, controller),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(theme, category),
          const SizedBox(height: 20),
          _infoRow(
            theme,
            icon: Icons.person_add,
            label: 'Paid by',
            value: payer == null
                ? 'Unknown'
                : '${payer.name} • ${formatMoney(expense.totalAmount)}',
            avatar: payer,
          ),
          _infoRow(
            theme,
            icon: Icons.calendar_today,
            label: 'Date',
            value: formatDateTime(expense.date),
          ),
          _infoRow(
            theme,
            icon: Icons.map_outlined,
            label: 'Group',
            value: controller.groupById(expense.groupId)?.name ?? 'General',
          ),
          if (expense.note.isNotEmpty)
            _infoRow(
              theme,
              icon: Icons.sticky_note_2_outlined,
              label: 'Note',
              value: expense.note,
            ),
          const SizedBox(height: 24),
          Text(
            'SPLIT BREAKDOWN',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final s in expense.splits)
                  ListTile(
                    leading: () {
                      final p = resolve(s.personId);
                      return p == null
                          ? const Icon(Icons.person_off)
                          : PersonAvatar(person: p, radius: 20);
                    }(),
                    title: Text(resolve(s.personId)?.name ?? 'Unknown'),
                    subtitle: Text('owes ${_sharePercent(context, s.amount)}'),
                    trailing: Text(
                      formatMoney(s.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                const Divider(),
                ListTile(
                  title: const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    formatMoney(expense.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sharePercent(BuildContext context, double amount) {
    final pct = (amount / expense.totalAmount * 100);
    return '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%';
  }

  Widget _header(ThemeData theme, ExpenseCategory category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            category.color,
            Color.lerp(category.color, Colors.black, 0.25)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expense.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(expense.totalAmount),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Person? avatar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null)
            PersonAvatar(person: avatar, radius: 18)
          else
            Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '"${expense.title}" will be removed from all balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.removeExpense(expense.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
