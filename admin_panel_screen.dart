import 'web_tunnel_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late IranianGateway _selectedGateway;
  late bool _gwEnabled;
  late TextEditingController _merchantCtrl;
  late TextEditingController _backendCtrl;
  late TextEditingController _webTunnelCtrl;
  final _freeNameCtrl = TextEditingController();
  final _freeLinkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final gw = context.read<VpnEngineService>().gatewayConfig;
    _selectedGateway = gw.gateway;
    _gwEnabled = gw.enabled;
    _merchantCtrl = TextEditingController(text: gw.merchantOrCard);
    _backendCtrl = TextEditingController(text: context.read<VpnEngineService>().backendUrl);
    _webTunnelCtrl = TextEditingController(text: context.read<VpnEngineService>().webTunnelUrl);
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _backendCtrl.dispose();
    _webTunnelCtrl.dispose();
    _freeNameCtrl.dispose();
    _freeLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final panels = engine.panels;
    final plans = engine.plans;
    final orders = engine.orders;
    final outbounds = engine.outbounds;
    final wgConfigs =
        engine.configs.where((c) => c.protocol == VpnProtocol.wireguard).toList();
    final ovpnConfigs =
        engine.configs.where((c) => c.protocol == VpnProtocol.openvpn).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Admin Command Center',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Add Panel (3x-UI / Marzban / Pasargad)',
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: DragonColors.electricBlue),
            onPressed: () => _showAddPanelDialog(context, engine),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [




          // 0-A. Customer Support Tickets (Admin Reply)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent_rounded,
                          color: DragonColors.electricBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تیکت‌های پشتیبانی مشتریان (${engine.tickets.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'بروزرسانی تیکت‌ها',
                        icon: const Icon(Icons.refresh_rounded,
                            color: DragonColors.electricBlue),
                        onPressed: engine.syncTicketsFromServer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (engine.tickets.isEmpty)
                    const Text('تیکتی ثبت نشده است.',
                        style: TextStyle(
                            fontSize: 12, color: DragonColors.textSecondary))
                  else
                    ...engine.tickets.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DragonColors.charcoal,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: DragonColors.electricBlue.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t.username} • ${t.subject}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(t.message, style: const TextStyle(fontSize: 12)),
                              if (t.adminReply.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('پاسخ شما: ${t.adminReply}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.greenAccent)),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.reply_rounded, size: 16),
                                  label: const Text('پاسخ به تیکت'),
                                  onPressed: () {
                                    final rCtrl = TextEditingController(
                                        text: t.adminReply);
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: DragonColors.charcoal,
                                        title: Text('پاسخ به ${t.username}'),
                                        content: TextField(
                                          controller: rCtrl,
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                            labelText: 'متن پاسخ',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('لغو'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await engine.replyTicket(
                                                  t, rCtrl.text);
                                              if (ctx.mounted) Navigator.pop(ctx);
                                            },
                                            child: const Text('ارسال پاسخ'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 0-B. Free Configs Section (Visible to ALL users in Configs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public_rounded,
                          color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'کانفیگ‌های رایگان (${engine.freeConfigs.length}) — نمایش برای همه کاربران',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _freeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام کانفیگ رایگان (مثلاً Free Germany)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _freeLinkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'لینک کانفیگ (vless:// یا vmess:// یا ...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('انتشار در بخش کانفیگ رایگان همه'),
                      onPressed: () async {
                        final ok = await engine.addFreeConfig(
                          name: _freeNameCtrl.text,
                          rawLink: _freeLinkCtrl.text,
                        );
                        if (context.mounted) {
                          if (ok) {
                            _freeNameCtrl.clear();
                            _freeLinkCtrl.clear();
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'کانفیگ رایگان منتشر شد و برای همه در Configs بالا می‌آید!'
                                  : 'لینک کانفیگ معتبر نیست'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  if (engine.freeConfigs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...engine.freeConfigs.map((fc) => ListTile(
                          dense: true,
                          title: Text(fc.name),
                          subtitle: Text('${fc.serverAddress}:${fc.port}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: DragonColors.crimsonRed),
                            onPressed: () => engine.deleteFreeConfig(fc.id),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 0. Admin Web Tunnel Panel (In-App Browser)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.language_rounded,
                          color: DragonColors.electricBlue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'پنل تانل تحت وب (ورود به سایت تانل)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _webTunnelCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'آدرس سایت یا پنل تانل (مثلاً http://IP:PORT)',
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
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('ورود به سایت تانل داخل برنامه'),
                      onPressed: () async {
                        final url = _webTunnelCtrl.text.trim();
                        if (url.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('آدرس سایت تانل را وارد کنید')),
                          );
                          return;
                        }
                        await engine.setWebTunnelUrl(url);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WebTunnelScreen(initialUrl: url),
                            ),
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

          // 0. Pending & Submitted Receipts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('رسیدهای واریزی مشتریان (${orders.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: 'بروزرسانی رسیدها از سرور',
                        icon: const Icon(Icons.refresh_rounded,
                            color: DragonColors.electricBlue),
                        onPressed: engine.syncOrdersFromServer,
                      ),
                    ],
                  ),
                  if (false) Text('',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (orders.isEmpty)
                    const Text('هنوز رسیدی ارسال نشده است.',
                        style: TextStyle(
                            fontSize: 12, color: DragonColors.textSecondary))
                  else
                    ...orders.map((ord) => Card(
                          color: DragonColors.charcoal,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${ord.username} • ${ord.planTitle} (${ord.priceTomans} تومان)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (ord.trackingCode.isNotEmpty)
                                  Text('کد پیگیری: ${ord.trackingCode}',
                                      style: const TextStyle(fontSize: 12)),
                                if (ord.receiptBase64 != null && ord.receiptBase64!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => Dialog(
                                          child: Image.memory(base64Decode(ord.receiptBase64!)),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(ord.receiptBase64!),
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ] else if (ord.receiptImagePath != null && File(ord.receiptImagePath!).existsSync()) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(ord.receiptImagePath!),
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (ord.status == OrderStatus.pending)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  DragonColors.electricBlue,
                                              foregroundColor: Colors.black),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('تایید و فعال‌سازی'),
                                          onPressed: () async {
                                            final msg =
                                                await engine.approveOrder(ord);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(msg)));
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  DragonColors.crimsonRed),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('رد رسید'),
                                          onPressed: () =>
                                              engine.rejectOrder(ord),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    ord.status == OrderStatus.approved
                                        ? 'تایید شده ✅'
                                        : 'رد شده ❌',
                                    style: TextStyle(
                                        color: ord.status == OrderStatus.approved
                                            ? DragonColors.electricBlue
                                            : DragonColors.crimsonRed,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 0.5. Outbound Pools & Volume Cap
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('اوتباند و سقف حجم رزرو (Outbound Pools)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_link_rounded,
                            color: DragonColors.electricBlue),
                        onPressed: () => _showAddOutboundDialog(context, engine),
                      ),
                    ],
                  ),
                  if (outbounds.isEmpty)
                    const Text(
                      'اوتباندی ثبت نشده است. با زدن آیکون بالا کانفیگ اوتباند و سقف حجم (مثلاً ۵۰۰ گیگ) را اضافه کنید.',
                      style: TextStyle(
                          fontSize: 12, color: DragonColors.textSecondary),
                    )
                  else
                    ...outbounds.map((ob) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${ob.name} (${ob.isExhausted ? "تکمیل شده" : "فعال"})',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ob.isExhausted
                                              ? DragonColors.crimsonRed
                                              : DragonColors.textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: DragonColors.crimsonRed,
                                        size: 20),
                                    onPressed: () =>
                                        engine.deleteOutboundPool(ob.id),
                                  ),
                                ],
                              ),
                              LinearProgressIndicator(
                                value: ob.usageRatio,
                                color: ob.isExhausted
                                    ? DragonColors.crimsonRed
                                    : DragonColors.electricBlue,
                                backgroundColor: Colors.white12,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'رزرو شده: ${ob.reservedGb.toStringAsFixed(1)} GB از ${ob.totalGb.toStringAsFixed(1)} GB • باقی‌مانده: ${ob.remainingGb.toStringAsFixed(1)} GB',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: DragonColors.textSecondary),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Volume & Price Plans for Gateway Checkout
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('پکیج‌های حجم و قیمت (فروش درگاه)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_box_rounded,
                            color: DragonColors.electricBlue),
                        onPressed: () => _showAddPlanDialog(context, engine),
                      ),
                    ],
                  ),
                  if (plans.isEmpty)
                    const Text('هیچ پکیجی ثبت نشده است.',
                        style: TextStyle(
                            fontSize: 12, color: DragonColors.textSecondary))
                  else
                    ...plans.map((pl) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${pl.title} (${pl.volumeGb} GB)'),
                          subtitle: Text(
                              '${pl.durationDays} روز • ${pl.priceTomans} تومان',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: DragonColors.electricBlue)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: DragonColors.crimsonRed),
                            onPressed: () => engine.deletePlan(pl.id),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Connected Panels
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connected Panels (3x-UI / Marzban / Pasargad)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (panels.isEmpty)
                    const Text('No panels added yet. Tap + above to connect.',
                        style: TextStyle(
                            fontSize: 12, color: DragonColors.textSecondary))
                  else
                    ...panels.map((p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${p.name} (${p.typeLabel})'),
                          subtitle: Text(p.baseUrl,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: DragonColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.sync,
                                    color: DragonColors.electricBlue),
                                onPressed: () async {
                                  final msg = await engine.syncPanel(p);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)));
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: DragonColors.crimsonRed),
                                onPressed: () => engine.deletePanel(p.id),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Instant WireGuard & OpenVPN Tester
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Instant WireGuard & OpenVPN Tester',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'WireGuard configs: ${wgConfigs.length}  •  OpenVPN configs: ${ovpnConfigs.length}',
                    style: const TextStyle(
                        fontSize: 12, color: DragonColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.security_rounded, size: 16),
                        label: const Text('Test WireGuard'),
                        onPressed: wgConfigs.isEmpty
                            ? null
                            : () async {
                                final res = await engine
                                    .testProtocolConfig(wgConfigs.first);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res)));
                                }
                              },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.vpn_key_rounded, size: 16),
                        label: const Text('Test OpenVPN'),
                        onPressed: ovpnConfigs.isEmpty
                            ? null
                            : () async {
                                final res = await engine
                                    .testProtocolConfig(ovpnConfigs.first);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res)));
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3.5. Central Backend Server URL
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('آدرس سرور مرکزی (برای دریافت رسید از گوشی‌های دیگر)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _backendCtrl,
                    decoration: const InputDecoration(
                      labelText: 'http://SERVER_IP:8090',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        engine.setBackendUrl(_backendCtrl.text);
                        engine.syncOrdersFromServer();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('آدرس سرور ذخیره و همگام‌سازی شد')),
                        );
                      },
                      child: const Text('ذخیره و همگام‌سازی'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Iranian Payment Gateways
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Iranian Payment Gateways (درگاه پرداخت ایرانی)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<IranianGateway>(
                    value: _selectedGateway,
                    decoration: const InputDecoration(
                      labelText: 'Select Gateway',
                      border: OutlineInputBorder(),
                    ),
                    items: IranianGateway.values
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(
                                  PaymentGatewayConfig(gateway: g).label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedGateway = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _merchantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Merchant ID / API Key / شماره کارت بلوبانک',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Payment Gateway'),
                    value: _gwEnabled,
                    onChanged: (v) => setState(() => _gwEnabled = v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        engine.saveGatewayConfig(PaymentGatewayConfig(
                          gateway: _selectedGateway,
                          enabled: _gwEnabled,
                          merchantOrCard: _merchantCtrl.text.trim(),
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Payment gateway settings saved!')),
                        );
                      },
                      child: const Text('Save Gateway'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlanDialog(BuildContext context, VpnEngineService engine) {
    final titleCtrl = TextEditingController();
    final gbCtrl = TextEditingController(text: '20');
    final daysCtrl = TextEditingController(text: '30');
    final priceCtrl = TextEditingController(text: '80000');
    final selectedOutboundIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: DragonColors.charcoal,
          title: const Text('افزودن پکیج حجم و قیمت'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'نام پکیج')),
                const SizedBox(height: 8),
                TextField(
                    controller: gbCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'حجم (GB)')),
                const SizedBox(height: 8),
                TextField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مدت (روز)')),
                const SizedBox(height: 8),
                TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قیمت (تومان)')),
                if (engine.outbounds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('انتخاب اوتباندهای این پکیج (چندتایی):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ...engine.outbounds.map((ob) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ob.name, style: const TextStyle(fontSize: 12)),
                        value: selectedOutboundIds.contains(ob.id),
                        onChanged: (v) {
                          setSt(() {
                            if (v == true) {
                              selectedOutboundIds.add(ob.id);
                            } else {
                              selectedOutboundIds.remove(ob.id);
                            }
                          });
                        },
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            ElevatedButton(
              onPressed: () async {
                await engine.addPlan(VpnPlan(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim().isEmpty
                      ? 'پکیج ویژه'
                      : titleCtrl.text.trim(),
                  volumeGb: double.tryParse(gbCtrl.text) ?? 20,
                  durationDays: int.tryParse(daysCtrl.text) ?? 30,
                  priceTomans: int.tryParse(priceCtrl.text) ?? 80000,
                  outboundIds: selectedOutboundIds.toList(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('ذخیره پکیج'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPanelDialog(BuildContext context, VpnEngineService engine) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    PanelType type = PanelType.threeXUi;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: DragonColors.charcoal,
          title: const Text('Connect New Panel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PanelType>(
                  value: type,
                  items: PanelType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(PanelProfile(
                                    id: '',
                                    name: '',
                                    type: t,
                                    baseUrl: '',
                                    username: '',
                                    password: '')
                                .typeLabel),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSt(() => type = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Panel Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                      labelText: 'URL (e.g. https://panel.domain.com:2053)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await engine.addPanel(PanelProfile(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim().isEmpty
                      ? 'Main Panel'
                      : nameCtrl.text.trim(),
                  type: type,
                  baseUrl: urlCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add Panel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOutboundDialog(BuildContext context, VpnEngineService engine) {
    final nameCtrl = TextEditingController();
    final gbCtrl = TextEditingController(text: '500');
    final rawCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DragonColors.charcoal,
        title: const Text('افزودن کانفیگ اوتباند'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'نام اوتباند (مثلاً آلمان)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gbCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سقف کل حجم مجاز (GB)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rawCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'لینک یا متن کانفیگ اوتباند',
                  hintText: 'vless:// , vmess:// , WireGuard , OpenVPN , JSON',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          ElevatedButton(
            onPressed: () async {
              final ok = await engine.addOutboundPool(
                name: nameCtrl.text,
                rawInput: rawCtrl.text,
                totalGb: double.tryParse(gbCtrl.text) ?? 500,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'اوتباند با موفقیت اضافه شد'
                        : 'فرمت کانفیگ یا حجم نامعتبر است'),
                  ),
                );
              }
            },
            child: const Text('ذخیره اوتباند'),
          ),
        ],
      ),
    );
  }

}
