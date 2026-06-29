import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/user.dart';

class TeamMemberTile extends StatelessWidget {
  const TeamMemberTile({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColorForUser(user, theme.colorScheme),
          child: Text(
            initialsFor(user.name),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        title: Text(user.name),
        subtitle: Text(user.email),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            user.roleLabel,
            style: theme.textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}
