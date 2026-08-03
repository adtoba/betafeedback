import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/user.dart';
import '../theme/app_tokens.dart';
import 'status_pill.dart';

/// Team member row. Designed to sit inside a `GroupedSection`.
class TeamMemberTile extends StatelessWidget {
  const TeamMemberTile({super.key, required this.user, this.trailing});

  final User user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user.name.isEmpty ? user.email : user.name;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.md - 2,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorForUser(user, scheme),
              shape: BoxShape.circle,
            ),
            child: Text(
              initialsFor(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (user.name.isNotEmpty)
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (trailing != null)
            trailing!
          else
            StatusPill(
              label: user.roleLabel,
              color: _roleColor(user.role, scheme),
            ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole? role, ColorScheme scheme) {
    return switch (role) {
      UserRole.creator => scheme.secondary,
      UserRole.developer => scheme.primary,
      UserRole.tester => scheme.onSurfaceVariant,
      null => scheme.onSurfaceVariant,
    };
  }
}
