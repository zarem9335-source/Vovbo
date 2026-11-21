import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';
import 'qr_scanner_screen.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final subs = engine.subscriptions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Subscriptions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Scan Sub QR',
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: DragonColors.electricBlue),
            onPressed: () async {
              final scanned = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
              if (scanned != null && context.mounted) {
                try {
                  final count = await engine.addAndFetchSubscription(scanned);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Subscription added ($count configs)')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Sync All',
            icon: engine.isUpdatingSubs
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DragonColors.electricBlue,
                    ),
                  )
                : const Icon(Icons.sync_rounded,
                    color: DragonColors.electricBlue),
            onPressed:
                engine.isUpdatingSubs ? null : engine.refreshAllSubscriptions,
          ),
          IconButton(
            tooltip: 'Add Subscription',
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: DragonColors.crimsonRed),
            onPressed: () => _showAddSubDialog(context, engine),
          ),
        ],
      ),
      body: subs.isEmpty
          ? const Center(
              child: Text(
                'No subscription links yet.\nTap + or QR icon to add a sub link.\nSubs auto-update every time you open the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DragonColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: subs.length,
              itemBuilder: (_, index) {
                final sub = subs[index];
                final last = sub.lastUpdated != null
                    ? '${sub.lastUpdated!.hour.toString().padLeft(2, '0')}:${sub.lastUpdated!.minute.toString().padLeft(2, '0')}'
                    : 'Never';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: Icon(Icons.rss_feed_rounded,
                          color: DragonColors.electricBlue),
                    ),
                    title: Text(sub.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${sub.configCount} configs • Last sync: $last\n${sub.url}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: DragonColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'کپی لینک سابسکیرپشن',
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: DragonColors.electricBlue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: sub.url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لینک سابسکیرپشن کپی شد!')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded,
                              color: DragonColors.electricBlue),
                          onPressed: () => engine.refreshSubscription(sub),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: DragonColors.crimsonRed),
                          onPressed: () => engine.deleteSubscription(sub.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSubDialog(BuildContext context, VpnEngineService engine) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DragonColors.charcoal,
        title: const Text('Add Subscription Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final count = await engine.addAndFetchSubscription(
                  urlCtrl.text,
                  name: nameCtrl.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Synced $count config(s)')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sub error: $e')),
                  );
                }
              }
            },
            child: const Text('Add & Sync'),
          ),
        ],
      ),
    );
  }
}
