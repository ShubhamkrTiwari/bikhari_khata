import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../models/settlement.dart';

/// Central app state: groups, people, expenses, payments, balances and
/// local persistence. Balances/settlements are scoped to the active group.
class ExpenseController extends ChangeNotifier {
  static const _peopleKey = 'split_people';
  static const _expensesKey = 'split_expenses';
  static const _paymentsKey = 'split_payments';
  static const _groupsKey = 'split_groups';

  static const _palette = <int>[
    0xFF26A69A, 0xFF5C6BC0, 0xFFEC407A, 0xFFFFA726,
    0xFF7E57C2, 0xFF66BB6A, 0xFF29B6F6, 0xFFEF5350,
    0xFFAB47BC, 0xFF26C6DA,
  ];

  final List<Person> _people = [];
  final List<Expense> _expenses = [];
  final List<Payment> _payments = [];
  final List<Group> _groups = [];
  String? _activeGroupId;
  bool _loaded = false;

  List<Person> get people => List.unmodifiable(_people);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Payment> get payments => List.unmodifiable(_payments);
  List<Group> get groups => List.unmodifiable(_groups);
  bool get isLoaded => _loaded;

  // ---- Group scoping -------------------------------------------------------

  /// null means "All groups".
  String? get activeGroupId => _activeGroupId;
  Group? get activeGroup =>
      _activeGroupId == null ? null : groupById(_activeGroupId!);

  Group? groupById(String id) =>
      _groups.where((g) => g.id == id).firstOrNull;

  /// People who participate in the active scope. "All groups" returns every
  /// person; a specific group returns its members.
  List<Person> get activeMembers {
    if (_activeGroupId == null) return people;
    final group = groupById(_activeGroupId!);
    if (group == null) return people;
    return _people.where((p) => group.memberIds.contains(p.id)).toList();
  }

  List<Expense> get visibleExpenses => _activeGroupId == null
      ? _expenses
      : _expenses.where((e) => e.groupId == _activeGroupId).toList();

  List<Payment> get visiblePayments => _activeGroupId == null
      ? _payments
      : _payments.where((p) => p.groupId == _activeGroupId).toList();

  void setActiveGroup(String? id) {
    if (_activeGroupId == id) return;
    _activeGroupId = id;
    notifyListeners();
  }

  Person? personById(String id) =>
      _people.where((p) => p.id == id).firstOrNull;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString(_groupsKey);
    if (rawGroups != null) {
      _groups.addAll(
        (jsonDecode(rawGroups) as List)
            .map((e) => Group.fromJson(e as Map<String, dynamic>)),
      );
    }
    // Always keep the default General group present.
    if (_groups.where((g) => g.id == kGeneralGroupId).isEmpty) {
      _groups.insert(
        0,
        const Group(
          id: kGeneralGroupId,
          name: 'General',
          emoji: '💸',
          colorValue: 0xFF00897B,
        ),
      );
    }

    final rawData = prefs.getString(_peopleKey);
    if (rawData != null) {
      _people.addAll(
        (jsonDecode(rawData) as List)
            .map((e) => Person.fromJson(e as Map<String, dynamic>)),
      );
    } else {
      _people.add(_newPerson('Me'));
    }

    final rawExpenses = prefs.getString(_expensesKey);
    if (rawExpenses != null) {
      _expenses.addAll(
        (jsonDecode(rawExpenses) as List).map(
          (e) => Expense.fromJson(e as Map<String, dynamic>),
        ),
      );
    }
    _expenses.sort((a, b) => b.date.compareTo(a.date));

    final rawPayments = prefs.getString(_paymentsKey);
    if (rawPayments != null) {
      _payments.addAll(
        (jsonDecode(rawPayments) as List).map(
          (e) => Payment.fromJson(e as Map<String, dynamic>),
        ),
      );
    }
    _payments.sort((a, b) => b.date.compareTo(a.date));

    // Backfill: any group without explicit members includes everyone so that
    // legacy / default groups stay usable.
    var changed = false;
    for (var i = 0; i < _groups.length; i++) {
      if (_groups[i].memberIds.isEmpty) {
        _groups[i] = _groups[i].copyWith(
          memberIds: _people.map((p) => p.id).toList(),
        );
        changed = true;
      }
    }
    if (changed) {
      _loaded = true;
      await _persist();
    }

    _loaded = true;
    notifyListeners();
  }

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_people.length + _expenses.length}';

  String newId() => _generateId();

  Person _newPerson(String name) => Person(
    id: _generateId(),
    name: name,
    colorValue: _palette[_people.length % _palette.length],
  );

  // ---- People --------------------------------------------------------------

  Future<void> addPerson(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final person = _newPerson(trimmed);
    _people.add(person);
    // New people join every existing group by default.
    for (var i = 0; i < _groups.length; i++) {
      _groups[i] = _groups[i].copyWith(
        memberIds: [..._groups[i].memberIds, person.id],
      );
    }
    notifyListeners();
    await _persist();
  }

  Future<void> renamePerson(String id, String name) async {
    final index = _people.indexWhere((p) => p.id == id);
    if (index == -1 || name.trim().isEmpty) return;
    _people[index] = _people[index].copyWith(name: name.trim());
    notifyListeners();
    await _persist();
  }

  Future<void> removePerson(String id) async {
    _people.removeWhere((p) => p.id == id);
    _expenses.removeWhere(
      (e) => e.paidBy == id || e.splits.any((s) => s.personId == id),
    );
    _payments.removeWhere((p) => p.from == id || p.to == id);
    for (var i = 0; i < _groups.length; i++) {
      _groups[i] = _groups[i].copyWith(
        memberIds: _groups[i].memberIds.where((m) => m != id).toList(),
      );
    }
    notifyListeners();
    await _persist();
  }

  // ---- Groups --------------------------------------------------------------

  Future<void> addGroup(
    String name, {
    String emoji = '👥',
    int? colorValue,
    List<String>? memberIds,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _groups.add(
      Group(
        id: _generateId(),
        name: trimmed,
        emoji: emoji,
        colorValue: colorValue ?? _palette[_groups.length % _palette.length],
        memberIds: memberIds ?? _people.map((p) => p.id).toList(),
      ),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updateGroup(Group updated) async {
    final index = _groups.indexWhere((g) => g.id == updated.id);
    if (index == -1) return;
    _groups[index] = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> removeGroup(String id) async {
    if (id == kGeneralGroupId) return; // General is permanent.
    _groups.removeWhere((g) => g.id == id);
    _expenses.removeWhere((e) => e.groupId == id);
    _payments.removeWhere((p) => p.groupId == id);
    if (_activeGroupId == id) _activeGroupId = null;
    notifyListeners();
    await _persist();
  }

  // ---- Expenses ------------------------------------------------------------

  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _persist();
  }

  Future<void> removeExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  // ---- Payments ------------------------------------------------------------

  Future<void> addPayment(Payment payment) async {
    _payments.insert(0, payment);
    _payments.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _persist();
  }

  Future<void> updatePayment(Payment payment) async {
    final index = _payments.indexWhere((p) => p.id == payment.id);
    if (index == -1) return;
    _payments[index] = payment;
    _payments.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _persist();
  }

  Future<void> removePayment(String id) async {
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groupsKey,
      jsonEncode(_groups.map((g) => g.toJson()).toList()),
    );
    await prefs.setString(
      _peopleKey,
      jsonEncode(_people.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      _expensesKey,
      jsonEncode(_expenses.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _paymentsKey,
      jsonEncode(_payments.map((p) => p.toJson()).toList()),
    );
  }

  // ---- Derived values (scoped to active group) -----------------------------

  double get totalSpent =>
      visibleExpenses.fold<double>(0, (sum, e) => sum + e.totalAmount);

  int get expenseCount => visibleExpenses.length;

  int get memberCount => _people.length;

  /// Distinct participants involved in the visible group's expenses.
  int get activeMemberCount {
    final ids = <String>{};
    for (final e in visibleExpenses) {
      ids.add(e.paidBy);
      for (final s in e.splits) {
        ids.add(s.personId);
      }
    }
    return ids.length;
  }

  /// Net balance per person. Positive => they are owed money,
  /// negative => they need to pay. Recorded payments are applied here.
  /// Scoped to the active group's members.
  Map<String, double> get balances {
    final result = <String, double>{for (final p in activeMembers) p.id: 0.0};
    for (final e in visibleExpenses) {
      result[e.paidBy] = (result[e.paidBy] ?? 0) + e.totalAmount;
      for (final s in e.splits) {
        result[s.personId] = (result[s.personId] ?? 0) - s.amount;
      }
    }
    for (final p in visiblePayments) {
      result[p.from] = (result[p.from] ?? 0) + p.amount;
      result[p.to] = (result[p.to] ?? 0) - p.amount;
    }
    return result;
  }

  List<BalancedPerson> get balancedPeople {
    final bal = balances;
    final list = activeMembers
        .map((p) => BalancedPerson(person: p, net: bal[p.id] ?? 0))
        .toList();
    list.sort((a, b) => b.net.compareTo(a.net));
    return list;
  }

  /// Total money that is still outstanding in the active scope.
  double get outstanding =>
      balancedPeople.fold<double>(0, (s, b) => s + (b.net > 0 ? b.net : 0));

  Map<String, double> get categoryTotals {
    final result = <String, double>{};
    for (final e in visibleExpenses) {
      result[e.category] = (result[e.category] ?? 0) + e.totalAmount;
    }
    return result;
  }

  /// Monthly totals (newest first) for a lightweight trend chart.
  List<TrendPoint> get monthlyTrend {
    final map = <String, double>{};
    final labelOf = <String, String>{};
    for (final e in visibleExpenses) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + e.totalAmount;
      labelOf[key] =
          '${_monthNames[e.date.month - 1]} ${e.date.year.toString().substring(2)}';
    }
    final points = map.entries
        .map((e) => TrendPoint(key: e.key, label: labelOf[e.key]!, value: e.value))
        .toList();
    points.sort((a, b) => b.key.compareTo(a.key));
    return points;
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Greedy debt simplification producing minimal transfer suggestions.
  List<Settlement> get settlements {
    final bal = Map<String, double>.from(balances);
    final creditors = <_DebtEntry>[];
    final debtors = <_DebtEntry>[];
    bal.forEach((id, value) {
      if (value > 0.01) {
        creditors.add(_DebtEntry(id, value));
      } else if (value < -0.01) {
        debtors.add(_DebtEntry(id, -value));
      }
    });

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final result = <Settlement>[];
    int ci = 0, di = 0;
    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];
      final pay = min(creditor.amount, debtor.amount);
      result.add(Settlement(from: debtor.id, to: creditor.id, amount: pay));
      creditor.amount -= pay;
      debtor.amount -= pay;
      if (creditor.amount <= 0.01) ci++;
      if (debtor.amount <= 0.01) di++;
    }
    return result;
  }

  String get groupName => activeGroup?.name ?? 'All groups';

  /// Build a CSV export of the currently visible expenses.
  String buildCsv() {
    String esc(String s) {
      final needs = s.contains(',') || s.contains('"') || s.contains('\n');
      final quoted = s.replaceAll('"', '""');
      return needs ? '"$quoted"' : quoted;
    }

    final rows = <List<String>>[
      [
        'Title',
        'Category',
        'Group',
        'Paid By',
        'Amount',
        'Date',
        'Split (person:amount)',
        'Note',
      ],
    ];
    for (final e in visibleExpenses) {
      final payer = personById(e.paidBy)?.name ?? e.paidBy;
      final splitsText = e.splits
          .map((s) => '${personById(s.personId)?.name ?? s.personId}=${s.amount.toStringAsFixed(2)}')
          .join('; ');
      final group = groupById(e.groupId)?.name ?? e.groupId;
      rows.add([
        e.title,
        e.category,
        group,
        payer,
        e.totalAmount.toStringAsFixed(2),
        e.date.toIso8601String().substring(0, 10),
        splitsText,
        e.note,
      ]);
    }
    return rows.map((r) => r.map(esc).join(',')).join('\n');
  }
}

class BalancedPerson {
  final Person person;
  final double net;
  const BalancedPerson({required this.person, required this.net});
}

class TrendPoint {
  final String key;
  final String label;
  final double value;
  const TrendPoint({
    required this.key,
    required this.label,
    required this.value,
  });
}

class _DebtEntry {
  final String id;
  double amount;
  _DebtEntry(this.id, this.amount);
}
