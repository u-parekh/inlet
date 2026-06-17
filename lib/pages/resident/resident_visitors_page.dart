import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
//import '../../services/auth_service.dart';

class ResidentVisitorsPage extends StatefulWidget {
  const ResidentVisitorsPage({super.key});

  @override
  State<ResidentVisitorsPage> createState() => _ResidentVisitorsPageState();
}

class _ResidentVisitorsPageState extends State<ResidentVisitorsPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
    _listenForRealtime();
  }

  // Fetch visitors linked to current resident
  Future<void> _fetchVisitors() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final resident = await _supabase
          .from('users')
          .select('block, flat')
          .eq('auth_id', user.id)
          .single();

      final block = resident['block'].toString().trim();
      final flat = resident['flat'].toString().trim();
      final data = await _supabase
          .from('visitors')
          .select('*')
          .ilike('block', '%${block}%')
          .ilike('flat', '%${flat}%')
          .order('created_at', ascending: false);
      //.ilike('block', resident['block'])
          //.ilike('flat', resident['flat'])

      /*.from('visitors')
          .select()
          .ilike('block', resident['block'])
          .ilike('flat', resident['flat'])
          .order('created_at', ascending: false);*/

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
      setState(() => _loading = false);
    }
  }

  // Realtime listener for visitors table
  void _listenForRealtime() {
    _supabase
        .channel('public:visitors')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitors',
      callback: (payload) {
        _fetchVisitors();
      },
    )
        .subscribe();
  }
  
  // Update visitor status (UUID safe)
  Future<void> _updateStatus(String id, String status) async {
    try {
      await _supabase.from('visitors').update({'status': status}).filter('id::text', 'eq', id);

      final visitor = await _supabase.from('visitors').select().eq('id', id).single();

      _fetchVisitors();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Visitor Entry $status"),
          backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
        ),
      );

      
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("Visitors"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visitors.isEmpty
          ? const Center(
        child: Text(
          "No visitor requests yet.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchVisitors,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _visitors.length,
          itemBuilder: (context, index) {
            final visitor = _visitors[index];
            final status = visitor['status'] ?? 'Pending';
            final statusColor = status == 'Accepted'
                ? Colors.green
                : status == 'Rejected'
                ? Colors.red
                : Colors.orange;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: visitor['photo_url'] != null
                          ? NetworkImage(visitor['photo_url'])
                          : null,
                      child: visitor['photo_url'] == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // ✅ Left Side Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visitor['visitor_name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text("Phone: ${visitor['phone'] ?? ''}"),
                          Text("Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
                          Text("Purpose: ${visitor['purpose']}"),
                          const SizedBox(height: 4),
                          Text(
                            "Status: $status",
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ✅ RIGHT SIDE Column (Date + Action Buttons)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // ✅ Created Date & Time
                        Text(
                          DateFormat('dd MMM yyyy').format(
                              DateTime.parse(visitor['created_at']).toLocal()),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(
                              DateTime.parse(visitor['created_at']).toLocal()),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),

                        if (status == 'Pending')
                          Row(
                            children: [
                              _roundedIconButton(
                                icon: Icons.check,
                                color: Colors.green,
                                onTap: () => _updateStatus(visitor['id'].toString(), 'Accepted'),
                              ),
                              const SizedBox(width: 6),
                              _roundedIconButton(
                                icon: Icons.close,
                                color: Colors.red,
                                onTap: () => _updateStatus(visitor['id'].toString(), 'Rejected'),
                              ),
                            ],
                          )
                        else
                          Icon(
                            status == 'Accepted'
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: statusColor,
                            size: 30,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            },
        ),
      ),
    );
  }

  // ✅ Small rounded button widget
  Widget _roundedIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}


