import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/expense_controller.dart';
import '../models/person.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final theme = Theme.of(context);
    final nets = {
      for (final b in controller.balancedPeople) b.person.id: b.net,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPersonDialog(context, controller),
        child: const Icon(Icons.person_add_alt_1_rounded),
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
        child: controller.people.isEmpty
            ? Center(
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
                            theme.colorScheme.primary.withValues(alpha: 0.16),
                            theme.colorScheme.tertiary.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        Icons.group_rounded,
                        size: 46,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No people yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap + to add friends, flatmates or family.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: controller.people.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = controller.people[i];
                  return _personTile(context, controller, p, nets[p.id]);
                },
              ),
      ),
    );
  }

  Widget _personTile(
    BuildContext context,
    ExpenseController controller,
    Person person,
    double? net,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hasNet = net != null && net.abs() > 0.009;
    final color = hasNet
        ? (net > 0 ? Colors.green : Colors.redAccent)
        : scheme.primary;
    final caption = hasNet
        ? (net > 0 ? 'gets back' : 'owes')
        : 'settled up';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: PersonAvatar(person: person),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          caption,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNet)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  signedMoney(net),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showPersonDialog(context, controller, existing: person);
                } else if (value == 'delete') {
                  _confirmDelete(context, controller, person);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPersonDialog(
    BuildContext context,
    ExpenseController controller, {
    Person? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add person' : 'Rename person'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final name = nameController.text.trim();
              if (existing == null) {
                controller.addPerson(name);
              } else {
                controller.renamePerson(existing.id, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseController controller,
    Person person,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete person?'),
        content: Text(
          'Removing ${person.name} will also delete their expenses and '
          'splits. This cannot be undone.',
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
      await controller.removePerson(person.id);
    }
  }
}
