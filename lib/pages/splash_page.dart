import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_page.dart';
import 'resident/resident_home.dart';
import 'guard/guard_home.dart';
import 'admin/admin_panel.dart';



class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;

  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // ✅ Logo Bounce Animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoController.forward();

    // ✨ Welcome Text Fade + Slide Animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _textController.forward();

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 11));

    final user = supabase.auth.currentUser;

    // ✅ If not logged in → Login Page
    if (user == null) {
      _goTo(const LoginPage());
      return;
    }

    // ✅ Fetch role
    final profile = await supabase
        .from('users')
        .select('role')
        .eq('auth_id', user.id)
        .maybeSingle();

    final role = profile?['role'] ?? 'Resident';

    switch (role) {
      case 'Resident':
        _goTo(const ResidentHome());
        break;
      case 'Guard':
        _goTo(const GuardHome());
        break;
      case 'Admin':
        _goTo(const AdminHomePage());
        break;
      default:
        _goTo(const LoginPage());
        break;
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Animated Logo
            ScaleTransition(
              scale: _logoScale,
              child: Image.asset(
                'assets/icon/icon.png',
                width: 120, // ✅ Medium size logo
                height: 120,
              ),
            ),

            const SizedBox(height: 20),

            // ✨ Animated Welcome Text
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  "Welcome to Inlet",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

