import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ResidentChatPage extends StatefulWidget {
  final Map<String, dynamic> resident;
  const ResidentChatPage({required this.resident, super.key});

  @override
  State<ResidentChatPage> createState() => _ResidentChatPageState();
}

class _ResidentChatPageState extends State<ResidentChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController textController = TextEditingController();
  File? selectedImage;
  String selectedScope = "all";
  String? specBlock;
  String? specFlat;
  bool showSent = false;
  final picker = ImagePicker();
  bool isSending = false; // ✅ NEW

  String _norm(dynamic v) => v?.toString().toLowerCase().trim() ?? '';

  Future<void> pickImage(bool fromCamera) async {
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 65,
    );
    if (picked != null) setState(() => selectedImage = File(picked.path));
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return null;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    await supabase.storage.from('message').upload(fileName, selectedImage!);
    return supabase.storage.from('message').getPublicUrl(fileName);
  }

  Future<void> sendMessage() async {
    if (isSending) return; // avoid double tap
    final text = textController.text.trim();
    if (text.isEmpty && selectedImage == null) return;

    setState(() => isSending = true); // ✅ NEW

    final imageUrl = await uploadImage();
    final senderId = widget.resident['id'];

    await supabase.from('messages').insert({
      'sender_id': senderId,
      'sender_block': widget.resident['block'],
      'sender_flat': widget.resident['flat'],
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock?.trim() : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat?.trim() : null,
      'type': "message", // ✅ Removed complaint option
      'text': text.isEmpty ? null : text,
      'image_url': imageUrl,
      'seen_at': null,
    });

    setState(() {
      isSending = false;
      textController.clear();
      selectedImage = null;
      specBlock = null;
      specFlat = null;
      selectedScope = 'all';
    });
  }

  Future<void> markAsSeen(String messageId) async {
    try {
      await supabase
          .from('messages')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', messageId);
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> messagesStream() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final userBlock = _norm(widget.resident['block']);
    final userFlat = _norm(widget.resident['flat']);
    final userId = widget.resident['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ✅ CENTERED Inbox / Sent
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => showSent = false),
                  child: Text(
                    "Inbox",
                    style: TextStyle(
                      fontWeight: !showSent ? FontWeight.bold : FontWeight.w500,
                      color: !showSent ? Colors.blue : Colors.black87,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => setState(() => showSent = true),
                  child: Text(
                    "Sent",
                    style: TextStyle(
                      fontWeight: showSent ? FontWeight.bold : FontWeight.w500,
                      color: showSent ? Colors.blue : Colors.black87,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // messages list below
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: messagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                final filtered = all.where((m) {
                  if (showSent) return (m['sender_id'] ?? '') == userId;

                  final scope = (m['receiver_scope'] ?? '').toString();
                  if (scope == 'all') return true;

                  if (scope == 'residents' && widget.resident['role'] == 'Resident') return true;

                  if (scope == 'admin' && widget.resident['role'] == 'Admin') return true;   // ✅ NEW

                  if (scope == 'guards' && widget.resident['role'] == 'Guard') return true;   // ✅ NEW

                  /*if (scope == 'all' || scope == 'residents') return true;
                  if (scope == 'admins' && widget.resident['role'] == 'Admin') return true;   // ✅ NEW
                  if (scope == 'guards' && widget.resident['role'] == 'Guard') return true;*/
                  if (scope == 'specific') {
                    return _norm(m['receiver_block']) == userBlock &&
                        _norm(m['receiver_flat']) == userFlat;
                  }
                  return false;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No messages yet"));
                }

                final display = filtered.reversed.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: display.length,
                  itemBuilder: (context, index) {
                    final m = display[index];
                    final isMe = (m['sender_id'] ?? '') == userId;

                    if (!showSent && !isMe && m['seen_at'] == null) {
                      markAsSeen(m['id'].toString());
                    }

                    final created = DateTime.tryParse(m['created_at'] ?? "")?.toLocal();
                    final dateLabel = created != null ? DateFormat('dd MMM, hh:mm a').format(created) : '';

                    final info = showSent
                        ? "To ${m['receiver_block'] ?? 'All'} / ${m['receiver_flat'] ?? ''} • $dateLabel"
                        : "From ${m['sender_block']} / ${m['sender_flat']} • $dateLabel";

                    // seen ticks
                    final ticks = showSent
                        ? Icon(Icons.done_all, size: 16, color: m['seen_at'] != null ? Colors.lightBlueAccent : Colors.white70)
                        : const SizedBox.shrink();

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['image_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(m['image_url'], width: 220),
                              ),
                            if ((m['text'] ?? '').toString().isNotEmpty)
                              Text(m['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(info, style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54)),
                                const SizedBox(width: 6),
                                ticks,
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ Compact Input Section + Loading Send Button
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              color: Colors.grey.withOpacity(0.1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // SCOPE DROPDOWN
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: selectedScope,
                        items: const [
                          DropdownMenuItem(value: "all", child: Text("All")),
                          DropdownMenuItem(value: "residents", child: Text("Residents")),
                          DropdownMenuItem(value: "admin", child: Text("Admin  ")),     // ✅ NEW
                          DropdownMenuItem(value: "guards", child: Text("Guards")),
                          DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                        ],
                        onChanged: (v) => setState(() => selectedScope = v ?? 'all'),
                      ),
                    ],
                  ),

                  // ✅ SHOW BLOCK + FLAT INPUTS ONLY WHEN specific SELECTED
                  if (selectedScope == "specific")
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Block",
                                isDense: true,
                                border: UnderlineInputBorder(),
                              ),
                              onChanged: (v) => specBlock = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Flat",
                                isDense: true,
                                border: UnderlineInputBorder(),
                              ),
                              onChanged: (v) => specFlat = v,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ✅ TEXT + IMAGE + SEND BUTTON
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo),
                        onPressed: () => pickImage(false),
                      ),
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: const InputDecoration(
                            hintText: "Type message...",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ✅ SEND BUTTON WITH LOADING
                      ElevatedButton(
                        onPressed: isSending ? null : sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(48, 48),
                          shape: const CircleBorder(),
                        ),
                        child: isSending
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )

        ],
      ),
    );
  }
}

/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentChatPage extends StatefulWidget {
  final Map<String, dynamic> resident;
  const ResidentChatPage({required this.resident, super.key});

  @override
  State<ResidentChatPage> createState() => _ResidentChatPageState();
}

class _ResidentChatPageState extends State<ResidentChatPage> {

  final supabase = Supabase.instance.client;
  final TextEditingController textController = TextEditingController();
  File? selectedImage;
  String selectedScope = "all";
  String messageType = "message";
  String? specBlock;
  String? specFlat;
  bool showSent = false;
  final picker = ImagePicker();

  Future<void> pickImage(bool fromCamera) async {
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 65,
    );
    if (picked != null) setState(() => selectedImage = File(picked.path));
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return null;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    await supabase.storage.from('message').upload(fileName, selectedImage!);
    return supabase.storage.from('message').getPublicUrl(fileName);
  }

  Future<void> sendMessage() async {
    if (textController.text.trim().isEmpty) return;

    final imageUrl = await uploadImage();
    final senderId = widget.resident['id'];

    await supabase.from('messages').insert({
      'sender_id': senderId,
      'sender_block': widget.resident['block'],
      'sender_flat': widget.resident['flat'],
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock?.trim() : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat?.trim() : null,
      'type': messageType,
      'text': textController.text.trim(),
      'image_url': imageUrl,
      'seen_at': null,
    });

    setState(() {
      textController.clear();
      selectedImage = null;
      specBlock = null;
      specFlat = null;
    });
  }

  Future<void> markAsSeen(String messageId) async {
    await supabase
        .from('messages')
        .update({'seen_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  Stream<List<Map<String, dynamic>>> inboxStream() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final userBlock = widget.resident['block']?.toString().trim();
    final userFlat = widget.resident['flat']?.toString().trim();
    final userId = widget.resident['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages / Complaints"),
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // SWITCH SECTION MOVED DOWN
          Container(
           // width: double.infinity,
            //padding: const EdgeInsets.all(8),
            color: Colors.grey.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() => showSent = false),
                  child: Text(
                    "Inbox",
                    style: TextStyle(
                      fontWeight: !showSent ? FontWeight.bold : FontWeight.normal,
                      color: !showSent ? Colors.blue : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () => setState(() => showSent = true),
                  child: Text(
                    "Sent",
                    style: TextStyle(
                      fontWeight: showSent ? FontWeight.bold : FontWeight.normal,
                      color: showSent ? Colors.blue : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: inboxStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;

                final filtered = showSent
                    ? messages.where((m) => m['sender_id'] == userId).toList()
                    : messages.where((m) =>
                m['receiver_scope'] == 'all' ||
                    m['receiver_scope'] == 'residents' ||
                    (m['receiver_scope'] == 'specific' &&
                        m['receiver_block']?.toString().trim() == userBlock &&
                        m['receiver_flat']?.toString().trim() == userFlat))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No messages yet", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: filtered.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, i) {
                    final m = filtered[i];

                    if (!showSent && m['seen_at'] == null) markAsSeen(m['id']); // mark inbox messages seen

                    final isMe = m['sender_id'] == userId;
                    final created = DateTime.tryParse(m['created_at'] ?? "");
                    final time = created != null ? "${created.hour}:${created.minute.toString().padLeft(2, '0')}" : "";

                    String info = showSent
                        ? "To ${m['receiver_block'] ?? 'All'} / ${m['receiver_flat'] ?? ''} • $time"
                        : "From ${m['receiver_block']} / ${m['receiver_flat']} • $time";

                    final ticks = showSent
                        ? (m['seen_at'] != null ? "✔✔" : "✔")
                        : "";

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['image_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(m['image_url'], width: 200),
                              ),
                            Text(
                              m['text'] ?? "",
                              style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(info, style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54)),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  Text(ticks, style: TextStyle(fontSize: 12, color: Colors.white)),
                                ]
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// INPUT SECTION
          SafeArea(
            child: Container(
              color: Colors.grey.withOpacity(0.1),
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  DropdownButtonFormField(
                    initialValue: selectedScope,
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Send to All")),
                      DropdownMenuItem(value: "residents", child: Text("All Residents")),
                      DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                    ],
                    onChanged: (v) => setState(() => selectedScope = v!),
                  ),
                  if (selectedScope == "specific")
                    Row(
                      children: [
                        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Block"), onChanged: (v) => specBlock = v)),
                        const SizedBox(width: 6),
                        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Flat"), onChanged: (v) => specFlat = v)),
                      ],
                    ),

                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => pickImage(true)),
                      IconButton(icon: const Icon(Icons.photo), onPressed: () => pickImage(false)),
                      Expanded(
                        child: TextField(controller: textController, decoration: const InputDecoration(hintText: "Type message...")),
                      ),
                      IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: sendMessage),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}*/

/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ResidentChatPage extends StatefulWidget {
  final Map<String, dynamic> resident;
  const ResidentChatPage({required this.resident, super.key});

  @override
  State<ResidentChatPage> createState() => _ResidentChatPageState();
}

class _ResidentChatPageState extends State<ResidentChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController textController = TextEditingController();
  File? selectedImage;
  String selectedScope = "all";
  String messageType = "message";
  String? specBlock;
  String? specFlat;
  bool showSent = false;
  final picker = ImagePicker();

  // Helpers to normalize blocks/flats for comparisons
  String _norm(dynamic v) => v?.toString().toLowerCase().trim() ?? '';

  Future<void> pickImage(bool fromCamera) async {
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 65,
    );
    if (picked != null) setState(() => selectedImage = File(picked.path));
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return null;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    // Upload to storage bucket "message"
    // (If your upload method requires bytes, adjust accordingly)
    await supabase.storage.from('message').upload(fileName, selectedImage!);
    final url = supabase.storage.from('message').getPublicUrl(fileName);
    return url;
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty && selectedImage == null) return;

    final imageUrl = await uploadImage();
    final senderId = widget.resident['id'];

    await supabase.from('messages').insert({
      'sender_id': senderId,
      'sender_block': widget.resident['block'],
      'sender_flat': widget.resident['flat'],
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock?.trim() : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat?.trim() : null,
      'type': messageType,
      'text': text.isEmpty ? null : text,
      'image_url': imageUrl,
      'seen_at': null, // ensure schema allows null
    });

    setState(() {
      textController.clear();
      selectedImage = null;
      specBlock = null;
      specFlat = null;
      selectedScope = 'all';
    });
  }

  Future<void> markAsSeen(String messageId) async {
    try {
      await supabase
          .from('messages')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', messageId);
    } catch (e) {
      // ignore errors for now (log if needed)
      // print('Mark seen error: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> messagesStream() {
    // streaming all messages here, we filter client-side for flexibility
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final userBlock = _norm(widget.resident['block']);
    final userFlat = _norm(widget.resident['flat']);
    final userId = widget.resident['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages / Complaints"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Title row with Inbox / Sent below
          Container(
           // width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /*const Text(
                  "Messages / Complaints",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),*/
                //const SizedBox(height: ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => showSent = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: !showSent ? Colors.blue.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                        child: Text(
                          "Inbox",
                          style: TextStyle(
                            fontWeight: !showSent ? FontWeight.bold : FontWeight.w500,
                            color: !showSent ? Colors.blue : Colors.black87,
                          ),
                        ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => showSent = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: showSent ? Colors.blue.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                        child: Text(
                          "Sent",
                          style: TextStyle(
                            fontWeight: showSent ? FontWeight.bold : FontWeight.w500,
                            color: showSent ? Colors.blue : Colors.black87,
                          ),
                        ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // message/complaint label placed on the right
                   /* Chip(
                      label: Text(
                        messageType == 'complaint' ? 'Complaint' : 'Message',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey.shade200,
                    ),*/
                  ],
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: messagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;

                // Filter and normalize for reliable matching
                final filtered = all.where((m) {
                  // Sent view -> messages sent by current user
                  if (showSent) return (m['sender_id'] ?? '') == userId;

                  // Inbox -> messages addressed to this resident (or public)
                  final scope = (m['receiver_scope'] ?? '').toString();
                  if (scope == 'all' || scope == 'residents') return true;

                  if (scope == 'guards' && widget.resident['role'] == 'guard') return true;
                  if (scope == 'admin' && widget.resident['role'] == 'admin') return true;

                  if (scope == 'specific') {
                    final rBlock = _norm(m['receiver_block']);
                    final rFlat = _norm(m['receiver_flat']);
                    return rBlock == userBlock && rFlat == userFlat;
                  }

                  return false;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No messages yet", style: TextStyle(color: Colors.grey, fontSize: 15)),
                  );
                }

                // show newest at bottom (chat-like). Reverse the list (server returns newest first)
                final displayList = filtered.reversed.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final m = displayList[index];

                    final isMe = (m['sender_id'] ?? '') == userId;
                    // mark as seen if it's an inbox message and not yet seen and not sent by me
                    if (!showSent && !isMe && m['seen_at'] == null) {
                      // mark as seen (fire-and-forget)
                      markAsSeen(m['id'].toString());
                    }

                    // created_at formatting
                    DateTime? created;
                    try {
                      created = DateTime.tryParse(m['created_at']?.toString() ?? '');
                      if (created != null) created = created.toLocal();
                    } catch (e) {
                      created = null;
                    }

                    final dateLabel = created != null ? DateFormat('dd MMM yyyy').format(created) : '';
                    final timeLabel = created != null ? DateFormat('hh:mm a').format(created) : '';

                    // info line
                    final info = showSent
                        ? 'To ${m['receiver_block'] ?? 'All'} / ${m['receiver_flat'] ?? ''} • $dateLabel $timeLabel'
                        : 'From ${m['sender_block'] ?? ''} / ${m['sender_flat'] ?? ''} • $dateLabel $timeLabel';

                    // tick icons for sent messages
                    Widget ticks = const SizedBox.shrink();
                    if (showSent) {
                      final seen = m['seen_at'] != null;
                      ticks = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done, size: 14, color: seen ? Colors.lightBlueAccent : Colors.white70),
                          const SizedBox(width: 2),
                          Icon(Icons.done, size: 14, color: seen ? Colors.lightBlueAccent : Colors.white70),
                        ],
                      );
                    }

                    // bubble constraints for responsive layout
                    final bubbleColor = isMe ? Colors.blueAccent : Colors.grey.shade200;
                    final textColor = isMe ? Colors.white : Colors.black87;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // optional image
                              if (m['image_url'] != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(m['image_url'], width: double.infinity, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // message text
                              if ((m['text'] ?? '').toString().isNotEmpty)
                                Text(
                                  m['text'] ?? '',
                                  style: TextStyle(color: textColor, fontSize: 15),
                                ),

                              const SizedBox(height: 8),

                              // info row (date/time + sender/receiver + ticks)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      info,
                                      style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ticks,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT SECTION - kept outside list so keyboard shows above controls
          Builder(
            builder: (context) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return SafeArea(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // scope + type row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedScope,
                              items: const [
                                DropdownMenuItem(value: "all", child: Text("Send to All")),
                                DropdownMenuItem(value: "residents", child: Text("All Residents")),
                                DropdownMenuItem(value: "guards", child: Text("Guards")),
                                DropdownMenuItem(value: "admin", child: Text("Admin")),
                                DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                              ],
                              onChanged: (v) => setState(() => selectedScope = v ?? 'all'),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: messageType,
                            items: const [
                              DropdownMenuItem(value: "message", child: Text("Message")),
                              DropdownMenuItem(value: "complaint", child: Text("Complaint")),
                            ],
                            onChanged: (v) => setState(() => messageType = v ?? 'message'),
                          ),
                        ],
                      ),

                      if (selectedScope == 'specific')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(hintText: "Block"),
                                  onChanged: (v) => specBlock = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(hintText: "Flat"),
                                  onChanged: (v) => specFlat = v,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => pickImage(true)),
                          IconButton(icon: const Icon(Icons.photo), onPressed: () => pickImage(false)),
                          Expanded(
                            child: TextField(
                              controller: textController,
                              decoration: const InputDecoration(
                                hintText: "Type message or complaint...",
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              maxLines: null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: sendMessage,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}*/



/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentChatPage extends StatefulWidget {
  final Map<String, dynamic> resident;
  const ResidentChatPage({required this.resident, super.key});

  @override
  State<ResidentChatPage> createState() => _ResidentChatPageState();
}

class _ResidentChatPageState extends State<ResidentChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController textController = TextEditingController();
  File? selectedImage;
  String selectedScope = "all";
  String messageType = "message";
  String? specBlock;
  String? specFlat;
  bool showSent = false;
  final picker = ImagePicker();

  Future<void> pickImage(bool fromCamera) async {
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 65,
    );
    if (picked != null) setState(() => selectedImage = File(picked.path));
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return null;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    await supabase.storage.from('message').upload(fileName, selectedImage!);
    return supabase.storage.from('message').getPublicUrl(fileName);
  }

  Future<void> sendMessage() async {
    if (textController.text.trim().isEmpty) return;

    final imageUrl = await uploadImage();
    final sender = widget.resident['id'];

    await supabase.from('messages').insert({
      'sender_id': sender,
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock?.trim() : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat?.trim() : null,
      'type': messageType,
      'text': textController.text.trim(),
      'image_url': imageUrl,
    });

    setState(() {
      textController.clear();
      selectedImage = null;
      specBlock = null;
      specFlat = null;
    });
  }

  Stream<List<Map<String, dynamic>>> inboxStream() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final userBlock = widget.resident['block']?.toString().trim();
    final userFlat = widget.resident['flat']?.toString().trim();
    final userId = widget.resident['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages / Complaints"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        actions: [
          TextButton(
            onPressed: () => setState(() => showSent = false),
            child: Text("Inbox",
                style: TextStyle(color: showSent ? Colors.grey : Colors.white)),
          ),
          TextButton(
            onPressed: () => setState(() => showSent = true),
            child: Text("Sent",
                style: TextStyle(color: showSent ? Colors.white : Colors.grey)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: inboxStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;

                final filtered = showSent
                    ? all.where((m) => m['sender_id'] == userId).toList()
                    : all.where((m) {
                  return m['receiver_scope'] == 'all' ||
                      m['receiver_scope'] == 'residents' ||
                      (m['receiver_scope'] == 'specific' &&
                          m['receiver_block']?.toString().trim() == userBlock &&
                          m['receiver_flat']?.toString().trim() == userFlat);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages yet",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: filtered.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    final isMe = m['sender_id'] == userId;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['image_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(m['image_url'], width: 200),
                              ),
                            Text(
                              m['text'] ?? "",
                              style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// INPUT BAR SAFE
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Column(
                children: [
                  DropdownButtonFormField(
                    initialValue: selectedScope,
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Send to All")),
                      DropdownMenuItem(value: "residents", child: Text("All Residents")),
                      DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                    ],
                    onChanged: (v) => setState(() => selectedScope = v!),
                  ),

                  if (selectedScope == "specific")
                    Row(
                      children: [
                        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Block"), onChanged: (v) => specBlock = v)),
                        const SizedBox(width: 6),
                        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Flat"), onChanged: (v) => specFlat = v)),
                      ],
                    ),

                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => pickImage(true)),
                      IconButton(icon: const Icon(Icons.photo), onPressed: () => pickImage(false)),
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: const InputDecoration(hintText: "Type message..."),
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: sendMessage),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}*/
