import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoticeCard extends StatefulWidget {
  final Map<String, dynamic> notice;
  const NoticeCard({super.key, required this.notice});

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {

    final n = widget.notice;

    //print(n); // ✅ TEMP DEBUG - Check keys in console

    // ✅ Safely handle date key variations
    final createdAtRaw = n['created_at'] ?? n['inserted_at'] ?? n['timestamp'] ?? n['createdAt'];
    DateTime? createdAt = createdAtRaw != null ? DateTime.parse(createdAtRaw).toLocal() : null;

    final date = createdAt != null ? DateFormat('dd MMM yy').format(createdAt) : '';
    final time = createdAt != null ? DateFormat('hh:mm a').format(createdAt) : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    n['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(time, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox.shrink(),
              secondChild: Text(
                n['body'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),

            Align(
              alignment: Alignment.centerRight,
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoticeCard extends StatefulWidget {
  final Map<String, dynamic> notice;
  const NoticeCard({super.key, required this.notice});

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;

    final createdAt = DateTime.tryParse(n['created_at'] ?? '')?.toLocal();
    final date = createdAt != null ? DateFormat('dd MMM yy').format(createdAt) : '';
    final time = createdAt != null ? DateFormat('hh:mm a').format(createdAt) : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),

                // Title
                Expanded(
                  child: Text(
                    n['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ),

                // Date & Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(time, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Body (Expand/Collapse)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox.shrink(),
              secondChild: Text(
                n['body'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),

            const SizedBox(height: 4),

            // Arrow
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}*/
