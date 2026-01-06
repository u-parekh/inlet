import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/resident/resident_home.dart';
import 'pages/admin/admin_panel.dart';
import 'pages/guard/guard_home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; 
import 'pages/splash_page.dart';


final navigatorKey = GlobalKey<NavigatorState>();
@pragma('vm:entry-point') 
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background message ${message.messageId}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://xzzgxebsrkizirygmqmg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5OTkxODMsImV4cCI6MjA3NDU3NTE4M30.ytdrVGhBx6cpfEb98LsQlntatssuF-IP578bYH45A24',
  );
 

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // handle when user taps notification
    final data = message.data;
  });
 runApp(const InletApp());
}

class InletApp extends StatelessWidget {
  const InletApp({super.key});
  @override Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => AuthService(), child: Consumer<AuthService>(
      builder: (context, auth, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: 'Inlet',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
          home: const SplashPage(),
          routes: {
            '/login': (_) => const LoginPage(),
            '/resident': (_) =>const ResidentHome(),
            '/admin': (_) => const AdminMainPage(),
            '/guard': (_) => const GuardHome(),
          },
        );
      },
    ));
  }

  Widget _buildHome(AuthService auth) {
   // if (auth.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (auth.currentUser == null) return const LoginPage();
    final role = auth.currentUser?.role ?? 'Resident';
    if (role == 'Admin') return const AdminMainPage();
    if (role == 'Guard') return const GuardHome();
    return ResidentHome();
  }
}
