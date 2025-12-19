// File: lib/services/fcm_service.dart (create new)
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FcmService {
  static final _supabase = Supabase.instance.client;

  /// Call this after user login or on app startup.
  static Future<void> saveFcmToken() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _supabase.from('users').update({
        'fcm_token': token,
      }).eq('auth_id', user.id);
      debugPrint('✅ Saved fcm_token for ${user.id}');
    } catch (e) {
      debugPrint('❌ Error saving fcm token: $e');
    }
  }
}
