import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/constants.dart';

void main() {
  group('AppConstants', () {
    test('app name and tagline are set', () {
      expect(AppConstants.appName, 'UpGrade');
      expect(AppConstants.appTagline, 'AI-Powered Study Assistant');
    });

    test('routes are non-empty and start with slash', () {
      final routes = [
        AppConstants.routeLogin,
        AppConstants.routeRegister,
        AppConstants.routeForgotPassword,
        AppConstants.routeGoogleClassroomSync,
        AppConstants.routeHome,
        AppConstants.routeTaskExecution,
        AppConstants.routeWarnings,
        AppConstants.routeProgress,
        AppConstants.routeBurnout,
        AppConstants.routeGroupStudy,
        AppConstants.routeAIChatbot,
        AppConstants.routePastTasks,
        AppConstants.routeMissedTasks,
      ];
      for (final route in routes) {
        expect(route.startsWith('/'), isTrue, reason: '$route should start with /');
        expect(route.length, greaterThan(1));
      }
    });

    test('login and register routes are distinct', () {
      expect(AppConstants.routeLogin, isNot(AppConstants.routeRegister));
    });
  });
}
