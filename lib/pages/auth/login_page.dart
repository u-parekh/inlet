import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'check_email_page.dart';
import 'register_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';

//final supabase = Supabase.instance.client;

Future<void> saveFcmToken() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await supabase.from('users').update({
    'fcm_token': token,
  }).eq('auth_id', user.id);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _email = '', _password = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'inlet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/icon/icon.png', //  ensure this exists
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: size.width < 500 ? double.infinity : 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                 Icon(
                  Icons.lock_outline,
                  color: Colors.blue.shade600,
                  size: 60,
                ),
                const SizedBox(height: 12),
                 Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Sign in to continue",
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined),
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (v) => _email = v,
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (v) => _password = v,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.login),
                    label: Text(
                      _loading ? 'Signing In...' : 'Login',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _loading
                        ? null
                        : () async {
                      setState(() => _loading = true);
                      final err = await auth.login(_email.trim(), _password.trim());
                      setState(() => _loading = false);

                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                        return;
                      }

                      final user = Supabase.instance.client.auth.currentUser;
                      if (user != null && user.emailConfirmedAt == null) {
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => CheckEmailPage(email: _email)),
                        );
                        return;
                      }

                      await auth.loadProfile();
                      if (!context.mounted) return;
                      final role = auth.currentUser?.role ?? 'Resident';
                      if (role == 'Admin') {
                        Navigator.pushReplacementNamed(context, '/admin');
                      } else if (role == 'Guard') {
                        Navigator.pushReplacementNamed(context, '/guard');
                      } else {
                        Navigator.pushReplacementNamed(context, '/resident');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: Text(
                    "Don't have an account? Register here",
                    style: TextStyle(color:Colors.blue.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

