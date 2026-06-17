import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import  'package:intl/intl.dart';

class GuardVisitorsPage extends StatefulWidget {
  const GuardVisitorsPage({super.key});

  @override
  State<GuardVisitorsPage> createState() => _GuardVisitorsPageState();
}

class _GuardVisitorsPageState extends State<GuardVisitorsPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  String visitorName = '', phone = '', block = '', flat = '', purpose = '';
  bool _loading = false;
  File? _photo;

  
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _photo = File(picked.path));
  }
  Future<String?> _getResidentToken(String block, String flat) async {
    final supabase = Supabase.instance.client;
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final resident = await _supabase
        .from('users')
        .select('block, flat')
        .eq('auth_id', user.id)
        .single();

    final block = resident['block'].toString().trim();
    final flat = resident['flat'].toString().trim();
    final response = await supabase
        .from('users')
        .select('fcm_token')
        .ilike('block', '%${block}%')
        .ilike('flat', '%${flat}%')
        .maybeSingle();                

    print("Resident lookup result: $response");

    if (response == null || response['fcm_token'] == null) {
      print("! No resident FCM token found for $block-$flat");
      return null;
    }
    return response['fcm_token'] as String?;
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    required String token,
    //required String block,
    // required String flat,
  }) async {
    final supabase = Supabase.instance.client;

    
    const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODk5OTE4MywiZXhwIjoyMDc0NTc1MTgzfQ.HuKzrHNiaxSnp8nEVVE21y1tUWzmL_cEeJ6xWjxCxik";

    final url =
        'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'; 

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serviceKey', 
        
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'token': token,
          //'block': block,
          //'flat': flat,

        }),
      );

      debugPrint("✅ Notification Response: ${response.body}");
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }
  Future<void> _uploadVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    String? photoUrl;
    try {
      if (_photo != null) {
        final fileName = 'visitor_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('visitors').upload(fileName, _photo!);
        photoUrl = _supabase.storage.from('visitors').getPublicUrl(fileName);
      }
       final inserted = await _supabase.from('visitors').insert({
          'visitor_name': visitorName,
          'phone': phone,
          'block': block,
          'flat': flat,
          'purpose': purpose,
          'photo_url': photoUrl,
          'status': 'Pending',
      }).select().single();

      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Visitor entry request sent successfully!'),
                backgroundColor: Colors.green
            ),
          );

      }
      final visitor = inserted;
      _formKey.currentState!.reset();
      setState(() => _photo = null);

      final residentToken = await _getResidentToken(block, flat);

      if (residentToken != null && residentToken.isNotEmpty) {
        await sendNotification(
          title: 'New Visitor Request',
          body: '${visitor['visitor_name']} waiting at ${visitor['block']}-${visitor['flat']}',
          token: residentToken,
        );
      } else {

        debugPrint("⚠️ No resident FCM token found for $block-$flat");
      }


    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest Error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Visitor Entry Form',
          style: TextStyle(
            fontSize: 20,
            // fontWeight: FontWeight.bold,
            color: Colors.black, // same as foreground for harmony
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visitor Form
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Wrap(
                            runSpacing: 10,
                            spacing: 10,
                            children: [
                              _buildField('Visitor Name', (v) => visitorName = v ?? ''),
                              _buildField('Phone Number', (v) => phone = v ?? ''),
                              _buildField('Block no./ House no', (v) => block = v ?? ''),
                              _buildField('Flat / Society Name', (v) => flat = v ?? ''),
                              _buildField('Purpose', (v) => purpose = v ?? ''),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _photo == null
                              ? ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Capture Photo'),
                            onPressed: _pickPhoto,
                          )
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_photo!, height: 150, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _uploadVisitor,
                            icon: const Icon(Icons.send),
                            label: _loading
                                ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent.withOpacity(0.70),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Visitors List (Below Form)
                Text("Visitors List",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 10),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('visitors')
                      .stream(primaryKey: ['id'])
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final visitors = snapshot.data!;
                    if (visitors.isEmpty) {
                      return const Center(child: Text("No visitors yet."));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visitors.length,
                      itemBuilder: (context, index) {
                        final visitor = visitors[index];
                        final statusColor = visitor['status'] == 'Accepted'
                            ? Colors.green
                            : visitor['status'] == 'Rejected'
                            ? Colors.red
                            : Colors.orange;

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: visitor['photo_url'] != null
                                ? CircleAvatar(backgroundImage: NetworkImage(visitor['photo_url']))
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(
                              visitor['visitor_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Phone: ${visitor['phone'] ?? ''}"),
                                Text("Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
                                Text("Purpose: ${visitor['purpose']}"),
                              ],
                            ),

                            //  Updated trailing section with date & time (no overflow)
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min, // prevents overflow 

                              children: [
                                Text(
                                  visitor['status'] ?? 'Pending',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                //  Date
                              Text(
                                  DateFormat('dd MMM yy').format(
                                    DateTime.parse(visitor['created_at']).toLocal(),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),

                                // Time
                                Text(
                                  DateFormat('hh:mm a').format(
                                    DateTime.parse(visitor['created_at']).toLocal(),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        );
                        },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Function(String?) onSaved) {
    return SizedBox(
      width: 300,
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        onSaved: onSaved,
      ),
    );
  }
}
