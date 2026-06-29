enum SubscriptionPlan { free, pro }

enum SubscriptionStatus { active, trialing, pastDue }

SubscriptionPlan subscriptionPlanFromString(String? value) => switch (value) {
      'pro' => SubscriptionPlan.pro,
      _ => SubscriptionPlan.free,
    };

SubscriptionStatus subscriptionStatusFromString(String? value) =>
    switch (value) {
      'trialing' => SubscriptionStatus.trialing,
      'past_due' => SubscriptionStatus.pastDue,
      _ => SubscriptionStatus.active,
    };

class Subscription {
  const Subscription({
    required this.plan,
    required this.status,
    this.renewsOn,
    this.projectLimit,
    this.projectsCreated = 0,
  });

  final SubscriptionPlan plan;
  final SubscriptionStatus status;

  /// Next billing date. Null for the free plan.
  final DateTime? renewsOn;

  /// Maximum number of projects the user can create. Null means unlimited.
  final int? projectLimit;

  /// How many projects the user currently owns (counts against [projectLimit]).
  final int projectsCreated;

  bool get isPaid => plan != SubscriptionPlan.free;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        plan: subscriptionPlanFromString(json['plan'] as String?),
        status: subscriptionStatusFromString(json['status'] as String?),
        renewsOn: json['renews_on'] == null
            ? null
            : DateTime.parse(json['renews_on'] as String),
        projectLimit: (json['project_limit'] as num?)?.toInt(),
        projectsCreated: (json['projects_created'] as num?)?.toInt() ?? 0,
      );
}

extension SubscriptionPlanInfo on SubscriptionPlan {
  String get label => switch (this) {
        SubscriptionPlan.free => 'Free',
        SubscriptionPlan.pro => 'Pro',
      };

  /// Whole-dollar monthly price.
  int get monthlyPrice => switch (this) {
        SubscriptionPlan.free => 0,
        SubscriptionPlan.pro => 12,
      };

  String get priceLabel =>
      monthlyPrice == 0 ? 'Free' : '\$$monthlyPrice/mo';

  String get tagline => switch (this) {
        SubscriptionPlan.free => 'For trying things out',
        SubscriptionPlan.pro => 'For builders running serious betas',
      };

  List<String> get features => switch (this) {
        SubscriptionPlan.free => const [
            '1 active project',
            'Unlimited testers & developers',
            'AI bug structuring',
          ],
        SubscriptionPlan.pro => const [
            'Unlimited projects',
            'Custom project logo',
            'Export bugs & feedback (CSV)',
            'Email notifications',
          ],
      };
}

extension SubscriptionStatusInfo on SubscriptionStatus {
  String get label => switch (this) {
        SubscriptionStatus.active => 'Active',
        SubscriptionStatus.trialing => 'Trial',
        SubscriptionStatus.pastDue => 'Past due',
      };
}
