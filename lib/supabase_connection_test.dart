import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectionTest extends StatefulWidget {
  const SupabaseConnectionTest({super.key});

  @override
  State<SupabaseConnectionTest> createState() => _SupabaseConnectionTestState();
}

class _SupabaseConnectionTestState extends State<SupabaseConnectionTest> {
  String status = 'Checking connection...';

  @override
  void initState() {
    super.initState();
    checkSupabaseConnection();
  }

  Future<void> checkSupabaseConnection() async {
    try {
      // simple SELECT query to test connectivity
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .limit(1);

      if (response.isNotEmpty) {
        setState(() => status = '✅ Connected to Supabase and fetched data!');
      } else {
        setState(() => status = '⚠️ Connected, but no data in notifications table.');
      }
    } catch (e) {
      setState(() => status = '❌ Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Connection Test')),
      body: Center(
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
