import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:betafeedback_mobile/data/app_state.dart';
import 'package:betafeedback_mobile/main.dart';
import 'package:betafeedback_mobile/services/api_client.dart';

/// Canned backend responses keyed by "METHOD /path".
http.Response _route(http.Request request) {
  final key = '${request.method} ${request.url.path}';

  Map<String, dynamic> ok(Object body) => {'__status': 200, '__body': body};

  final user = {
    'id': 'u1',
    'name': 'Alex Rivera',
    'email': 'alex@beta.app',
    'avatar_hue': 240,
  };

  final projectSummary = {
    'id': 'p1',
    'name': 'ShopFlow Mobile',
    'description': 'Checkout beta',
    'creator_id': 'u1',
    'creator_name': 'Alex Rivera',
    'invite_code': 'shopflow-1',
    'invite_link': 'https://betafeedback.app/join/shopflow-1',
    'app_link': 'https://testflight.apple.com/join/shopflow',
    'created_at': '2026-06-01T00:00:00Z',
    'tester_count': 2,
    'member_count': 3,
    'latest_feedback_at': null,
  };

  late final Map<String, dynamic> result;
  switch (key) {
    case 'POST /v1/auth/email/start':
      result = ok({'expires_in': 600, 'debug_code': '123456'});
    case 'POST /v1/auth/email/verify':
      result = ok({'token': 'test-token', 'user': user});
    case 'GET /v1/me':
      result = ok(user);
    case 'GET /v1/projects':
      result = ok({
        'projects': [projectSummary],
      });
    case 'GET /v1/notifications':
      result = ok({'notifications': []});
    case 'GET /v1/projects/p1':
      result = ok({
        ...projectSummary,
        'members': [
          {
            'user_id': 'u1',
            'name': 'Alex Rivera',
            'email': 'alex@beta.app',
            'role': 'creator',
            'avatar_hue': 240,
          },
        ],
      });
    case 'GET /v1/projects/p1/feedback':
      result = ok({
        'feedback': [
          {
            'id': 'f1',
            'project_id': 'p1',
            'author_id': 'u1',
            'author_name': 'Alex Rivera',
            'title': 'Cart total resets',
            'body': 'Cart resets after promo code',
            'device': 'iPhone 15 Pro · iOS 17.4',
            'app_version': 'v1.4.0',
            'screenshots': [],
            'created_at': '2026-06-02T10:00:00Z',
          },
        ],
      });
    case 'GET /v1/projects/p1/bugs':
      result = ok({'bugs': []});
    case 'GET /v1/projects/p1/test-items':
      result = ok({'test_items': []});
    case 'GET /v1/projects/p1/activity':
      result = ok({'activity': []});
    default:
      return http.Response(jsonEncode({'error': 'not found: $key'}), 404);
  }

  return http.Response(
    jsonEncode(result['__body']),
    result['__status'] as int,
    headers: {'content-type': 'application/json'},
  );
}

AppState _appStateWithMock() =>
    AppState(api: ApiClient(client: MockClient((r) async => _route(r))));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('email OTP sign-in leads to the projects list',
      (WidgetTester tester) async {
    await tester.pumpWidget(BetaFeedbackApp(appState: _appStateWithMock()));
    await tester.pumpAndSettle();

    // No stored session -> sign-in screen.
    expect(find.text('BetaFeedback'), findsOneWidget);

    // Reveal email field, enter an address, continue.
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'name@work-email.com'),
      'alex@beta.app',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Verification screen, then enter any 6-digit code (backend accepts it).
    expect(find.text('Check your email'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    // Landed on the projects list with the real project from the API.
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('ShopFlow Mobile'), findsOneWidget);
  });

  testWidgets('opening a project loads its feedback from the API',
      (WidgetTester tester) async {
    await tester.pumpWidget(BetaFeedbackApp(appState: _appStateWithMock()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'name@work-email.com'),
      'alex@beta.app',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ShopFlow Mobile'));
    await tester.pumpAndSettle();

    expect(find.text('Bug summary'), findsOneWidget);
    expect(find.text('Cart total resets'), findsOneWidget);
    expect(find.textContaining('iPhone 15 Pro'), findsOneWidget);
  });

  test('ApiClient surfaces backend error messages', () async {
    final client = ApiClient(
      client: MockClient(
        (r) async => http.Response(jsonEncode({'error': 'nope'}), 403),
      ),
    );
    expect(
      () => client.get('/v1/anything'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
  });
}
