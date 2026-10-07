import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/categories.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';

enum _SplitMode { equal, exact, shares }

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
  );

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _category = kExpenseCategories.first.name;
  DateTime _date = DateTime.now();
  String? _paidBy;
  String? _groupId;
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _exactInputs = {};
  final Map<String, TextEditingController> _shareInputs = {};
  _SplitMode _mode = _SplitMode.equal;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _exactInputs.values) {
      c.dispose();
    }
    for (final c in _shareInputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => double.tryParse(_amountController.text) ?? 0;

  List<Person> get _people => context.read<ExpenseController>().activeMembers;

  String get _effectiveGroupId =>
      _groupId ??
      context.read<ExpenseController>().activeGroupId ??
      kGeneralGroupId;

  double get _perPersonEqual =>
      _selected.isEmpty ? 0 : _total / _selected.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Save',
            onPressed: _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAmountField(theme),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'What was it for?',
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g. Dinner at Pub'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title required' : null,
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Category',
              child: _buildCategoryChips(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Group',
              child: _buildGroupSelector(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Paid by',
              child: _buildPayerSelector(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Split between',
              child: _buildParticipants(),
            ),
            const SizedBox(height: 12),
            _buildSplitDetails(theme),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Date',
              child: _buildDateSelector(theme),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Note (optional)',
              child: TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(hintText: 'Add a note'),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Save Expense'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    final scheme = theme.colorScheme;
    final showPerPerson = _selected.isNotEmpty && _total > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.75)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w900,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorStyle: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    if (value == null || value <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Text(
              showPerPerson
                  ? '₹${_perPersonEqual.toStringAsFixed(2)} per person · ${_selected.length} ${_selected.length == 1 ? 'person' : 'people'}'
                  : 'Select people below to see the per-person split',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kExpenseCategories.map((c) {
        final selected = c.name == _category;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _category = c.name),
          avatar: Icon(
            c.icon,
            color: selected ? Colors.white : c.color,
            size: 18,
          ),
          label: Text(c.name),
          selectedColor: c.color,
          labelStyle: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupSelector() {
    final groups = context.read<ExpenseController>().groups;
    final current = _effectiveGroupId;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: groups.map((g) {
        final selected = g.id == current;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _groupId = g.id),
          label: Text('${g.emoji} ${g.name}'),
          selectedColor: g.color,
          labelStyle: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayerSelector() {
    if (_people.isEmpty) {
      return const Text(
        'No members in this group. Add them from the Groups tab.',
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _people.map((p) {
        final isMe = p.id == (_paidBy ?? _people.first.id);
        return GestureDetector(
          onTap: () => setState(() => _paidBy = p.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? p.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isMe ? p.color : Colors.grey.shade400,
                width: isMe ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonAvatar(person: p, radius: 14),
                const SizedBox(width: 8),
                Text(
                  p.name,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                    color: isMe ? p.color : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParticipants() {
    return Column(
      children: _people.map((p) {
        final checked = _selected.contains(p.id);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: checked,
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(p.id);
            } else {
              _selected.remove(p.id);
            }
          }),
          title: Row(
            children: [
              PersonAvatar(person: p, radius: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(p.name)),
            ],
          ),
          secondary: checked && _mode == _SplitMode.equal
              ? Text(
                  formatMoney(_perPersonEqual),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildSplitDetails(ThemeData theme) {
    if (_selected.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      title: 'How to split',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_SplitMode>(
            segments: const [
              ButtonSegment(value: _SplitMode.equal, label: Text('Equal')),
              ButtonSegment(value: _SplitMode.exact, label: Text('Exact')),
              ButtonSegment(value: _SplitMode.shares, label: Text('Shares')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == _SplitMode.equal)
            Text(
              'Everyone pays ${formatMoney(_perPersonEqual)} equally.',
              style: theme.textTheme.bodyMedium,
            )
          else
            _buildManualSplitInputs(theme),
        ],
      ),
    );
  }

  Widget _buildManualSplitInputs(ThemeData theme) {
    final members = _people.where((p) => _selected.contains(p.id)).toList();
    final inputs = _mode == _SplitMode.exact ? _exactInputs : _shareInputs;
    for (final m in members) {
      inputs.putIfAbsent(m.id, () => TextEditingController());
    }
    inputs.removeWhere(
      (id, c) => !_selected.contains(id),
    );

    final allocated = _allocatedValue(members);
    final diff = _total - allocated;

    return Column(
      children: [
        ...members.map((m) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                PersonAvatar(person: m, radius: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(m.name)),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: inputs[m.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: _mode == _SplitMode.exact ? '₹ ' : null,
                      hintText: _mode == _SplitMode.exact ? '0' : '1',
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _mode == _SplitMode.exact ? 'Allocated' : 'Total shares',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              _mode == _SplitMode.exact
                  ? formatMoney(allocated)
                  : '${allocated.toInt()} shares',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (_mode == _SplitMode.exact)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              diff.abs() < 0.01
                  ? 'Perfectly split.'
                  : (diff > 0
                        ? '${formatMoney(diff)} still to assign'
                        : '${formatMoney(-diff)} over the total'),
              style: TextStyle(
                color: diff.abs() < 0.01 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// For exact mode returns the summed amount; for shares mode returns the
  /// summed share count (used only for display purposes).
  double _allocatedValue(List<Person> members) {
    if (_mode == _SplitMode.exact) {
      return members.fold<double>(
        0,
        (sum, m) =>
            sum + (double.tryParse(_exactInputs[m.id]?.text ?? '') ?? 0),
      );
    }
    return members.fold<double>(
      0,
      (sum, m) => sum + (double.tryParse(_shareInputs[m.id]?.text ?? '') ?? 0),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(formatDate(_date), style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final members = _people.where((p) => _selected.contains(p.id)).toList();
    if (members.isEmpty) {
      _showSnack('Select at least one person to split with.');
      return;
    }
    final paidById = _paidBy ?? _people.first.id;
    final total = double.tryParse(_amountController.text) ?? 0;
    if (total <= 0) {
      _showSnack('Enter a valid amount.');
      return;
    }

    final List<Split> splits;
    if (_mode == _SplitMode.equal) {
      final per = total / members.length;
      // Distribute leftover cents to the first members.
      splits = List.generate(members.length, (i) {
        final amount = (per * 100).floorToDouble() / 100;
        return Split(personId: members[i].id, amount: amount);
      });
      final assigned = splits.fold<double>(0, (s, x) => s + x.amount);
      final leftover = (total - assigned);
      if (leftover > 0.001 && splits.isNotEmpty) {
        splits[0] = Split(
          personId: splits.first.personId,
          amount: splits.first.amount + leftover,
        );
      }
    } else if (_mode == _SplitMode.exact) {
      final values = members
          .map(
            (m) =>
                double.tryParse(_exactInputs[m.id]?.text ?? '') ?? 0,
          )
          .toList();
      final sum = values.fold<double>(0, (a, b) => a + b);
      if ((sum - total).abs() > 0.01) {
        _showSnack('Exact amounts must add up to the total.');
        return;
      }
      splits = [
        for (var i = 0; i < members.length; i++)
          Split(personId: members[i].id, amount: values[i]),
      ];
    } else {
      final rawShares = members
          .map(
            (m) => double.tryParse(_shareInputs[m.id]?.text ?? '') ?? 0,
          )
          .toList();
      final totalShares = rawShares.fold<double>(0, (a, b) => a + b);
      if (totalShares <= 0) {
        _showSnack('Enter shares greater than zero.');
        return;
      }
      splits = [
        for (var i = 0; i < members.length; i++)
          Split(
            personId: members[i].id,
            amount: total * rawShares[i] / totalShares,
          ),
      ];
    }

    final expense = Expense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      category: _category,
      totalAmount: total,
      paidBy: paidById,
      splits: splits,
      date: _date,
      note: _noteController.text.trim(),
      groupId: _effectiveGroupId,
    );

    context.read<ExpenseController>().addExpense(expense);
    Navigator.of(context).pop();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
