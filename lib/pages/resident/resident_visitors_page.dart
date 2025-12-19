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

      /* await sendNotification(
        title: 'Visitor $status',
        body: 'Resident has $status ${visitor['visitor_name']}',
        block: visitor['block'],
        flat: visitor['flat'],

      );*/

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

// helper
/* Future<void> sendNotification({
    required String title,
    required String body,
    required String block,
    required String flat,
  }) async {
   // final supabase = Supabase.instance.client;
    // ✅ Obtain the anon key from existing client headers
   // const String anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5OTkxODMsImV4cCI6MjA3NDU3NTE4M30.ytdrVGhBx6cpfEb98LsQlntatssuF-IP578bYH45A24"; // ✅ Put your anon key here
    const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODk5OTE4MywiZXhwIjoyMDc0NTc1MTgzfQ.HuKzrHNiaxSnp8nEVVE21y1tUWzmL_cEeJ6xWjxCxik";

    final url =
        'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'; // auto correct region

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serviceKey',
          //'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}', // Important
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'block': block,
          'flat': flat,
        }),
      );

      debugPrint("✅ Notification Response: ${response.body}");
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }*/

/* Future<void> sendVisitorNotification(String visitorId, String action) async {
    final supabase = Supabase.instance.client;

    // Use the client functions.invoke (it sends auth and is simpler)
    final res = await supabase.functions.invoke('send-fcm', body: {
      'visitor_id': visitorId,
      'action': action, // e.g. 'Accepted' or 'Rejected'
    });

    // res is dynamic — you can print for debugging
    debugPrint('📩 Edge function result: $res');
  }*/
// Use this method in your resident page after updating visitor status
// ✅ Send notification via Supabase Edge Function
/*Future<void> _sendFCMNotification(String status) async {
    try {
      final url = Uri.parse(
          'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'); // Edge function endpoint
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': 'Visitor $status',
          'body': 'Your visitor has been $status by the resident.',
        }),
      );
      debugPrint("📩 FCM response: ${response.statusCode}");
    } catch (e) {
      debugPrint('❌ FCM error: $e');
    }
  }*/

/*await _supabase
          .from('visitors')
          .update({'status': status})
          .filter('id::text', 'eq', id); // ✅ UUID fix
        await _sendFcm(

        title: 'Visitor $status',
        body: 'Resident has $status the visitor ${visitor['visitor_name']}',
        block: visitor['block'],
        flat: visitor['flat'],
      );

      _fetchVisitors();
      // after update status
      // After updating visitor record:
      final supabase = Supabase.instance.client;
      await supabase.from('visitors').update({'status': 'Accepted'}).eq('id', id);

// Notify via edge function (no residentAuthId required)
      await sendVisitorNotification(id, 'Accepted');*/

// await _sendFCMNotification(status);


/*return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
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
                          Text(
                              "Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
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
                    if (status == 'Pending')
                      Column(
                        children: [
                          _roundedIconButton(
                            icon: Icons.check,
                            color: Colors.green,
                            onTap: () => _updateStatus(
                                visitor['id'].toString(), 'Accepted'),
                          ),
                          const SizedBox(height: 8),
                          _roundedIconButton(
                            icon: Icons.close,
                            color: Colors.red,
                            onTap: () => _updateStatus(
                                visitor['id'].toString(), 'Rejected'),
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
              ),
            );*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // ✅ Fetch visitors for logged-in resident
  Future<void> _fetchVisitors() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final resident = await _supabase
          .from('users')
          .select('block, flat')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (resident == null) return;

      final data = await _supabase
          .from('visitors')
          .select()
          .eq('block', resident['block'])
          .eq('flat', resident['flat'])
          .order('created_at', ascending: false);

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ✅ Real-time updates when visitors table changes
  void _listenForRealtime() {
    _supabase.channel('public:visitors')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'visitors',
        callback: (payload) {
          debugPrint("🔔 Realtime change detected: ${payload.eventType}");
          _fetchVisitors();
        },
      )
      ..subscribe();
  }

  // ✅ Update visitor status and trigger FCM
  Future<void> _updateStatus(String id, String status) async {
    try {
      await _supabase
          .from('visitors')
          .update({'status': status})
          .eq('id', id);

      await _sendFCMNotification(status);

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

  // ✅ Send notification via Supabase Edge Function
  Future<void> _sendFCMNotification(String status) async {
    try {
      final url = Uri.parse(
          'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'); // Edge function endpoint
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': 'Visitor $status',
          'body': 'Your visitor has been $status by the resident.',
        }),
      );
      debugPrint("📩 FCM response: ${response.statusCode}");
    } catch (e) {
      debugPrint('❌ FCM error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visitors"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        foregroundColor: Colors.black,
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
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage:
                      visitor['photo_url'] != null &&
                          visitor['photo_url'] != ''
                          ? NetworkImage(visitor['photo_url'])
                          : null,
                      child: visitor['photo_url'] == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 12),
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
                          Text(
                              "Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
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
                    if (status == 'Pending')
                      Column(
                        children: [
                          _roundedIconButton(
                            icon: Icons.check,
                            color: Colors.green,
                            onTap: () => _updateStatus(
                                visitor['id'].toString(), 'Accepted'),
                          ),
                          const SizedBox(height: 8),
                          _roundedIconButton(
                            icon: Icons.close,
                            color: Colors.red,
                            onTap: () => _updateStatus(
                                visitor['id'].toString(), 'Rejected'),
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
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ Small rounded icon button
  Widget _roundedIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}*/



/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final data = await _supabase
          .from('visitors')
          .select()
          .eq('block', resident['block'])
          .eq('flat', resident['flat'])
          .order('created_at', ascending: false);

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
      setState(() => _loading = false);
    }
  }

  void _listenForRealtime() {
    _supabase
        .channel('realtime:visitors')
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

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _supabase
          .from('visitors')
          .update({'status': status})
          .filter('id::text', 'eq', id); // ✅ fixed uuid cast

      _fetchVisitors();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Visitor $status"),
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
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("Visitors"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade400,
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
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                          Text(
                              "Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
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
                    if (status == 'Pending')
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _roundActionButton(
                            icon: Icons.check,
                            color: Colors.green,
                            onPressed: () => _updateStatus(
                                visitor['id'].toString(), 'Accepted'),
                          ),
                          const SizedBox(height: 8),
                          _roundActionButton(
                            icon: Icons.close,
                            color: Colors.red,
                            onPressed: () => _updateStatus(
                                visitor['id'].toString(), 'Rejected'),
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
              ),
            );
          },
        ),
      ),
    );
  }

  /// ✅ Small rounded action button for accept/reject
  Widget _roundActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _listenForUpdates();
  }

  /// Fetch visitors assigned to current resident
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

      final data = await _supabase
          .from('visitors')
          .select()
          .eq('block', resident['block'])
          .eq('flat', resident['flat'])
          .order('created_at', ascending: false);

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
      setState(() => _loading = false);
    }
  }

  /// Listen for realtime visitor updates
  void _listenForUpdates() {
    final channel = _supabase.channel('visitors_changes');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitors',
      callback: (payload) => _fetchVisitors(),
    ).subscribe();
  }

  /// Update visitor status (Accept / Reject)
  Future<void> _updateStatus(dynamic id, String status) async {
    try {
      // Cast id to UUID for Supabase
      await _supabase
          .from('visitors')
          .update({'status': status})
          .filter('id::text', 'eq', id.toString()); // ✅ explicit cast

      await _fetchVisitors();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Visitor $status"),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Resident Visitors"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
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
            padding: const EdgeInsets.all(16),
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
                elevation: 4,
                shadowColor: Colors.blueAccent.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Visitor photo
                      visitor['photo_url'] != null
                          ? CircleAvatar(
                        radius: 35,
                        backgroundImage:
                        NetworkImage(visitor['photo_url']),
                      )
                          : const CircleAvatar(
                        radius: 35,
                        child: Icon(Icons.person, size: 30),
                      ),
                      const SizedBox(width: 12),

                      // Visitor Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(visitor['visitor_name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("📞 ${visitor['phone'] ?? ''}"),
                            Text(
                                "🏢 ${visitor['block']} | Flat: ${visitor['flat']}"),
                            Text("🎯 ${visitor['purpose']}"),
                          ],
                        ),
                      ),

                      // Actions or Status
                      status == 'Pending'
                          ? Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          // ✅ Accept button
                          ElevatedButton(
                            onPressed: () => _updateStatus(
                                visitor['id'], 'Accepted'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: const CircleBorder(),
                              minimumSize: const Size(40, 40),
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 5),

                          // ❌ Reject button
                          ElevatedButton(
                            onPressed: () => _updateStatus(
                                visitor['id'], 'Rejected'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: const CircleBorder(),
                              minimumSize: const Size(40, 40),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ],
                      )
                          : Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}*/



/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _listenForUpdates();
  }

  Future<void> _fetchVisitors() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get resident's block and flat
      final resident = await _supabase
          .from('users')
          .select('block, flat')
          .eq('auth_id', user.id)
          .single();

      // Fetch visitors for this resident
      final data = await _supabase
          .from('visitors')
          .select()
          .eq('block', resident['block'])
          .eq('flat', resident['flat'])
          .order('created_at', ascending: false);

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
      setState(() => _loading = false);
    }
  }

  void _listenForUpdates() {
    final channel = _supabase.channel('visitors_changes');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitors',
      callback: (payload) => _fetchVisitors(),
    ).subscribe();
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _supabase.from('visitors').update({'status': status}).eq('id', id);
      _fetchVisitors();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Visitor $status"),
          backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error updating visitor status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visitors"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.15),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /*Text("Visitors List",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 10),*/
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: visitor['photo_url'] != null
                          ? CircleAvatar(
                        backgroundImage:
                        NetworkImage(visitor['photo_url']),
                      )
                          : const CircleAvatar(
                          child: Icon(Icons.person)),
                      title: Text(
                        visitor['visitor_name'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Phone: ${visitor['phone'] ?? ''}"),
                          Text(
                              "Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
                          Text("Purpose: ${visitor['purpose']}"),
                        ],
                      ),
                      trailing: status == 'Pending'
                          ? Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _updateStatus(
                                visitor['id'], 'Accepted'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text("Accept"),
                          ),
                          const SizedBox(height: 5),
                          ElevatedButton(
                            onPressed: () => _updateStatus(
                                visitor['id'], 'Rejected'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text("Deny"),
                          ),
                        ],
                      )
                          : Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/


/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentVisitorsPage extends StatefulWidget {
  const ResidentVisitorsPage({super.key});

  @override
  State<ResidentVisitorsPage> createState() => _ResidentVisitorsPageState();
}

class _ResidentVisitorsPageState extends State<ResidentVisitorsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _visitors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
    _listenForUpdates();
  }

  Future<void> _fetchVisitors() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Fetch resident’s block & flat
      final resident = await _supabase
          .from('users')
          .select('block, flat')
          .eq('auth_id', user.id)
          .single();

      // Fetch visitors for same block & flat
      final data = await _supabase
          .from('visitors')
          .select()
          .eq('block', resident['block'])
          .eq('flat', resident['flat'])
          .order('created_at', ascending: false);

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('❌ Error fetching visitors: $e');
    }
    setState(() => _loading = false);
  }

  void _listenForUpdates() {
    final channel = _supabase.channel('visitors_updates');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitors',
      callback: (payload) {
        _fetchVisitors();
      },
    ).subscribe();
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _supabase.from('visitors').update({'status': status}).eq('id', id);
      _fetchVisitors();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Visitor marked as $status'),
          backgroundColor:
          status == 'accepted' ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resident - Visitors Requests"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _visitors.isEmpty
            ? const Center(
          child: Text(
            "No visitors yet.",
            style:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchVisitors,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _visitors.length,
            itemBuilder: (context, index) {
              final v = _visitors[index];
              final status = v['status'] ?? 'pending';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: v['photo_url'] != null
                        ? NetworkImage(v['photo_url'])
                        : const AssetImage('assets/visitor.png')
                    as ImageProvider,
                  ),
                  title: Text(
                    v['visitor_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Phone: ${v['phone']}"),
                      Text("Purpose: ${v['purpose']}"),
                      Text("Block: ${v['block']} | Flat: ${v['flat']}"),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (status == 'pending') ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text("Accept"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () => _updateStatus(
                                  v['id'], 'accepted'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text("Deny"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _updateStatus(v['id'], 'rejected'),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: status == 'accepted'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'accepted'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentVisitorsPage extends StatefulWidget {
  const ResidentVisitorsPage({super.key});

  @override
  State<ResidentVisitorsPage> createState() => _ResidentVisitorsPageState();
}

class _ResidentVisitorsPageState extends State<ResidentVisitorsPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> visitors = [];

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
    _subscribeToUpdates();
  }

  Future<void> _fetchVisitors() async {
    final data = await _supabase.from('visitors').select().order('created_at', ascending: false);
    setState(() => visitors = data);
  }

  void _subscribeToUpdates() {
    _supabase.channel('visitors_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'visitors',
      callback: (_) => _fetchVisitors(),
    )
        .subscribe();
  }

  Future<void> _updateStatus(String id, String status) async {
    await _supabase.from('visitors').update({'status': status}).eq('id', id);
    _fetchVisitors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitors')),
      body: ListView.builder(
        itemCount: visitors.length,
        itemBuilder: (context, index) {
          final v = visitors[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: v['photo_url'] != null
                  ? Image.network(v['photo_url'], width: 60, height: 60, fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 40),
              title: Text(v['visitor_name']),
              subtitle: Text(
                '${v['purpose']}\nPhone no: ${v['phone']} Block: ${v['block']}  Flat: ${v['flat']}\nStatus: ${v['status']}',
              ),
              isThreeLine: true,
              trailing: v['status'] == 'Pending'
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _updateStatus(v['id'], 'Accepted'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _updateStatus(v['id'], 'Rejected'),
                  ),
                ],
              )
                  : Text(v['status'], style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentVisitorsPage extends StatefulWidget {
  const ResidentVisitorsPage({super.key});

  @override
  State<ResidentVisitorsPage> createState() => _ResidentVisitorsPageState();
}

class _ResidentVisitorsPageState extends State<ResidentVisitorsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _visitors = [];
  RealtimeChannel? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
    _subscribeRealtime();
  }

  Future<void> _loadVisitors() async {
    final res = await supabase
        .from('visitor')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      _visitors = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    _sub = supabase.channel('visitors-resident')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitor',
      callback: (payload) {
        _loadVisitors();
      },
    )
        .subscribe();
  }

  Future<void> _updateStatus(String id, String status) async {
    await supabase.from('visitor').update({'status': status}).eq('id', id);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Visitor $status')));
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
     // return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return const Center(child: Text('No visitors have arrived'));
    }


    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueAccent.withOpacity(0.1), // light gray background
          foregroundColor: Colors.white, // deep blue text/icons
          elevation: 0, // flat look
          centerTitle: true, // ✅ centers the title text
          title: const Text(
            'Visitors',
            style: TextStyle(
              fontSize: 20,
             // fontWeight: FontWeight.bold,
              color: Colors.black, // same as foreground for harmony
              letterSpacing: 0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        ),
          body: ListView.builder(
        itemCount: _visitors.length,
        itemBuilder: (context, i) {
          final v = _visitors[i];
          return Card(
            child: ListTile(
              title: Text(v['visitor_name']),
              subtitle: Text(
                  'Block: ${v['block']} | Flat: ${v['flat']}\nPurpose: ${v['purpose']}'),
              trailing: v['status'] == 'pending'
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _updateStatus(v['id'], 'accepted'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _updateStatus(v['id'], 'rejected'),
                  ),
                ],
              )
                  : Text(
                v['status'].toUpperCase(),
                style: TextStyle(
                  color: v['status'] == 'accepted'
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class ResidentVisitorsPage extends StatelessWidget {
  const ResidentVisitorsPage({super.key});

  Future<void> _respondToVisitor(Map<String, dynamic> visitor, String status) async {
    final client = Supabase.instance.client;

    // 1️⃣ Update visitor status
    await client.from('visitor').update({'status': status}).eq('id', visitor['id']);

    // 2️⃣ Notify guard via RPC
    await client.rpc('send_notification', params: {
      '_visitor_id': visitor['id'],
      '_guard_id': visitor['guard_id'],
      '_visitor_name': visitor['name'],
      '_status': status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final residentId = auth.currentUser?.authId;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white, // light gray background
          foregroundColor: Colors.white, // deep blue text/icons
          elevation: 2, // flat look
          centerTitle: true, // ✅ centers the title text
          title: const Text(
            'Visitors',
            style: TextStyle(
              fontSize: 20,
              // fontWeight: FontWeight.bold,
              color: Colors.black, // same as foreground for harmony
              letterSpacing: 0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DBService.visitorsStreamForResident(residentId ?? ''),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final visitors = snap.data!;
          if (visitors.isEmpty) return const Center(child: Text('No visitors yet'));

          return ListView.builder(
            itemCount: visitors.length,
            itemBuilder: (context, i) {
              final visitor = visitors[i];
              final status = visitor['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(visitor['name'] ?? 'Unknown'),
                  subtitle: Text('Flat: ${visitor['block']}-${visitor['flat']}\nPurpose: ${visitor['purpose']}\nStatus: $status'),
                  trailing: status == 'pending'
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _respondToVisitor(visitor, 'accepted'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _respondToVisitor(visitor, 'denied'),
                      ),
                    ],
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}*/
