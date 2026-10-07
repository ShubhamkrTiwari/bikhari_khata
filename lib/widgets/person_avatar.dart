import 'package:flutter/material.dart';

import '../models/person.dart';

/// Circular avatar showing a person's initials on a gradient disc.
class PersonAvatar extends StatelessWidget {
  final Person person;
  final double radius;

  const PersonAvatar({super.key, required this.person, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            person.color,
            Color.lerp(person.color, Colors.black, 0.28)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: person.color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          person.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.72,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
