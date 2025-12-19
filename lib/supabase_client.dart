import 'package:supabase_flutter/supabase_flutter.dart';

class Supa {
  static const _url = 'https://xzzgxebsrkizirygmqmg.supabase.co';
  static const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5OTkxODMsImV4cCI6MjA3NDU3NTE4M30.ytdrVGhBx6cpfEb98LsQlntatssuF-IP578bYH45A24';

  static Future<void> init() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
      //primaryKey: 'secure_key_123',
      //authCallbackUrlHostname: 'login-callback',
      debug: true,
    );
  }

  static SupabaseClient client = Supabase.instance.client;
}
