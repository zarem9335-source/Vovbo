import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _subjCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<VpnEngineService>().syncTicketsFromServer());
  }

  @override
  void dispose() {
    _subjCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final tickets = engine.tickets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تیکت و پشتیبانی',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'بروزرسانی تیکت‌ها',
            icon: const Icon(Icons.refresh_rounded,
                color: DragonColors.electricBlue),
            onPressed: engine.syncTicketsFromServer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ارسال تیکت جدید به پشتیبانی',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _subjCtrl,
                    decoration: const InputDecoration(
                      labelText: 'موضوع تیکت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات مشکل یا درخواست شما',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DragonColors.electricBlue,
                        foregroundColor: Colors.black,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'در حال ارسال...' : 'ارسال تیکت'),
                      onPressed: _sending
                          ? null
                          : () async {
                              if (_subjCtrl.text.trim().isEmpty ||
                                  _msgCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('موضوع و متن تیکت را وارد کنید')),
                                );
                                return;
                              }
                              setState(() => _sending = true);
                              await engine.submitTicket(
                                subject: _subjCtrl.text,
                                message: _msgCtrl.text,
                              );
                              if (mounted) {
                                _subjCtrl.clear();
                                _msgCtrl.clear();
                                setState(() => _sending = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('تیکت شما ثبت و ارسال شد!')),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('تیکت‌های من (${tickets.length})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (tickets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('هنوز تیکتی ثبت نکرده‌اید.',
                    style: TextStyle(color: DragonColors.textSecondary)),
              ),
            )
          else
            ...tickets.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(t.subject,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: t.status == 'answered'
                                    ? Colors.greenAccent.withOpacity(0.18)
                                    : DragonColors.electricBlue.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t.status == 'answered' ? 'پاسخ داده شده' : 'در انتظار پاسخ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: t.status == 'answered'
                                      ? Colors.greenAccent
                                      : DragonColors.electricBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(t.message, style: const TextStyle(fontSize: 12)),
                        if (t.adminReply.isNotEmpty) ...[
                          const Divider(height: 14),
                          Text('پاسخ پشتیبانی:',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: DragonColors.electricBlue)),
                          const SizedBox(height: 4),
                          Text(t.adminReply,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.greenAccent)),
                        ],
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
