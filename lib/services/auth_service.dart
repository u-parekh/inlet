/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../models/app_user.dart';
import 'db_service.dart';

class AuthService extends ChangeNotifier {
  final client = Supa.client;
  AppUser? currentUser;
  bool isLoading = true;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    final session = client.auth.currentSession;
    if (session != null) {
      await loadProfile();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? block,
    String? flat,
    required String role,
  }) async {
    try {
      final res = await client.auth.signUp(email: email, password: password);
      final user = res.user;
      if (user == null) return 'Sign up failed';

      final authId = user.id;
      // Create profile in DB
      await DBService.createUser({
        'auth_id': authId,
        'full_name': fullName,
        'email': email,
        'password':password,
        'phone': phone,
        'block': block,
        'flat': flat,
        'role': role,
      });

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /*Future<String?> login(String email, String password) async {
    try {
      final res = await client.auth.signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) return 'Login failed';
      await loadProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }*/
  // Login
  Future<String?> login(String email, String password) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) return 'Login failed. Try again.';
      return null;
    } on AuthException catch (e) {
      // 🧩 Detect “email not confirmed” type error
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'Please confirm your email before logging in.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
  // Resend confirmation email
  /*Future<void> resendConfirmation(String email) async {
    await client.auth.resend(
      type: ResendType.signup,
      email: email,
    );
  }*/

  Future<void> loadProfile() async {
    final supaUser = client.auth.currentUser;
    if (supaUser == null) {
      currentUser = null;
      notifyListeners();
      return;
    }
    final m = await DBService.getUserByAuthId(supaUser.id);
    if (m != null) currentUser = AppUser.fromMap(m);
    notifyListeners();
  }

  Future<void> logout() async {
    await client.auth.signOut();
    currentUser = null;
    notifyListeners();
  }
}*/

// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String authId; //  auth user id
  final String fullName;
  final String email;
  final String password;
  final String? phone;
  final String? block;
  final String? flat;
  final String role;

  AppUser({
    required this.authId,
    required this.fullName,
    required this.email,
    required this.password,
    this.phone,
    this.block,
    this.flat,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      authId: data['id'] ?? '',
      fullName: data['full_name'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      phone: data['phone'] ?? '',
      block: data['block'] ?? '',
      flat: data['flat'] ?? '',
      role: data['role'] ?? 'Resident',
    );
  }
}

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  AppUser? currentUser;

  // ✅ Login
  Future<String?> login(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await loadProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  // ✅ Register (creates auth user + DB profile)
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String block,
    required String flat,
    required String role,
  }) async {
    try {
      final res = await _supabase.auth.signUp(email: email, password: password);
      final user = res.user;
      if (user == null) return 'Registration failed.';

      // store profile in DB
      await _supabase.from('users').insert({
        'auth_id': user.id,
        'full_name': fullName,
        'email': email,
        'password': password,
        'phone': phone,
        'block': block,
        'flat': flat,
        'role': role,
      });

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  // ✅ Load profile after login
  Future<void> loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data == null) {
        debugPrint('⚠️ No profile found for ${user.email}');
        currentUser = null;
        return;
      }

      currentUser = AppUser.fromMap(data);
      notifyListeners();
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest Error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
    }
  }


  // ✅ Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
    currentUser = null;
    notifyListeners();
  }
}

