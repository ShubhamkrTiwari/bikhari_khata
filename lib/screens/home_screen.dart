import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/expense_controller.dart';
import '../models/categories.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../models/settlement.dart';
import '../utils/format.dart';
import '../widgets/expense_tile.dart';
import '../widgets/floating_nav_bar.dart';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: controller.isLoaded
            ? IndexedStack(index: _index, children: pages)
            : const _LoadingView(),
      ),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
        items: const [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          NavItem(
            icon: Icons.balance_outlined,
            activeIcon: Icons.balance_rounded,
            label: 'Balances',
          ),
          NavItem(
            icon: Icons.map_outlined,
            activeIcon: Icons.map_rounded,
            label: 'Groups',
          ),
          NavItem(
            icon: Icons.group_outlined,
            activeIcon: Icons.group_rounded,
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  formatDate(DateTime.now()),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.groupName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        emoji: '🌐',
        label: 'All',
        selected: controller.activeGroupId == null,
        onTap: () => controller.setActiveGroup(null),
      ),
      for (final g in controller.groups)
        _ChipItem(
          emoji: g.emoji,
          label: g.name,
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
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border({Color? color, double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search expenses…',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 21,
            color: scheme.onSurfaceVariant,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: border(),
          enabledBorder: border(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          focusedBorder: border(color: scheme.primary, width: 1.5),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
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
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _ChipItem({
    required this.label,
    this.emoji,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [base, Color.lerp(base, scheme.tertiary, 0.5)!],
                  )
                : null,
            color: selected ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: base.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(
                  emoji!,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 6),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
                child: Text(label),
              ),
            ],
          ),
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
    final user = context.watch<AuthController>().user;
    final greetingName = user == null
        ? ''
        : user.name.trim().split(RegExp(r'\s+')).first;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      title: Text(
        user == null ? 'Split Khata' : 'Namaste, $greetingName 👋',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Export CSV',
          icon: const Icon(Icons.ios_share),
          onPressed: () => _export(context),
        ),
        const _UserMenu(),
      ],
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

/// Signed-in user's avatar with account info + logout.
class _UserMenu extends StatelessWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) return const SizedBox(width: 8);
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) async {
        if (value != 'logout') return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: Text(
              'Your data stays safe on this device and in the cloud. '
              'Sign back in anytime with ${user.email}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await context.read<AuthController>().signOut();
        }
      },
      itemBuilder: (menuContext) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(menuContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          foregroundColor: Colors.white,
          child: Text(
            user.initials,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.tertiary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 46,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 250,
            child: Text(
              'Tap "Add" to split your first expense with the group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final isPositive = b.net > 0.009;
    final isNegative = b.net < -0.009;
    final color = isPositive
        ? Colors.green
        : isNegative
        ? Colors.redAccent
        : scheme.primary;
    final caption = isPositive
        ? 'will receive'
        : isNegative
        ? 'will pay'
        : 'settled up';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: PersonAvatar(person: b.person),
        title: Text(
          b.person.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              caption,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            signedMoney(b.net),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final from = controller.personById(s.from);
    final to = controller.personById(s.to);
    if (from == null || to == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 38,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: PersonAvatar(person: from, radius: 17),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: PersonAvatar(person: to, radius: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            from.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: scheme.primary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            to.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'tap to settle up',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, scheme.tertiary, 0.7)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  formatMoney(s.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
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
    final scheme = Theme.of(context).colorScheme;
    final from = controller.personById(p.from);
    final to = controller.personById(p.to);
    if (from == null || to == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: () => showSettleUpSheet(context, existing: p),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 21,
          ),
        ),
        title: Text(
          '${from.name} → ${to.name}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${formatDate(p.date)}'
          '${p.note.isNotEmpty ? ' • ${p.note}' : ''}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Text(
            formatMoney(p.amount),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            child: Icon(Icons.celebration_rounded, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All settled up 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'No pending payments between members',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
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
