import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/categories.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../models/settlement.dart';
import '../utils/format.dart';
import '../widgets/expense_tile.dart';
import '../widgets/person_avatar.dart';
import '../widgets/stat_card.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';
import 'groups_screen.dart';
import 'people_screen.dart';
import 'settle_up_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  String _activeMonth = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ExpenseController>().load(),
    );
  }

  void _showMonth(String month) {
    setState(() {
      _activeMonth = month;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    final pages = [
      _ActivityTab(
        controller: controller,
        month: _activeMonth,
        onMonthChanged: (m) => setState(() => _activeMonth = m),
      ),
      _BalancesTab(controller: controller, onMonthSelected: _showMonth),
      const GroupsScreen(),
      const PeopleScreen(),
    ];

    return Scaffold(
      body: controller.isLoaded
          ? IndexedStack(index: _index, children: pages)
          : const _LoadingView(),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.balance_outlined),
            selectedIcon: Icon(Icons.balance),
            label: 'Balances',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'People',
          ),
        ],
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    switch (_index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => AddExpenseScreen.open(context),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => showSettleUpSheet(context),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Settle up'),
        );
      default:
        return null;
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ===========================================================================
// ACTIVITY / DASHBOARD TAB
// ===========================================================================

class _ActivityTab extends StatefulWidget {
  final ExpenseController controller;
  final String month;
  final ValueChanged<String> onMonthChanged;
  const _ActivityTab({
    required this.controller,
    required this.month,
    required this.onMonthChanged,
  });

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Expense> _filtered(ExpenseController controller) {
    final query = _searchController.text.trim().toLowerCase();
    return controller.visibleExpenses.where((e) {
      final matchMonth =
          widget.month == 'all' ||
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}' ==
              widget.month;
      final matchQuery = query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.note.toLowerCase().contains(query);
      return matchMonth && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final expenses = _filtered(controller);

    return CustomScrollView(
      slivers: [
        _DashboardHeader(controller: controller),
        SliverToBoxAdapter(child: _buildStatsRow(controller)),
        SliverToBoxAdapter(child: _buildGroupChips(controller)),
        SliverToBoxAdapter(child: _buildSearchField()),
        SliverToBoxAdapter(child: _buildMonthFilter(controller)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          sliver: expenses.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyActivity(),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final e = expenses[i];
                      return Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: _deleteBackground(context),
                        onDismissed: (_) {
                          controller.removeExpense(e.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${e.title}" deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => controller.addExpense(e),
                              ),
                            ),
                          );
                        },
                        child: ExpenseTile(
                          expense: e,
                          resolvePerson: controller.personById,
                          onTap: () =>
                              ExpenseDetailScreen.open(context, e),
                        ),
                      );
                    },
                    childCount: expenses.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _deleteBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.red),
    );
  }

  Widget _buildStatsRow(ExpenseController controller) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.trending_up,
              label: 'Total spent',
              value: formatMoney(controller.totalSpent),
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.pending_actions,
              label: 'Outstanding',
              value: formatMoney(controller.outstanding),
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.receipt_long,
              label: 'Expenses',
              value: '${controller.expenseCount}',
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChips(ExpenseController controller) {
    final items = <Widget>[
      _ChipItem(
        label: '🌐 All',
        selected: controller.activeGroupId == null,
        onTap: () => controller.setActiveGroup(null),
      ),
      for (final g in controller.groups)
        _ChipItem(
          label: '${g.emoji} ${g.name}',
          selected: controller.activeGroupId == g.id,
          color: g.color,
          onTap: () => controller.setActiveGroup(g.id),
        ),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: items,
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search expenses…',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMonthFilter(ExpenseController controller) {
    final months = controller.monthlyTrend;
    if (months.length < 2) return const SizedBox(height: 4);
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _ChipItem(
            label: 'All time',
            selected: widget.month == 'all',
            onTap: () => widget.onMonthChanged('all'),
          ),
          for (final m in months)
            _ChipItem(
              label: m.label,
              selected: widget.month == m.key,
              onTap: () => widget.onMonthChanged(m.key),
            ),
        ],
      ),
    );
  }
}

class _ChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _ChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(label),
        selectedColor: base,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final ExpenseController controller;
  const _DashboardHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Export CSV',
          icon: const Icon(Icons.ios_share),
          onPressed: () => _export(context),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 60, 20),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split Khata',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              controller.groupName,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        background: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.78),
                theme.colorScheme.tertiary.withValues(alpha: 0.65),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final csv = context.read<ExpenseController>().buildCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${csv.split('\n').length - 1} expenses as CSV to clipboard',
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('CSV export'),
                content: SingleChildScrollView(
                  child: SelectableText(csv),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No expenses here yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add" to split your first expense.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// BALANCES TAB
// ===========================================================================

class _BalancesTab extends StatelessWidget {
  final ExpenseController controller;
  final ValueChanged<String> onMonthSelected;
  const _BalancesTab({
    required this.controller,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final balanced = controller.balancedPeople;
    final settlements = controller.settlements;
    final payments = controller.visiblePayments;
    final categoryTotals = controller.categoryTotals;
    final trend = controller.monthlyTrend;

    return CustomScrollView(
      slivers: [
        _GradientHeader(
          title: 'Balances',
          subtitle: '${controller.groupName} • who owes whom',
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (trend.isNotEmpty) ...[
                _sectionTitle(context, 'MONTHLY TREND'),
                _trendCard(context, trend),
                const SizedBox(height: 16),
              ],
              _sectionTitle(context, 'PERSON BALANCES'),
              ...balanced.map((b) => _balanceTile(context, b)),
              const SizedBox(height: 20),
              _sectionTitle(context, 'SUGGESTED SETTLEMENTS'),
              const SizedBox(height: 4),
              if (settlements.isEmpty)
                _settledBanner(context)
              else
                ...settlements.map(
                  (s) => _settlementTile(context, s, () {
                    showSettleUpSheet(
                      context,
                      fromId: s.from,
                      toId: s.to,
                      amount: s.amount,
                    );
                  }),
                ),
              if (categoryTotals.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle(context, 'SPENDING BY CATEGORY'),
                const SizedBox(height: 4),
                _categorySummary(
                  context,
                  categoryTotals,
                  controller.totalSpent,
                ),
              ],
              if (payments.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle(context, 'PAYMENT HISTORY'),
                const SizedBox(height: 4),
                ...payments.map((p) => _paymentTile(context, p)),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _trendCard(BuildContext context, List<TrendPoint> trend) {
    final theme = Theme.of(context);
    final maxV = trend.map((t) => t.value).reduce((a, b) => a > b ? a : b);
    final shown = trend.take(6).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: shown.map((t) {
                  final h = maxV == 0 ? 0.0 : (t.value / maxV);
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onMonthSelected(t.key),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(t.value),
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            height: 60 * h + 4,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.35 + 0.55 * h,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.label,
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap a bar to view that month',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceTile(BuildContext context, BalancedPerson b) {
    final theme = Theme.of(context);
    final isPositive = b.net > 0.009;
    final isNegative = b.net < -0.009;
    final color = isPositive
        ? Colors.green
        : isNegative
        ? Colors.red.shade400
        : theme.colorScheme.primary;
    final caption = isPositive
        ? 'will receive'
        : isNegative
        ? 'will pay'
        : 'settled up';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: PersonAvatar(person: b.person),
        title: Text(
          b.person.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(caption),
        trailing: Text(
          signedMoney(b.net),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _settlementTile(
    BuildContext context,
    Settlement s,
    VoidCallback onTap,
  ) {
    final from = controller.personById(s.from);
    final to = controller.personById(s.to);
    if (from == null || to == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: PersonAvatar(person: from, radius: 20),
        title: Row(
          children: [
            Flexible(
              child: Text(
                from.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            Flexible(
              child: Text(
                ' ${to.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: const Text('should pay  •  tap to settle'),
        trailing: Text(
          formatMoney(s.amount),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _categorySummary(
    BuildContext context,
    Map<String, double> totals,
    double grandTotal,
  ) {
    final theme = Theme.of(context);
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      categoryByName(entry.key).icon,
                      color: categoryByName(entry.key).color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.key)),
                    SizedBox(
                      width: 90,
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        value: grandTotal == 0 ? 0 : entry.value / grandTotal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatMoney(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(BuildContext context, Payment p) {
    final from = controller.personById(p.from);
    final to = controller.personById(p.to);
    if (from == null || to == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        onTap: () => showSettleUpSheet(context, existing: p),
        leading: PersonAvatar(person: from, radius: 18),
        title: Text(
          '${from.name} → ${to.name}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatDate(p.date)}'
          '${p.note.isNotEmpty ? ' • ${p.note}' : ''}',
        ),
        trailing: Text(
          formatMoney(p.amount),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _settledBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Everyone is settled up. No pending payments!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GradientHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        background: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.78),
                theme.colorScheme.tertiary.withValues(alpha: 0.65),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
