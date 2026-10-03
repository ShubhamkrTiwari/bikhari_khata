import 'package:flutter/material.dart';

/// A fixed set of expense categories with icon + color metadata.
class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const kExpenseCategories = <ExpenseCategory>[
  ExpenseCategory(
    name: 'Food',
    icon: Icons.restaurant,
    color: Color(0xFFFF7043),
  ),
  ExpenseCategory(
    name: 'Travel',
    icon: Icons.directions_bus,
    color: Color(0xFF42A5F5),
  ),
  ExpenseCategory(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Color(0xFFEC407A),
  ),
  ExpenseCategory(
    name: 'Bills',
    icon: Icons.receipt_long,
    color: Color(0xFF5C6BC0),
  ),
  ExpenseCategory(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Color(0xFFAB47BC),
  ),
  ExpenseCategory(
    name: 'Groceries',
    icon: Icons.local_grocery_store,
    color: Color(0xFF66BB6A),
  ),
  ExpenseCategory(
    name: 'Other',
    icon: Icons.category,
    color: Color(0xFF8D6E63),
  ),
];

ExpenseCategory categoryByName(String name) =>
    kExpenseCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => kExpenseCategories.last,
    );
