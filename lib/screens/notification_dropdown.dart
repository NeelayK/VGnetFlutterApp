import 'package:flutter/material.dart';

import '../theme.dart';

class NotificationsDropdown extends StatelessWidget {
  final bool showDropdown;
  final List<Map<String, dynamic>> notifications;
  final Function(Map<String, dynamic>) onMarkAsRead;

  const NotificationsDropdown({
    super.key,
    required this.showDropdown,
    required this.notifications,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDropdown) return const SizedBox();

    return Positioned(
      right: 20,
      top: 0,
      child: AnimatedOpacity(
        opacity: showDropdown ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 280,
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: notifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No new activity'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final notif = notifications[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.notifications, color: Colors.red),
                        title: Text(
                          notif['description'] ?? "No description",
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          notif['timestamp']?.toString() ?? "",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => onMarkAsRead(notif),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
