import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class GuardMessagesPage extends StatelessWidget {
  const GuardMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final guardId = auth.currentUser?.authId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<Map<String,dynamic>>>(
        stream: Supabase.instance.client
            .from('notifications:guard_id=eq.$guardId')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((e) => List<Map<String,dynamic>>.from(e as List)),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snap.data!;
          if (messages.isEmpty) return const Center(child: Text('No messages yet'));

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(m['visitor_name'] ?? 'Unknown Visitor'),
                  subtitle: Text('Status: ${m['status'] ?? ''}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

