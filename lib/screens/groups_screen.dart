import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/group.dart';
import '../models/group_presets.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups & Trips'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join Group',
            onPressed: () => _showJoinGroupDialog(context, controller),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupDialog(context, controller),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.25],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            _allGroupsTile(context, controller),
            const SizedBox(height: 8),
            for (final g in controller.groups) _groupTile(context, controller, g),
          ],
        ),
      ),
    );
  }

  Widget _allGroupsTile(BuildContext context, ExpenseController controller) {
    final theme = Theme.of(context);
    final isAll = controller.activeGroupId == null;
    return _GroupCard(
        color: theme.colorScheme.primary,
        emoji: '🌐',
        name: 'All groups',
        subtitle:
            '${controller.people.length} people • ${formatMoney(controller.expenses.fold<double>(0, (s, e) => s + e.totalAmount))}',
        selected: isAll,
        onTap: () => controller.setActiveGroup(null),
        actions: const [],
      );
  }

  Widget _groupTile(
    BuildContext context,
    ExpenseController controller,
    Group group,
  ) {
    final expenses = controller.expenses
        .where((e) => e.groupId == group.id)
        .toList();
    final sum = expenses.fold<double>(0, (s, e) => s + e.totalAmount);
    final selected = controller.activeGroupId == group.id;

    return _GroupCard(
      color: group.color,
      emoji: group.emoji,
      name: group.name,
      subtitle:
          '${group.memberIds.length} members • ${formatMoney(sum)}',
      selected: selected,
      onTap: () => controller.setActiveGroup(group.id),
      actions: group.id == kGeneralGroupId
          ? const []
          : [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _showGroupDialog(context, controller, existing: group),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, controller, group),
              ),
            ],
    );
  }

  Future<void> _showGroupDialog(
    BuildContext context,
    ExpenseController controller, {
    Group? existing,
  }) async {
    final allPeople = controller.people;
    final nameController = TextEditingController(text: existing?.name ?? '');
    String emoji = existing?.emoji ?? kGroupEmojis.first;
    int colorValue = existing?.colorValue ??
        kGroupColors[controller.groups.length % kGroupColors.length];
    final members = <String>{
      ...?existing?.memberIds,
      if (existing == null) ...allPeople.map((p) => p.id),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New group' : 'Edit group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    'Group ID (Share with friends to connect): ${existing.id}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.primary),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Icon', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kGroupEmojis.map((e) {
                    final selected = e == emoji;
                    return GestureDetector(
                      onTap: () => setLocal(() => emoji = e),
                      child: CircleAvatar(
                        backgroundColor: selected
                            ? Color(colorValue).withValues(alpha: 0.25)
                            : Colors.grey.shade200,
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Colour', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kGroupColors.map((c) {
                    final selected = c == colorValue;
                    return GestureDetector(
                      onTap: () => setLocal(() => colorValue = c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(c),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Members', style: Theme.of(ctx).textTheme.labelLarge),
                    const Spacer(),
                    Text(
                      '${members.length}/${allPeople.length}',
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (allPeople.isEmpty)
                  Text(
                    'No people yet. Add them in the People tab.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Column(
                      children: allPeople.map((p) {
                        final checked = members.contains(p.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          value: checked,
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              members.add(p.id);
                            } else {
                              members.remove(p.id);
                            }
                          }),
                          title: Row(
                            children: [
                              PersonAvatar(person: p, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p.name)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (existing == null) {
                  controller.addGroup(name,
                      emoji: emoji,
                      colorValue: colorValue,
                      memberIds: members.toList());
                } else {
                  controller.updateGroup(existing.copyWith(
                    name: name,
                    emoji: emoji,
                    colorValue: colorValue,
                    memberIds: members.toList(),
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseController controller,
    Group group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text(
          'All expenses and payments in this group will be removed. '
          'This cannot be undone.',
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
    if (confirmed == true) {
      await controller.removeGroup(group.id);
    }
  }

  Future<void> _showJoinGroupDialog(
    BuildContext context,
    ExpenseController controller,
  ) async {
    final idController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Connected Group'),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(
            labelText: 'Enter Group ID or Code',
            hintText: 'e.g., group_id_here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final id = idController.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              await controller.load();
              final found = controller.groupById(id);
              if (found != null) {
                controller.setActiveGroup(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Joined group "${found.name}" successfully!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group ID not found in cloud database.')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
    idController.dispose();
  }
}

class _GroupCard extends StatelessWidget {
  final Color color;
  final String emoji;
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final List<Widget> actions;

  const _GroupCard({
    required this.color,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? color
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'viewing',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 22),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
