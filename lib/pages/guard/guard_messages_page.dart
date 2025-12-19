import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

/*class GuardMessagesPage extends StatefulWidget {
  const GuardMessagesPage({super.key});

  @override
  State<GuardMessagesPage> createState() => _GuardMessagesPageState();
}

class _GuardMessagesPageState extends State<GuardMessagesPage> {
  final List<Map<String, dynamic>> _msgs = [];
  RealtimeChannel? _channel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context, listen: false);
    final guardId = auth.currentUser?.authId;

    if (guardId != null) {
      _subscribe(guardId);
    }
  }

  void _subscribe(String guardId) {
    final supabase = Supabase.instance.client;

    _channel = supabase.channel('public:notifications')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: 'guard_id=eq.$guardId',
        ),
            (payload, {ref}) {
          final newRecord = Map<String, dynamic>.from(payload['new'] ?? {});
          setState(() => _msgs.insert(0, newRecord));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Visitor ${newRecord['status']} for ${newRecord['visitor_name']}'),
            ),
          );
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Notifications')),
      body: _msgs.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : ListView.builder(
        itemCount: _msgs.length,
        itemBuilder: (context, i) {
          final m = _msgs[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(m['visitor_name'] ?? 'Unknown'),
              subtitle: Text('Status: ${m['status'] ?? 'Pending'}'),
            ),
          );
        },
      ),
    );
  }
}*/
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

