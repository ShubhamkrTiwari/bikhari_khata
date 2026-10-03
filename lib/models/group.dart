import 'dart:ui';

/// Id of the always-present default group. Expenses with no explicit group
/// (including legacy saved data) belong here.
const String kGeneralGroupId = 'general';

/// A group / trip that expenses and payments belong to.
class Group {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final List<String> memberIds;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.memberIds = const [],
  });

  Color get color => Color(colorValue);

  Group copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    List<String>? memberIds,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        memberIds: memberIds ?? this.memberIds,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'colorValue': colorValue,
    'memberIds': memberIds,
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: (json['emoji'] as String?) ?? '👥',
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF00897B,
    memberIds: (json['memberIds'] as List?)?.cast<String>() ?? const [],
  );
}
