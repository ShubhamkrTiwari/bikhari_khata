import 'package:flutter/material.dart';

import '../models/person.dart';

/// Circular avatar showing a person's initials tinted with their color.
class PersonAvatar extends StatelessWidget {
  final Person person;
  final double radius;

  const PersonAvatar({super.key, required this.person, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: person.color.withValues(alpha: 0.18),
      foregroundColor: person.color,
      child: Text(
        person.initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
