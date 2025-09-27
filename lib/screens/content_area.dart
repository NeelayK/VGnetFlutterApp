import 'package:flutter/material.dart';

class ContentArea extends StatelessWidget {
  final String activeCommand;
  final Widget doorsScreen;
  final Widget unknownVisitorLogsScreen;
  final Widget logsScreen;
  final Widget workScreen;
  final Widget plantMonitorScreen;
  final Widget airQualityScreen;

  const ContentArea({
    super.key,
    required this.activeCommand,
    required this.doorsScreen,
    required this.unknownVisitorLogsScreen,
    required this.logsScreen,
    required this.workScreen,
    required this.plantMonitorScreen,
    required this.airQualityScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: SingleChildScrollView(
          key: ValueKey(activeCommand),
          padding: const EdgeInsets.only(bottom: 60),
          child: Builder(
            builder: (_) {
              if (activeCommand == 'doors') return doorsScreen;
              if (activeCommand == 'logs') return logsScreen;
              if (activeCommand == 'unknown_visitor_logs') return unknownVisitorLogsScreen;
              if (activeCommand == 'work') return workScreen;
              if (activeCommand == 'plant') return plantMonitorScreen;
              if (activeCommand == 'air_quality') return airQualityScreen;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}
