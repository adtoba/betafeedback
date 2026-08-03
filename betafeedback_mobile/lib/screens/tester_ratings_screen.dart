import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';

class TesterRatingsScreen extends StatefulWidget {
  const TesterRatingsScreen({super.key});

  @override
  State<TesterRatingsScreen> createState() => _TesterRatingsScreenState();
}

class _TesterRatingsScreenState extends State<TesterRatingsScreen> {
  Future<List<TesterRating>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).loadMyTesterRatings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AppScope.of(context).currentUser;
    final future = _future;

    return Scaffold(
      appBar: AppBar(title: const Text('Your ratings')),
      body: AppLayout.adaptiveBody(
        context,
        future == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<TesterRating>>(
                future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppEmptyState(
                icon: AppIcons.error,
                title: 'Couldn\'t load ratings',
                message: '${snapshot.error}',
              );
            }

            final ratings = snapshot.data ?? const [];
            if (ratings.isEmpty) {
              return const AppEmptyState(
                icon: AppIcons.star,
                title: 'No ratings yet',
                message:
                    'When creators rate you on a project, their feedback '
                    'shows up here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.only(
                top: AppSpace.sm,
                bottom: AppSpace.xxxl,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter + AppSpace.xs,
                    0,
                    AppSpace.gutter,
                    AppSpace.xl,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.star,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        user.testerRatingLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                GroupedSection(
                  children: [
                    for (final rating in ratings) _RatingTile(rating: rating),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final TesterRating rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final project = rating.projectName.isEmpty
        ? 'Project'
        : rating.projectName;
    final rater = rating.raterName.isEmpty ? 'A creator' : rating.raterName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md + 2,
        AppSpace.md,
        AppSpace.md + 2,
        AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _Stars(score: rating.score),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '$rater · ${formatDate(rating.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(rating.comment, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            AppIcons.star,
            size: 14,
            color: i <= score
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
