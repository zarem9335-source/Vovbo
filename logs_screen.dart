import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final logs = engine.logs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Connection Logs',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: DragonColors.crimsonRed),
            onPressed: engine.clearLogs,
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text('No logs recorded yet.',
                  style: TextStyle(color: DragonColors.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: logs.length,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  logs[index],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: logs[index].contains('ERROR') ||
                            logs[index].contains('failed')
                        ? DragonColors.crimsonRed
                        : DragonColors.electricBlue,
                  ),
                ),
              ),
            ),
    );
  }
}
