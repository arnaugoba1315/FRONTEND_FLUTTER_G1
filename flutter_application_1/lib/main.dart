import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/routes.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/socket_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Servicio de autenticación
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Servicio de Socket.IO - depende del servicio de autenticación
        ChangeNotifierProvider(create: (_) => SocketService()),
        // Servicio de chat - depende de Socket.IO
        ChangeNotifierProxyProvider<SocketService, ChatService>(
          create: (context) => ChatService(context.read<SocketService>()),
          update: (context, socketService, previous) => 
            previous ?? ChatService(socketService),
        ),
      ],
      child: const MyApp(),
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
    // Inicializar servicios
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.initialize();
    
    // Si el usuario está autenticado, conectar Socket.IO
    if (authService.isLoggedIn && authService.currentUser != null) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.connect(authService.currentUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}