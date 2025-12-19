import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notice_card.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  final supabase = Supabase.instance.client;
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  String _target = 'all';
  bool _loading = false;
  List<Map<String, dynamic>> _notices = [];

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('notice')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      setState(() {
        _notices = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching notices: $e')),
      );
    }
  }

  Future<void> _createNotice() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in')),
      );
      return;
    }

    final title = titleController.text.trim();
    final body = messageController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.from('notice').insert({
        'title': title,
        'body': body,
        'target': _target,
        'created_by': user.id, // just UUID, no FK constraint
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(' Notice created successfully!'),
            backgroundColor:  Colors.green
        ),
      );

      titleController.clear();
      messageController.clear();

      await _fetchNotices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating notice: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // light gray background
        foregroundColor: Colors.white, // deep blue text/icons
        elevation: 0, // flat look
        centerTitle: true, // ✅ centers the title text
        title: const Text(
          'Notice',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black, // same as foreground for harmony
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/icon/icon.png', // 👈 ensure this exists
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Notice Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _target,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'resident', child: Text('Residents')),
                  DropdownMenuItem(value: 'guard', child: Text('Guards')),
                ],
                onChanged: (v) => setState(() => _target = v!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _createNotice,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Notice'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                'My Created Notices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              if (_notices.isEmpty)
                const Text('No notices created yet.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notices.length,
                  itemBuilder: (context, i) {
                    //return MyNoticeCard(notice: _notices[i]);
                    return NoticeCard(notice: _notices[i]); // ✅ Custom Card
                  },
                ),

              /*ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notices.length,
                  itemBuilder: (context, i) {
                    final n = _notices[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(n['title']),
                        subtitle: Text(
                          '${n['body']}\nTarget: ${n['target']}',
                        ),
                      ),
                    );
                  },
                ),*/
            ],
          ),
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  String _target = 'All';
  bool _loading = false;
  List<Map<String, dynamic>> _myNotices = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMyNotices();
  }

  Future<void> _loadMyNotices() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final res = await supabase
        .from('notice')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    setState(() {
      _myNotices = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _createNotice() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final title = titleController.text.trim();
    final message = messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and message')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final newNotice = {
        'title': title,
        'body': message,
        'target': _target,
        'created_by': userId, // ✅ Matches RLS policy
      };

      await supabase.from('notice').insert(newNotice);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice sent successfully!')),
      );

      titleController.clear();
      messageController.clear();

      await _loadMyNotices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Admin Notices'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create New Notice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _target,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Resident', child: Text('Resident')),
                  DropdownMenuItem(value: 'Guard', child: Text('Guard')),
                ],
                onChanged: (v) => setState(() => _target = v!),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_loading ? 'Sending...' : 'Send Notice'),
                onPressed: _loading ? null : _createNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('My Sent Notices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_myNotices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No notices created yet.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myNotices.length,
                  itemBuilder: (context, i) {
                    final n = _myNotices[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(n['title'] ?? ''),
                        subtitle: Text('${n['body'] ?? ''}\nTarget: ${n['target']}'),
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
}
*/
/*import 'package:flutter/material.dart';
import '../../services/db_service.dart';

class NoticePage extends StatefulWidget {
  final String adminId;
  const NoticePage({super.key, required this.adminId});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _target = 'all';
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _createNotice() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter title and body')));
      return;
    }

    setState(() => _loading = true);
    await DBService.createNotice(
      title: _title.text.trim(),
      body: _body.text.trim(),
      target: _target,
      adminId: widget.adminId,
    );
    _title.clear();
    _body.clear();
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice created successfully')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Notices')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _body, decoration: const InputDecoration(labelText: 'Body')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _target,
              decoration: const InputDecoration(labelText: 'Target Audience'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Users')),
                DropdownMenuItem(value: 'resident', child: Text('Residents Only')),
                DropdownMenuItem(value: 'guard', child: Text('Guards Only')),
              ],
              onChanged: (val) => setState(() => _target = val!),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _createNotice,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Notice'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text('Your Created Notices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: DBService.adminNoticesStream(widget.adminId),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final notices = snap.data!;
                  if (notices.isEmpty) return const Center(child: Text('No notices yet'));
                  return ListView.builder(
                    itemCount: notices.length,
                    itemBuilder: (context, i) {
                      final n = notices[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(n['title'] ?? ''),
                          subtitle: Text('${n['body']}\nTarget: ${n['target']}'),
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
