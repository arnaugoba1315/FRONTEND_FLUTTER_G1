import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/routes.dart';
import 'package:flutter_application_1/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/socket_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';
import 'package:flutter_application_1/services/notification_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProxyProvider<SocketService, ChatService>(
          create: (context) => ChatService(context.read<SocketService>()),
          update: (context, socketService, previous) => 
            previous ?? ChatService(socketService),
        ),
        ChangeNotifierProxyProvider<SocketService, NotificationService>(
          create: (context) => NotificationService(context.read<SocketService>()),
          update: (context, socketService, previous) => 
            previous ?? NotificationService(socketService),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    // Initialize services
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.initialize();
    
    // If user is logged in, initialize socket
    if (authService.isLoggedIn && authService.currentUser != null) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.connect(authService.currentUser);
      
      // Load notifications
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.loadNotifications(authService.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EA Grup 1',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          elevation: 0,
        ),
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.deepPurple,
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
      home: LoginScreen(),
    );
  }
}