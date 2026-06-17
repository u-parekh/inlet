import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentMessagePage extends StatefulWidget {
  final Map<String, dynamic> resident; // contains block & flat
  const ResidentMessagePage({required this.resident, super.key});

  @override
  State<ResidentMessagePage> createState() => _ResidentMessagePageState();
}

class _ResidentMessagePageState extends State<ResidentMessagePage> {
  final supabase = Supabase.instance.client;
  final TextEditingController messageController = TextEditingController();
  final picker = ImagePicker();
  File? selectedImage;
  String selectedScope = "all";
  String messageType = "message";
  String? specBlock;
  String? specFlat;

  Future<void> pickImage(bool fromCamera) async {
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 60,
    );
    if (picked != null) setState(() => selectedImage = File(picked.path));
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    await supabase.storage
        .from('message')
        .upload(fileName, selectedImage!);

    return supabase.storage.from('message').getPublicUrl(fileName);
  }

  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty) return;
    final imageUrl = await uploadImage();
    final senderId = supabase.auth.currentUser!.id;

    await supabase.from('messages').insert({
      'sender_id': senderId,
      'receiver_scope': selectedScope,
      'receiver_block': selectedScope == 'specific' ? specBlock : null,
      'receiver_flat': selectedScope == 'specific' ? specFlat : null,
      'type': messageType,
      'text': messageController.text.trim(),
      'image_url': imageUrl,
    });

    setState(() {
      messageController.clear();
      selectedImage = null;
      specBlock = null;
      specFlat = null;
    });
  }

  Stream<List<Map<String, dynamic>>> fetchMessages() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resident Messages")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: fetchMessages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return Card(
                      child: ListTile(
                        title: Text(m['text']),
                        subtitle: Text("${m['type']} • ${m['receiver_scope']}"),
                        trailing: m['image_url'] != null
                            ? Image.network(m['image_url'], width: 60)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // SEND MESSAGE UI
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                DropdownButtonFormField(
                  initialValue: selectedScope,
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Send to All")),
                    DropdownMenuItem(value: "admin", child: Text("Admin")),
                    DropdownMenuItem(value: "guards", child: Text("Guards")),
                    DropdownMenuItem(value: "residents", child: Text("All Residents")),
                    DropdownMenuItem(value: "specific", child: Text("Specific Resident")),
                  ],
                  onChanged: (v) => setState(() => selectedScope = v!),
                ),

                if (selectedScope == "specific")
                  Row(
                    children: [
                      Expanded(child: TextField(decoration: const InputDecoration(hintText: "Block"), onChanged: (v) => specBlock = v)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(decoration: const InputDecoration(hintText: "Flat"), onChanged: (v) => specFlat = v)),
                    ],
                  ),

                DropdownButtonFormField(
                  initialValue: messageType,
                  items: const [
                    DropdownMenuItem(value: "message", child: Text("Message")),
                    DropdownMenuItem(value: "complaint", child: Text("Complaint")),
                  ],
                  onChanged: (v) => setState(() => messageType = v!),
                ),

                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(hintText: "Write message..."),
                ),

                if (selectedImage != null)
                  Image.file(selectedImage!, height: 120),

                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => pickImage(true)),
                    IconButton(icon: const Icon(Icons.photo), onPressed: () => pickImage(false)),
                    const Spacer(),
                    ElevatedButton(onPressed: sendMessage, child: const Text("Send")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
