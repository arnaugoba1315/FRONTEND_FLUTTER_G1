import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/auth/login_screen.dart';
import 'package:flutter_application_1/screens/auth/register_screen.dart';
import 'package:flutter_application_1/screens/user/user_home.dart';
import 'package:flutter_application_1/screens/user/user_profile.dart';
import 'package:flutter_application_1/screens/admin/backoffice_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String userHome = '/user-home';
  static const String userProfile = '/user-profile';
  static const String admin = '/admin';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => RegisterScreen());
      case userHome:
        return MaterialPageRoute(builder: (_) => UserHomeScreen());
      case userProfile:
        return MaterialPageRoute(builder: (_) => UserProfileScreen());
      case admin:
        return MaterialPageRoute(builder: (_) => BackofficeScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}