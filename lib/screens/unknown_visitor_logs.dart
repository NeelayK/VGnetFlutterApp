import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class UnknownVisitorLogsScreen extends StatefulWidget {
  const UnknownVisitorLogsScreen({super.key});

  @override
  State<UnknownVisitorLogsScreen> createState() =>
      _UnknownVisitorLogsScreenState();
}

class _UnknownVisitorLogsScreenState extends State<UnknownVisitorLogsScreen> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> logs = [];
  final String bucketName = "unknown_visitor";

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  /// Fetch logs and generate public URLs for images
  Future<void> _fetchLogs() async {
    try {
      final data = await supabase
          .from('unknown_visitor_logs')
          .select()
          .order('timestamp', ascending: false);

      final fetchedLogs = (data as List).cast<Map<String, dynamic>>();

      // Generate public URLs for each image
      for (var log in fetchedLogs) {
        final fileName = log['file_name'];
        final publicUrl =
            supabase.storage.from(bucketName).getPublicUrl(fileName);
        log['image_url'] = publicUrl;
      }

      setState(() {
        logs = fetchedLogs;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ Determine columns dynamically based on screen size
    int crossAxisCount = 2; // Default for small screens
    if (screenWidth > 1200) {
      crossAxisCount = 4; // Large screens
    } else if (screenWidth > 800) {
      crossAxisCount = 3; // Medium screens
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty) {
      return const Center(
        child: Text(
          "No unknown visitors",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900, // ✅ Limit scaling for very large displays
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Recent Unknown Visitors",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ✅ Responsive grid with rounded corners & no extra bottom spacing
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: logs.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.74, // Adjust for balanced design
                ),
                itemBuilder: (context, index) {
                  final log = logs[index];

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(16), // ✅ More rounded corners
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Visitor Image with proper aspect ratio
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1/1, // ✅ Maintain image ratio
                            child: Image.network(
                              log['image_url'],
                              fit: BoxFit.cover, // ✅ Fill without stretching
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Timestamp
                        Text(
                          "Time: ${_formatTime(log['timestamp'])}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Door ID
                        Text(
                          "Door: ${log['door_id'] ?? 'Unknown'}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
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

  /// Format the timestamp nicely
  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return ts.toString();
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }
}
