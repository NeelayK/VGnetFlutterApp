import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? currentUserName;
  String? currentUserRole;
  List<Map<String, dynamic>> profiles = [];
  Map<String, bool> expandedHistory = {};
  Map<String, List<Map<String, dynamic>>> historyCache = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
  }

  /// Fetch current user's profile to determine role and name
  Future<void> _fetchCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return; // ✅ Prevent setState after dispose
      setState(() {
        currentUserName = profile?['name'] as String?;
        currentUserRole = profile?['role'] as String?;
      });

      await _fetch();
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserHistory(String name) async {
    final data = await supabase
        .from('history')
        .select('request_name, created_at')
        .eq('name', name)
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> _fetch() async {
    try {
      var query = supabase
          .from('profiles')
          .select('name, in_lab, work_time, minutes_this_week, entry_exit_time')
          .eq('role', 'student')
          .order('name');

      final data = await query;

      if (!mounted) return; // ✅ Avoid calling setState if disposed
      setState(() {
        profiles = (data as List).cast<Map<String, dynamic>>();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Work Hours',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          // Responsive 3-column wrap layout
          LayoutBuilder(
  builder: (context, constraints) {
    double screenWidth = constraints.maxWidth;

    // Decide columns dynamically
    int columns;
    if (screenWidth >= 1200) {
      columns = 3;
    } else if (screenWidth >= 800) {
      columns = 2;
    } else {
      columns = 1;
    }

    double cardWidth = (screenWidth / columns) - 20;
    cardWidth = cardWidth.clamp(280, double.infinity); // ✅ Minimum width: 280px

    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: profiles.map((item) {
        final isPresent = item['in_lab'] == true;
        final name = item['name'] as String? ?? '';
        final isCurrentUser = name == currentUserName;
        final isAdmin = currentUserRole == 'admin';

        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 280, // ✅ Minimum width
            maxWidth: cardWidth,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Watch Icon Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (isAdmin || isCurrentUser)
                      GestureDetector(
                        onTap: () async {
                          if (expandedHistory[name] == true) {
                            setState(() {
                              expandedHistory[name] = false;
                            });
                          } else {
                            if (!historyCache.containsKey(name)) {
                              final history = await _fetchUserHistory(name);
                              historyCache[name] = history;
                            }
                            if (!mounted) return;
                            setState(() {
                              expandedHistory[name] = true;
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: expandedHistory[name] == true ? 36 : 24,
                          height: expandedHistory[name] == true ? 36 : 24,
                          child: Icon(
                            Icons.watch_later_outlined,
                            color: Colors.blueGrey,
                            size: expandedHistory[name] == true ? 32 : 24,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // Work hours (only admin or self)
                if (isAdmin || isCurrentUser) ...[
                  Text(
                    "Today: ${_formatWorkTime(item['work_time'])}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Week: ${_formatWorkTime(item['minutes_this_week'])}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Last Entry/Exit Timestamp
                Text(
                  "Last Log: ${_formatTime(item['entry_exit_time'])}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),

                // Status
                Text(
                  isPresent ? "Present" : "Not in Lab",
                  style: TextStyle(
                    color: isPresent
                        ? const Color.fromARGB(255, 62, 172, 175)
                        : const Color.fromARGB(255, 208, 93, 139),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                // Expanded history
                if ((isAdmin || isCurrentUser) &&
                    expandedHistory[name] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildHistoryWidget(
                        historyCache[name] ?? [], isPresent),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  },
),

        ],
      ),
    );
  }

  /// Build history dropdown with optimized "Present" handling
  Widget _buildHistoryWidget(List<Map<String, dynamic>> logs, bool isPresent) {
    if (logs.isEmpty) {
      return const Text(
        "No history found.",
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (final log in logs) {
      final dt = DateTime.tryParse(log['created_at'].toString())?.toLocal();
      if (dt == null) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(dt);
      groupedByDate.putIfAbsent(dateKey, () => []).add(log);
    }

    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    int diffMinutes(DateTime a, DateTime b) =>
        b.difference(a).inMinutes.abs();

    const toleranceMinutes = 15;
    List<Widget> dateWidgets = [];

    for (final date in sortedDates) {
      final dayLogs = groupedByDate[date]!..sort((a, b) {
          final dtA = DateTime.tryParse(a['created_at'].toString())?.toLocal();
          final dtB = DateTime.tryParse(b['created_at'].toString())?.toLocal();
          if (dtA == null || dtB == null) return 0;
          return dtA.compareTo(dtB);
        });

      final dateObj = DateTime.parse(date);
      final isToday = DateTime.now().difference(dateObj).inDays == 0;

      dateWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            DateFormat("MMMM d'${_daySuffix(dateObj.day)}'").format(dateObj),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

      DateTime? currentEntry;

      for (int i = 0; i < dayLogs.length; i++) {
        final rawReq =
            (dayLogs[i]['request_name']?.toString() ?? '').toLowerCase();
        final dt =
            DateTime.tryParse(dayLogs[i]['created_at'].toString())?.toLocal();
        if (dt == null) continue;

        final isEntry = rawReq == 'entry' || rawReq == 'enter';
        final isExit = rawReq == 'exit' || rawReq == 'leave';

        if (!isEntry && !isExit) continue;

        if (isEntry) {
          if (currentEntry == null) {
            currentEntry = dt;
          } else {
            if (diffMinutes(currentEntry, dt) > toleranceMinutes) {
              if (!(isPresent && isToday)) {
                dateWidgets.add(
                    _discrepancyWidget("Exit Discrepancy", currentEntry, null));
              }
              currentEntry = dt;
            }
          }
        } else if (isExit) {
          DateTime latestExit = dt;
          int j = i + 1;
          while (j < dayLogs.length) {
            final nextReq =
                (dayLogs[j]['request_name']?.toString() ?? '').toLowerCase();
            final nextIsExit = nextReq == 'exit' || nextReq == 'leave';
            if (!nextIsExit) break;

            final nextDt = DateTime.tryParse(dayLogs[j]['created_at'].toString())
                ?.toLocal();
            if (nextDt == null) break;

            if (diffMinutes(latestExit, nextDt) <= toleranceMinutes) {
              latestExit = nextDt;
              i = j;
              j++;
            } else {
              break;
            }
          }

          if (currentEntry != null) {
            final mins = latestExit.difference(currentEntry).inMinutes;
            if (mins >= 0) {
              dateWidgets.add(_intervalWidget(
                  currentEntry, latestExit, _formatWorkTime(mins)));
            }
            currentEntry = null;
          } else {
            dateWidgets.add(
                _discrepancyWidget("Entry Discrepancy", null, latestExit));
          }
        }
      }

      // ✅ Show "(Present)" only for today
      if (currentEntry != null && isPresent && isToday) {
        dateWidgets.add(_intervalWidget(
          currentEntry,
          DateTime.now(),
          "${_formatWorkTime(DateTime.now().difference(currentEntry).inMinutes)} (Present)",
        ));
      } else if (currentEntry != null) {
        dateWidgets
            .add(_discrepancyWidget("Exit Discrepancy", currentEntry, null));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dateWidgets,
      ),
    );
  }

  Widget _intervalWidget(DateTime start, DateTime end, String duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}"),
          Text(duration, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _discrepancyWidget(String type, DateTime? start, DateTime? end) {
    String left = start != null ? DateFormat('h:mm a').format(start) : "???";
    String right = end != null ? DateFormat('h:mm a').format(end) : "???";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$left - $right"),
          Text(type,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.tryParse(ts.toString());
      if (dt == null) return '-';
      return DateFormat('MMM d, h:mm a').format(dt.toLocal());
    } catch (_) {
      return '-';
    }
  }

  String _formatWorkTime(dynamic minutes) {
    if (minutes == null) return "0m";
    final mins = int.tryParse(minutes.toString()) ?? 0;
    final hours = mins ~/ 60;
    final remainingMinutes = mins % 60;
    if (hours > 0 && remainingMinutes > 0) {
      return "${hours}h ${remainingMinutes}m";
    } else if (hours > 0) {
      return "${hours}h";
    } else {
      return "${remainingMinutes}m";
    }
  }
}
