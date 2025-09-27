import 'package:flutter/material.dart';

import '../theme.dart';

class CommandMenu extends StatelessWidget {
  final List<Map<String, dynamic>> commands;
  final String activeCommand;
  final Function(String) onCommandSelected;

  const CommandMenu({
    super.key,
    required this.commands,
    required this.activeCommand,
    required this.onCommandSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemCount: commands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final cmd = commands[i];
          final isActive = activeCommand == cmd['key'];

          return GestureDetector(
            onTap: () => onCommandSelected(cmd['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.fill,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cmd['icon'] as IconData,
                    size: 28,
                    color: isActive ? AppColors.fill : AppColors.dark,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cmd['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? AppColors.fill : AppColors.dark,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
