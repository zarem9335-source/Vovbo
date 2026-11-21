import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';
import 'qr_scanner_screen.dart';

class ConfigsScreen extends StatelessWidget {
  const ConfigsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final configs = engine.configs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Configurations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Scan QR Code',
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: DragonColors.electricBlue),
            onPressed: () async {
              final scanned = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
              if (scanned != null && context.mounted) {
                final count = await engine.importRawInput(scanned);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported $count via QR')),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Auto-Select Best Ping',
            icon: const Icon(Icons.flash_auto_rounded,
                color: DragonColors.electricBlue),
            onPressed: () => engine.autoSelectBestPing(connectAfter: false),
          ),
          IconButton(
            tooltip: 'Import Config',
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: DragonColors.crimsonRed),
            onPressed: () => _showImportSheet(context, engine),
          ),
        ],
      ),
      body: configs.isEmpty
          ? const Center(
              child: Text(
                'No configs yet.\nTap + or QR icon to import.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DragonColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final cfg = configs[index];
                final selected = cfg.id == engine.selectedConfigId;
                final quotaInfo = (cfg.hasQuotaLimit || cfg.hasTimeLimit)
                    ? '\n${cfg.remainingQuotaLabel} • ${cfg.remainingTimeLabel}'
                    : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selected
                          ? DragonColors.electricBlue
                          : Colors.white10,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => engine.selectConfig(cfg.id),
                    leading: CircleAvatar(
                      backgroundColor:
                          DragonColors.crimsonRed.withOpacity(0.16),
                      child: Icon(
                        cfg.protocol == VpnProtocol.wireguard
                            ? Icons.security_rounded
                            : cfg.protocol == VpnProtocol.v2ray
                                ? Icons.flash_on_rounded
                                : Icons.vpn_key_rounded,
                        color: DragonColors.electricBlue,
                      ),
                    ),
                    title: Text(cfg.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${cfg.protocolLabel} • ${cfg.serverAddress}:${cfg.port}$quotaInfo',
                      style: const TextStyle(
                          fontSize: 12, color: DragonColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => engine.testPing(cfg),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cfg.pingMs == null
                                  ? 'Ping'
                                  : cfg.pingMs! < 0
                                      ? 'Timeout'
                                      : '${cfg.pingMs} ms',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (cfg.pingMs ?? 999) > 0 &&
                                        (cfg.pingMs ?? 999) < 180
                                    ? DragonColors.electricBlue
                                    : DragonColors.crimsonRed,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'کپی لینک کانفیگ',
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: DragonColors.electricBlue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: cfg.rawConfig));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لینک کانفیگ کپی شد!')),
                            );
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'test_connect') {
                              final msg = await engine.testProtocolConfig(cfg);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg)));
                              }
                            } else if (value == 'quota') {
                              _showQuotaAndSplitDialog(context, engine, cfg);
                            } else if (value == 'edit') {
                              _showEditDialog(context, engine, cfg);
                            } else if (value == 'delete') {
                              engine.deleteConfig(cfg.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'test_connect',
                                child: Text('Test & Connect Now')),
                            PopupMenuItem(
                                value: 'quota',
                                child: Text('Quota / Time / Split')),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showQuotaAndSplitDialog(
      BuildContext context, VpnEngineService engine, VpnConfig cfg) {
    final gbCtrl = TextEditingController(
        text: cfg.hasQuotaLimit
            ? (cfg.quotaBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)
            : '10');
    final minCtrl = TextEditingController(
        text: cfg.hasTimeLimit ? cfg.timeLimitMinutes.toString() : '60');
    final splitTotalCtrl = TextEditingController(text: '100');
    final splitPartsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DragonColors.charcoal,
        title: const Text('Quota, Timer & Split'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Set Limit for This Config',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: gbCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Data Limit (GB, 0 = Unlimited)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Time Limit (Minutes, 0 = Unlimited)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final gb = double.tryParse(gbCtrl.text) ?? 0;
                  final mins = int.tryParse(minCtrl.text) ?? 0;
                  cfg.quotaBytes =
                      gb > 0 ? (gb * 1024 * 1024 * 1024).round() : null;
                  cfg.timeLimitMinutes = mins > 0 ? mins : null;
                  cfg.usedBytes = 0;
                  cfg.usedSeconds = 0;
                  engine.updateConfig(cfg);
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Limit to Config'),
              ),
              const Divider(height: 24),
              const Text('Split Volume (e.g. 100 GB -> 10 x 10 GB)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: splitTotalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Total GB', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: splitPartsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Parts', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final total = double.tryParse(splitTotalCtrl.text) ?? 100;
                  final parts = int.tryParse(splitPartsCtrl.text) ?? 10;
                  final mins = int.tryParse(minCtrl.text);
                  await engine.splitConfigIntoParts(
                    cfg,
                    totalGb: total,
                    parts: parts,
                    timeLimitMinutesPerPart:
                        (mins != null && mins > 0) ? mins : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Split & Create Parts'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportSheet(BuildContext context, VpnEngineService engine) {
    final textCtrl = TextEditingController();
    final subCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DragonColors.charcoal,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Import Configuration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Paste vless://, vmess://, .conf, .ovpn, or Xray JSON...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final clip = await Clipboard.getData(Clipboard.kTextPlain);
                    if (clip?.text != null) textCtrl.text = clip!.text!;
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final count = await engine.importRawInput(textCtrl.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported $count config(s)')),
                  );
                }
              },
              child: const Text('Import Text / Link'),
            ),
            const Divider(height: 22),
            TextField(
              controller: subCtrl,
              decoration: const InputDecoration(
                hintText: 'Subscription URL (https://...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Add Sub'),
                    onPressed: () async {
                      try {
                        final count =
                            await engine.addAndFetchSubscription(subCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added $count from sub')),
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Pick File'),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['conf', 'ovpn', 'json', 'txt'],
                      );
                      if (result != null && result.files.single.path != null) {
                        final content =
                            await File(result.files.single.path!).readAsString();
                        final count = await engine.importRawInput(
                          content,
                          customName: result.files.single.name,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Imported $count file(s)')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, VpnEngineService engine, VpnConfig cfg) {
    final nameCtrl = TextEditingController(text: cfg.name);
    final rawCtrl = TextEditingController(text: cfg.rawConfig);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DragonColors.charcoal,
        title: const Text('Edit Config'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
              controller: rawCtrl,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Raw Config'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              engine.updateConfig(VpnConfig(
                id: cfg.id,
                name: nameCtrl.text.trim(),
                protocol: cfg.protocol,
                rawConfig: rawCtrl.text.trim(),
                serverAddress: cfg.serverAddress,
                port: cfg.port,
                isUdpPreferred: cfg.isUdpPreferred,
                pingMs: cfg.pingMs,
                subscriptionId: cfg.subscriptionId,
                quotaBytes: cfg.quotaBytes,
                usedBytes: cfg.usedBytes,
                timeLimitMinutes: cfg.timeLimitMinutes,
                usedSeconds: cfg.usedSeconds,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
