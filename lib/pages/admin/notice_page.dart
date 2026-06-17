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
        centerTitle: true, //  centers the title text
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
            'assets/icon/icon.png', //  ensure this exists
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
                    return NoticeCard(notice: _notices[i]); //  Custom Card
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
