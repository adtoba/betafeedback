import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
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
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        final currentUser = appState.currentUser;
        final isCreator = currentUser.id == project.creatorId;
        final isDeveloper = project.developerIds.contains(currentUser.id);
        final canReply = isDeveloper || isCreator;

        final messages =
            project.feedback
                .where((m) => m.type == FeedbackType.testerMessage)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          appBar: AppBar(title: Text('Feedback · ${messages.length}')),
          body: messages.isEmpty
              ? const _EmptyFeedback()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.md,
                    AppSpace.gutter,
                    AppSpace.xxl,
                  ),
                  itemCount: messages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpace.sm + 2),
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
    return const AppEmptyState(
      icon: AppIcons.feedback,
      title: 'No reports yet',
      message: 'Reports from your testers will collect here.',
    );
  }
}
