import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../task/screens/task_shell_screen.dart';
import 'poc_list_screen.dart';

enum WorkMode { poc, task }

class WorkShellScreen extends ConsumerStatefulWidget {
  const WorkShellScreen({super.key});

  @override
  ConsumerState<WorkShellScreen> createState() => _WorkShellScreenState();
}

class _WorkShellScreenState extends ConsumerState<WorkShellScreen> {
  WorkMode _mode = WorkMode.poc;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<WorkMode>(
              segments: const [
                ButtonSegment(
                  value: WorkMode.poc,
                  icon: Icon(Icons.science_outlined),
                  label: Text('PoC & Demo'),
                ),
                ButtonSegment(
                  value: WorkMode.task,
                  icon: Icon(Icons.task_alt_outlined),
                  label: Text('Task'),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? palette.primary
                      : palette.textSecondary,
                ),
              ),
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
          ),
        ),
      ),
      body: _mode == WorkMode.poc
          ? const PocListScreen(embedded: true)
          : const TaskShellScreen(embedded: true),
    );
  }
}
