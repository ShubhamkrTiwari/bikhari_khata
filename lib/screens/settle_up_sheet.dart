import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/group.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../utils/format.dart';

/// Bottom sheet to record or edit an actual payment that settles a debt.
/// Optionally pass [fromId], [toId] and [amount] to prefill (e.g. from a
/// suggested settlement). Pass [existing] to edit a recorded payment.
Future<void> showSettleUpSheet(
  BuildContext context, {
  String? fromId,
  String? toId,
  double? amount,
  Payment? existing,
}) {
  final mediaCtx = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(mediaCtx).viewInsets.bottom + 20,
      ),
      child: _SettleUpForm(
        fromId: fromId,
        toId: toId,
        amount: amount,
        existing: existing,
      ),
    ),
  );
}

class _SettleUpForm extends StatefulWidget {
  final String? fromId;
  final String? toId;
  final double? amount;
  final Payment? existing;

  const _SettleUpForm({
    this.fromId,
    this.toId,
    this.amount,
    this.existing,
  });

  @override
  State<_SettleUpForm> createState() => _SettleUpFormState();
}

class _SettleUpFormState extends State<_SettleUpForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String? _from;
  late String? _to;
  late DateTime _date;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final members = context.read<ExpenseController>().activeMembers;
    _from = e?.from ?? widget.fromId ?? members.firstOrNull?.id;
    _to = e?.to ??
        widget.toId ??
        members.where((p) => p.id != _from).firstOrNull?.id;
    _date = e?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: (e?.amount ?? widget.amount) != null
          ? (e?.amount ?? widget.amount)!.toStringAsFixed(2)
          : '',
    );
    _noteController = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = context.read<ExpenseController>().activeMembers;

    if (members.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'You need at least two members in this group to record a payment.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'Edit payment' : 'Settle up',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_isEditing)
                IconButton(
                  tooltip: 'Delete payment',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _delete,
                ),
            ],
          ),
          Text(
            'Record who actually paid whom.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _personDropdown('Payer', members, _from, (v) {
                  if (v == _to) setState(() => _to = _from);
                  setState(() => _from = v);
                }),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _personDropdown('Receiver', members, _to, (v) {
                  if (v == _from) setState(() => _from = _to);
                  setState(() => _to = v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
            validator: (v) {
              final value = double.tryParse(v ?? '');
              if (value == null || value <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 12),
          InkWell(
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(formatDate(_date), style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Method / note (optional)',
              hintText: 'e.g. UPI, cash',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? 'Update payment' : 'Record payment'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _personDropdown(
    String label,
    List<Person> members,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: members
          .map(
            (p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_from == null || _to == null || _from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payer and receiver must differ.')),
      );
      return;
    }
    final controller = context.read<ExpenseController>();
    final payment = Payment(
      id: widget.existing?.id ?? controller.newId(),
      from: _from!,
      to: _to!,
      amount: double.parse(_amountController.text),
      date: _date,
      note: _noteController.text.trim(),
      groupId:
          widget.existing?.groupId ??
          controller.activeGroupId ??
          kGeneralGroupId,
    );
    if (_isEditing) {
      controller.updatePayment(payment);
    } else {
      controller.addPayment(payment);
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    final controller = context.read<ExpenseController>();
    controller.removePayment(existing.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.addPayment(existing),
        ),
      ),
    );
  }
}
