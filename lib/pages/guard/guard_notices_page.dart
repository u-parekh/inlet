import 'package:flutter/material.dart';
import '../../services/db_service.dart';
import '../notice_card.dart';

class GuardNoticesPage extends StatelessWidget {
  const GuardNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent.withOpacity(0.1),     // ✅ Blue Background
        centerTitle: true,                      // ✅ Center Title
        elevation: 0,
        title: const Text(
          "Notice",
          style: TextStyle(
            color: Colors.black,                 // ✅ White Text
            //fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DBService.noticesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notices = snapshot.data!;

          // ✅ Correct filter (target = 'guard', not 'guards')
          final filtered = notices.where((n) =>
          (n['target'] == 'all' || n['target'] == 'guard')).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No notices yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return NoticeCard(notice: filtered[index]); // ✅ WhatsApp Style Card
            },
          );
        },
      ),
    );
  }
}

/*class GuardNoticesPage extends StatelessWidget {
  const GuardNoticesPage({super.key});
  @override Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String,dynamic>>>(
        stream: DBService.noticesStream(),
        builder: (c,s) {
          if (!s.hasData) return const Center(child:CircularProgressIndicator());
          final list = s.data!;
          final filtered = list.where((n) => (n['target']=='all' || n['target']=='guards')).toList();
          if (filtered.isEmpty) return const Center(child: Text('No notices yet'));
          return ListView.builder(itemCount: filtered.length, itemBuilder: (cx,i){
            final n = filtered[i];
            return Card(child: ListTile(title: Text(n['title'] ?? ''), subtitle: Text(n['body'] ?? '')));
          });
        }
    );
  }
}*/
