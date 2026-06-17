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
  bool isSending = false; 

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

    setState(() => isSending = true); 

    final imageUrl = await uploadImage();
    final senderId = widget.resident['id'];

    await supabase.from('messages').insert({
      'sender_id': senderId,
      'sender_block': widget.resident['block'],
      'sender_flat': widget.resident['flat'],
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock?.trim() : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat?.trim() : null,
      'type': "message", //  Removed complaint option
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
          //  CENTERED Inbox / Sent
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

                  if (scope == 'admin' && widget.resident['role'] == 'Admin') return true;   

                  if (scope == 'guards' && widget.resident['role'] == 'Guard') return true;   

                 
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

          //  Compact Input Section + Loading Send Button
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
                          DropdownMenuItem(value: "admin", child: Text("Admin  ")),     
                          DropdownMenuItem(value: "guards", child: Text("Guards")),
                          DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                        ],
                        onChanged: (v) => setState(() => selectedScope = v ?? 'all'),
                      ),
                    ],
                  ),

                  //  SHOW BLOCK + FLAT INPUTS ONLY WHEN specific SELECTED
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

                  //  TEXT + IMAGE + SEND BUTTON
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

                      //  SEND BUTTON WITH LOADING
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

