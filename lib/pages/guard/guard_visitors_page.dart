import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import  'package:intl/intl.dart';
//import 'package:image/image.dart' as img;



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

  /*Future<File> compressImage(File file) async {
    final decoded = img.decodeImage(await file.readAsBytes())!;
    final compressed = img.encodeJpg(decoded, quality: 50);
    final newFile = File(file.path)..writeAsBytesSync(compressed);
    return newFile;
  }*/

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
        .maybeSingle();                 // Return null instead of error

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

    // ✅ Obtain the anon key from existing client headers
    //const String anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5OTkxODMsImV4cCI6MjA3NDU3NTE4M30.ytdrVGhBx6cpfEb98LsQlntatssuF-IP578bYH45A24"; // ✅ Put your anon key here
    const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODk5OTE4MywiZXhwIjoyMDc0NTc1MTgzfQ.HuKzrHNiaxSnp8nEVVE21y1tUWzmL_cEeJ6xWjxCxik";

    final url =
        'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'; // auto correct region

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serviceKey', // ✅ REQUIRED
          //'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}', // Important
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
       // final compressedPhoto = await compressImage(_photo!);
        //await _supabase.storage.from('visitors').upload(fileName, compressedPhoto);
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
    //final isWide = MediaQuery.of(context).size.width > 600;

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
                          /*Text("Visitor Entry Form",
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              )),
                          const SizedBox(height: 16),*/
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

                            // ✅ Updated trailing section with date & time (no overflow)
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min, // prevents overflow ✅

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

                                // ✅ Date
                              Text(
                                  DateFormat('dd MMM yy').format(
                                    DateTime.parse(visitor['created_at']).toLocal(),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),

                                // ✅ Time
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

/*Future<String?> _getResidentToken(String block, String flat) async {
    final supabase = Supabase.instance.client;

    final response = await supabase.rpc('get_resident_token', params: {
      'p_block': block.trim(),
      'p_flat': flat.trim(),
    }).maybeSingle();

    print("Resident lookup result: $response");

    if (response == null || response['fcm_token'] == null) {
      print("! No resident FCM token found for $block-$flat");
      return null;
    }
    return response['fcm_token'] as String?;
  }*/

/*Future<String?> _getResidentToken(String block, String flat) async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('users')
        .select('fcm_token')
        .ilike('block', block.trim())   // Case-insensitive match
        .ilike('flat', flat.trim())     // Case-insensitive match
        .maybeSingle();                 // Return null instead of error

    print("Resident lookup result: $response");

    if (response == null || response['fcm_token'] == null) {
      print("! No resident FCM token found for $block-$flat");
      return null;
    }

    return response['fcm_token'] as String?;
  }*/


/* Future<void> sendNotification({
    required String title,
    required String body,
    required String token,
    //required String block,
   // required String flat,
  }) async {
    final supabase = Supabase.instance.client;

    // ✅ Obtain the anon key from existing client headers
    //const String anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5OTkxODMsImV4cCI6MjA3NDU3NTE4M30.ytdrVGhBx6cpfEb98LsQlntatssuF-IP578bYH45A24"; // ✅ Put your anon key here
    const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6emd4ZWJzcmtpemlyeWdtcW1nIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODk5OTE4MywiZXhwIjoyMDc0NTc1MTgzfQ.HuKzrHNiaxSnp8nEVVE21y1tUWzmL_cEeJ6xWjxCxik";

    final url =
        'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'; // auto correct region

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serviceKey', // ✅ REQUIRED
          //'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}', // Important
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
  }*/

/*final residentToken = await _getResidentToken(block, flat);

      if (residentToken != null && residentToken.isNotEmpty) {
        await sendNotification(
          title: 'New Visitor Request',
          body: '${visitor['visitor_name']} waiting at ${visitor['block']}-${visitor['flat']}',
          token: residentToken,
        );
      } else {

        debugPrint("⚠️ No resident FCM token found for $block-$flat");
      }*/

/*await sendNotification(
        title: 'New Visitor Request',
        body: '${visitor['visitor_name']} waiting at ${visitor['block']}-${visitor['flat']}',
        //block: block,
        //flat: flat,
        token: residentFcmToken, // <-- THIS IS IMPORTANT
      );*/
// Find the resident for this block & flat
// 🔔 Send notification
/* await _sendFcm(
        title: 'New Visitor Request',
        body: '${visitor['visitor_name']} waiting at ${visitor['block']}-${visitor['flat']}',//ody: '$visitorName waiting at $block-$flat',
        block: block,
        flat: flat,
      );*/
//inal visitor = inserted.first;
/*wait _sendFcm(
        title: 'New Visitor Request',
        body: '${visitor['visitor_name']} waiting at ${visitor['block']}-${visitor['flat']}',
      );*/


/* ture<void> _sendFcm({required String title, required String body}) async {
    try {
      final url = Uri.parse(
          'https://xzzgxebsrkizirygmqmg.supabase.co/functions/v1/send-fcm'); // replace with your function URL
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: '{"title": "$title", "body": "$body"}',
      );
    } catch (e) {
      debugPrint('❌ FCM send error: $e');
    }
  }*/
/*return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: visitor['photo_url'] != null
                                ? CircleAvatar(backgroundImage: NetworkImage(visitor['photo_url']))
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(visitor['visitor_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Phone: ${visitor['phone'] ?? ''}"),
                                Text("Block: ${visitor['block']} | Flat: ${visitor['flat']}"),
                                Text("Purpose: ${visitor['purpose']}"),
                              ],
                            ),
                            trailing: Text(
                              visitor['status'] ?? 'Pending',

                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );*/

/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

 /* Future<void> _sendFcm({
    required String title,
    required String body,
    required String block,
    required String flat,
  }) async {
    try {
      await _supabase.functions.invoke('send-fcm', body: {
        'title': title,
        'body': body,
        'block': block,
        'flat': flat,
      });
    } catch (e) {
      debugPrint('❌ FCM Error: $e');
    }
  }*/

  Future<void> _uploadVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    String? photoUrl;

    try {
      // Upload Photo to Supabase Storage
      if (_photo != null) {
        final fileName = 'visitor_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('visitors').upload(fileName, _photo!);
        photoUrl = _supabase.storage.from('visitors').getPublicUrl(fileName);
      }

      // Insert Visitor Record and return inserted row
       await _supabase.from('visitors').insert({
        'visitor_name': visitorName,
        'phone': phone,
        'block': block,
        'flat': flat,
        'purpose': purpose,
        'photo_url': photoUrl,
        'status': 'Pending',
      }).select().single();

      // Send Notification to Resident
     /* await _sendFcm(
        title: 'New Visitor Request',
        body: '$visitorName waiting at $block-$flat',
        block: block,
        flat: flat,
      );*/

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor entry request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _formKey.currentState!.reset();
      setState(() => _photo = null);
    } catch (e) {
      debugPrint('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visitor Entry Form"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Wrap(
                        runSpacing: 12,
                        spacing: 12,
                        children: [
                          _buildField("Visitor Name", (v) => visitorName = v ?? ''),
                          _buildField("Phone Number", (v) => phone = v ?? ''),
                          _buildField("Block", (v) => block = v ?? ''),
                          _buildField("Flat", (v) => flat = v ?? ''),
                          _buildField("Purpose", (v) => purpose = v ?? ''),

                          const SizedBox(height: 16),
                          _photo == null
                              ? ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Capture Photo"),
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
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                                : const Text("Submit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                Text("Visitors List", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase.from('visitors').stream(primaryKey: ['id']).order('created_at'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final visitors = snapshot.data!;
                    if (visitors.isEmpty) return const Text("No visitors yet.");

                    return ListView.builder(
                      itemCount: visitors.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final v = visitors[index];
                        final color = v['status'] == 'Accepted'
                            ? Colors.green
                            : v['status'] == 'Rejected'
                            ? Colors.red
                            : Colors.orange;

                        return Card(
                          child: ListTile(
                            leading: v['photo_url'] != null
                                ? CircleAvatar(backgroundImage: NetworkImage(v['photo_url']))
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(v['visitor_name']),
                            subtitle: Text("Block ${v['block']} | Flat ${v['flat']}"),
                            trailing: Text(v['status'], style: TextStyle(color: color)),
                          ),
                        );
                      },
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Function(String?) onSaved) {
    return SizedBox(
      width: 320,
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
}*/



/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (picked != null) {
      setState(() => _photo = File(picked.path));
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

      await _supabase.from('visitors').insert({
        'visitor_name': visitorName,
        'phone': phone,
        'block': block,
        'flat': flat,
        'purpose': purpose,
        'photo_url': photoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitor added successfully!')),
        );
      }

      _formKey.currentState!.reset();
      setState(() {
        _photo = null;
      });
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
        title: const Text('Guard - Visitors Entry'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Visitor Name'),
                validator: _required,
                onSaved: (v) => visitorName = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number'),
                validator: _required,
                onSaved: (v) => phone = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Block'),
                validator: _required,
                onSaved: (v) => block = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Flat'),
                validator: _required,
                onSaved: (v) => flat = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Purpose'),
                validator: _required,
                onSaved: (v) => purpose = v ?? '',
              ),
              const SizedBox(height: 16),
              _photo == null
                  ? ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture / Browse Photo'),
                onPressed: _pickPhoto,
              )
                  : Image.file(_photo!, height: 150, fit: BoxFit.cover),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _uploadVisitor,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Visitor'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) => (v == null || v.isEmpty) ? 'Required' : null;
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class GuardVisitorsPage extends StatefulWidget {
  const GuardVisitorsPage({super.key});

  @override
  State<GuardVisitorsPage> createState() => _GuardVisitorsPageState();
}

class _GuardVisitorsPageState extends State<GuardVisitorsPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  final _visitorName = TextEditingController();
  final _block = TextEditingController();
  final _flat = TextEditingController();
  final _purpose = TextEditingController();

  List<Map<String, dynamic>> _visitors = [];
  RealtimeChannel? _sub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
    _subscribeToRealtime();
  }

  Future<void> _loadVisitors() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('visitor')
        .select()
        .eq('created_by', user.id)
        .order('created_at', ascending: false);

    setState(() => _visitors = List<Map<String, dynamic>>.from(data));
  }

  void _subscribeToRealtime() {
    _sub = supabase.channel('visitors-realtime')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'visitor',
      callback: (payload) {
        debugPrint('🔔 Realtime change: ${payload.eventType}');
        _loadVisitors(); // refresh on insert/update
      },
    )
        .subscribe();
  }


  Future<void> _addVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      final data = {
        'visitor_name': _visitorName.text.trim(),
        'block': _block.text.trim(),
        'flat': _flat.text.trim(),
        'purpose': _purpose.text.trim(),
        'created_by': userId,
      };

      await supabase.from('visitor').insert(data);

      _visitorName.clear();
      _block.clear();
      _flat.clear();
      _purpose.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visitor added Successfully ✅')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _loading = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( backgroundColor: Colors.blueAccent.withOpacity(0.1),centerTitle: true,title: const Text('Visitors')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _visitorName,
                decoration: const InputDecoration(labelText: 'Visitor Name'),
                validator: (v) =>
                v!.isEmpty ? 'Please enter visitor name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _block,
                decoration: const InputDecoration(labelText: 'Block'),
                validator: (v) => v!.isEmpty ? 'Enter block' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _flat,
                decoration: const InputDecoration(labelText: 'Flat'),
                validator: (v) => v!.isEmpty ? 'Enter flat' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
                validator: (v) => v!.isEmpty ? 'Enter purpose' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _addVisitor,
                child: Text(_loading ? 'Saving...' : 'Add Visitor'),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Visitor Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._visitors.map((v) => Card(
            child: ListTile(
              title: Text(v['visitor_name']),
              subtitle: Text(
                  'Block: ${v['block']} | Flat: ${v['flat']}\nPurpose: ${v['purpose']}'),
              trailing: Text(
                v['status'].toString().toUpperCase(),
                style: TextStyle(
                  color: v['status'] == 'accepted'
                      ? Colors.green
                      : v['status'] == 'rejected'
                      ? Colors.red
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )),
        ]),
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuardVisitorsPage extends StatefulWidget {
  const GuardVisitorsPage({super.key});

  @override
  State<GuardVisitorsPage> createState() => _GuardVisitorsPageState();
}

class _GuardVisitorsPageState extends State<GuardVisitorsPage> {
  final _formKey = GlobalKey<FormState>();
  final _visitorName = TextEditingController();
  final _block = TextEditingController();
  final _flat = TextEditingController();
  final _purpose = TextEditingController();
  bool _loading = false;

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myVisitors = [];

  @override
  void initState() {
    super.initState();
    _loadMyVisitors();
  }

  Future<void> _loadMyVisitors() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final res = await supabase
        .from('visitor')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    setState(() {
      _myVisitors = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _addVisitor() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'visitor_name': _visitorName.text.trim(),
        'block': _block.text.trim(),
        'flat': _flat.text.trim(),
        'purpose': _purpose.text.trim(),
        'created_by': userId,
      };

      await supabase.from('visitor').insert(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor entry added successfully ✅')),
      );

      _visitorName.clear();
      _block.clear();
      _flat.clear();
      _purpose.clear();

      await _loadMyVisitors();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 Visitor Log'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Visitor Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _visitorName,
                      decoration: const InputDecoration(
                        labelText: 'Visitor Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please enter visitor name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _block,
                      decoration: const InputDecoration(
                        labelText: 'Block',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please Enter Block' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _flat,
                      decoration: const InputDecoration(
                        labelText: 'Flat Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please enter flat number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _purpose,
                      decoration: const InputDecoration(
                        labelText: 'Purpose of Visit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please enter purpose' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: Text(_loading ? 'Saving...' : 'Save Entry'),
                      onPressed: _loading ? null : _addVisitor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('My Visitor Entries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_myVisitors.isEmpty)
                const Text('No visitors logged yet.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myVisitors.length,
                  itemBuilder: (context, i) {
                    final v = _myVisitors[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(v['visitor_name'] ?? ''),
                        subtitle: Text(
                            'Block: ${v['block']} | Flat: ${v['flat']}\nPurpose: ${v['purpose']}'),
                        trailing: Text(v['created_at']
                            .toString()
                            .substring(0, 16)
                            .replaceAll('T', ' ')),
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
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class GuardVisitorPage extends StatefulWidget {
  const GuardVisitorPage({super.key});

  @override
  State<GuardVisitorPage> createState() => _GuardVisitorPageState();
}

class _GuardVisitorPageState extends State<GuardVisitorPage> {
  final _name = TextEditingController();
  final _block = TextEditingController();
  final _flat = TextEditingController();
  final _purpose = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final guardId = auth.currentUser?.authId;
    final messenger = ScaffoldMessenger.of(context);

    if (_name.text.isEmpty || _block.text.isEmpty || _flat.text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill name, block, and flat')),
      );
      return;
    }

    setState(() => _sending = true);

    // 🔍 Find resident by block + flat
    final resident = await DBService.findResidentByBlockFlat(
      _block.text.trim(),
      _flat.text.trim(),
    );

    if (resident == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Resident not found')),
      );
      setState(() => _sending = false);
      return;
    }

    // ✅ Create visitor record
    await DBService.createVisitor({
      'name': _name.text.trim(),
      'block': _block.text.trim(),
      'flat': _flat.text.trim(),
      'purpose': _purpose.text.trim(),
      'status': 'pending',
      'resident_auth_id': resident['id'],
      'guard_auth_id': guardId,
      'created_at': DateTime.now().toIso8601String(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Visitor request sent')),
    );

    _name.clear();
    _block.clear();
    _flat.clear();
    _purpose.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guard Visitor Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _block,
                decoration: const InputDecoration(
                  labelText: 'Block',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _flat,
                decoration: const InputDecoration(
                  labelText: 'Flat Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _purpose,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blueAccent.shade100,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class GuardVisitorsPage extends StatefulWidget {
  const GuardVisitorsPage({super.key});
  @override
  State<GuardVisitorsPage> createState() => _GuardVisitorsPageState();
}

class _GuardVisitorsPageState extends State<GuardVisitorsPage> {
  final _name = TextEditingController();
  final _block = TextEditingController();
  final _flat = TextEditingController();
  final _purpose = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _block.dispose();
    _flat.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_name.text.trim().isEmpty || _block.text.trim().isEmpty || _flat.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please fill name, block and flat')));
      return;
    }

    setState(() => _sending = true);

    try {
      // 1️⃣ Get guard auth ID
      final guardAuthId =
          Provider.of<AuthService>(context, listen: false).currentUser?.authId;

      // 2️⃣ Create visitor request
      await DBService.createVisitor({
        'name': _name.text.trim(),
        'block': _block.text.trim(),
        'flat': _flat.text.trim(),
        'purpose': _purpose.text.trim(),
        'photo_url': null,
        'guard_auth_id': guardAuthId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Visitor request sent successfully')),
      );

      // Clear fields
      _name.clear();
      _block.clear();
      _flat.clear();
      _purpose.clear();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardAuthId =
        Provider.of<AuthService>(context, listen: false).currentUser?.authId;

    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Management')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Visitor Form
            TextField(controller: _name, decoration: const InputDecoration(labelText:'Visitor Name')),
            TextField(controller: _block, decoration: const InputDecoration(labelText:'Block')),
            TextField(controller: _flat, decoration: const InputDecoration(labelText:'Flat')),
            TextField(controller: _purpose, decoration: const InputDecoration(labelText:'Purpose')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send'),
            ),
            const SizedBox(height: 24),
            const Text('Your Visitors', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Real-time visitor list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: DBService.guardVisitorStream(guardAuthId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final visitors = snapshot.data!;
                  if (visitors.isEmpty) return const Center(child: Text('No visitors yet.'));

                  return ListView.builder(
                    itemCount: visitors.length,
                    itemBuilder: (context, index) {
                      final visitor = visitors[index];
                      final status = visitor['status'] ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(visitor['name'] ?? 'Unknown'),
                          subtitle: Text('Flat: ${visitor['flat'] ?? ''} • Purpose: ${visitor['purpose'] ?? ''}'),
                          trailing: Text(
                            status.toString().toUpperCase(),
                            style: TextStyle(
                              color: status == 'accepted'
                                  ? Colors.green
                                  : status == 'denied'
                                  ? Colors.red
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/
/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class GuardVisitorsPage extends StatefulWidget {
  const GuardVisitorsPage({super.key});
  @override
  State<GuardVisitorsPage> createState() => _GuardVisitorsPageState();
}

class _GuardVisitorsPageState extends State<GuardVisitorsPage> {
  final _name = TextEditingController();
  final _block = TextEditingController();
  final _flat = TextEditingController();
  final _purpose = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _block.dispose();
    _flat.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final auth = Provider.of<AuthService>(context, listen:false);
    final guardId = auth.currentUser?.authId;
    final messenger = ScaffoldMessenger.of(context);

    if (_name.text.isEmpty || _block.text.isEmpty || _flat.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please fill name, block, and flat')));
      return;
    }

    setState(()=>_sending=true);

    final resident = await DBService.findResidentByBlockFlat(_block.text.trim(), _flat.text.trim());
    print('Searching for block=${_block.text.trim()}, flat=${_flat.text.trim()}');

    if (resident == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Resident not found')));

      setState(()=>_sending=false);
      return;
    }

    await DBService.createVisitor({
      'name': _name.text.trim(),
      'block': _block.text.trim(),
      'flat': _flat.text.trim(),
      'purpose': _purpose.text.trim(),
      'status': 'pending',
      'resident_id': resident['id'],
      'guard_id': guardId,
      'created_at': DateTime.now().toIso8601String(),
    });

    messenger.showSnackBar(const SnackBar(content: Text('Visitor request sent')));
    _name.clear(); _block.clear(); _flat.clear(); _purpose.clear();
    setState(()=>_sending=false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen:false);
    final guardId = auth.currentUser?.authId;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Guard Visitors & Messages')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Visitor Form
            TextField(controller: _name, decoration: const InputDecoration(labelText:'Visitor Name')),
            TextField(controller: _block, decoration: const InputDecoration(labelText:'Block')),
            TextField(controller: _flat, decoration: const InputDecoration(labelText:'Flat')),
            TextField(controller: _purpose, decoration: const InputDecoration(labelText:'Purpose')),
            const SizedBox(height:12),
            ElevatedButton(
                onPressed: _sending?null:_send,
                child: _sending?const CircularProgressIndicator(color: Colors.white):const Text('Send')
            ),
            const SizedBox(height:24),
            // Real-time Notifications
            Expanded(
              child: guardId==null?const Center(child:Text('User not found')):StreamBuilder<List<Map<String,dynamic>>>(
                stream: DBService.guardNotificationsStream(guardId),
                builder:(context,snap){
                  if(!snap.hasData) return const Center(child:CircularProgressIndicator());
                  final msgs = snap.data!;
                  if(msgs.isEmpty) return const Center(child:Text('No messages yet'));
                  return ListView.builder(
                    itemCount: msgs.length,
                    itemBuilder:(c,i){
                      final m = msgs[i];
                      final visitorName = m['visitor_name'] ?? 'Unknown';
                      final status = m['status'] ?? '';
                      final createdAt = m['created_at'] != null
                          ? DateTime.parse(m['created_at']).toLocal()
                          : DateTime.now();
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical:4),
                        child: ListTile(
                          leading: const Icon(Icons.message, color: Colors.blue),
                          title: Text('Visitor $visitorName'),
                          subtitle: Text('Status: $status\nTime: ${createdAt.hour}:${createdAt.minute}'),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}*/
