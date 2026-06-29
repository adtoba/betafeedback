import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../widgets/feedback_card.dart';

/// Full feedback feed for a project (newest first).
class FeedbackListScreen extends StatelessWidget {
  const FeedbackListScreen({super.key, required this.projectId});

  final String projectId;

  static const previewLimit = 5;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final project = appState.projectById(projectId);
        if (project == null) {
          return const Scaffold(
            body: Center(child: Text('Project not found')),
          );
        }

        final currentUser = appState.currentUser;
        final isCreator = currentUser.id == project.creatorId;
        final isDeveloper = project.developerIds.contains(currentUser.id);
        final canReply = isDeveloper || isCreator;

        final messages = project.feedback
            .where((m) => m.type == FeedbackType.testerMessage)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          appBar: AppBar(title: const Text('Feedback')),
          body: messages.isEmpty
              ? const _EmptyFeedback()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final author = appState.userById(message.authorId);
                    final linkedBug = appState.structuredBugForFeedback(
                      project.id,
                      message.id,
                    );
                    return FeedbackCard(
                      message: message,
                      author: author,
                      structuredBug: linkedBug,
                      canReply: canReply,
                      projectId: project.id,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No feedback yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
