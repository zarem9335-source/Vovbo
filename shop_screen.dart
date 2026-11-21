import 'tickets_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  double _customGb = 20;
  int _customDays = 30;

  void _openReceiptUploadSheet(VpnEngineService engine, VpnPlan plan) {
    if (!engine.canFulfillVolume(plan.volumeGb)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ظرفیت فروش اوتباند تکمیل شده است! امکان خرید این حجم وجود ندارد.')),
      );
      return;
    }
    final gw = engine.gatewayConfig;
    final trackingCtrl = TextEditingController();
    String? pickedPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DragonColors.charcoal,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('پرداخت کارت به کارت • ${plan.title}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DragonColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: DragonColors.electricBlue.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مبلغ قابل واریز: ${plan.priceTomans} تومان',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DragonColors.electricBlue)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              gw.merchantOrCard.isEmpty
                                  ? 'شماره کارت هنوز توسط ادمین ثبت نشده'
                                  : 'شماره کارت: ${gw.merchantOrCard}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (gw.merchantOrCard.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  size: 18, color: DragonColors.electricBlue),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: gw.merchantOrCard));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('شماره کارت کپی شد')),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شماره پیگیری / ۴ رقم آخر کارت (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded,
                      color: DragonColors.electricBlue),
                  label: Text(pickedPath == null
                      ? 'آپلود عکس رسید واریزی'
                      : 'رسید انتخاب شد (${pickedPath!.split('/').last})'),
                  onPressed: () async {
                    final res = await FilePicker.platform
                        .pickFiles(type: FileType.image);
                    if (res != null && res.files.single.path != null) {
                      setSheetState(() => pickedPath = res.files.single.path);
                    }
                  },
                ),
                if (pickedPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(pickedPath!),
                        height: 120, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DragonColors.crimsonRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('ارسال رسید برای تایید ادمین'),
                  onPressed: () async {
                    if (pickedPath == null &&
                        trackingCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'لطفاً عکس رسید یا کد پیگیری را وارد کنید')),
                      );
                      return;
                    }
                    await engine.submitReceiptOrder(
                      plan: plan,
                      receiptImagePath: pickedPath,
                      trackingCode: trackingCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'رسید برای ادمین ارسال شد! پس از تایید، کانفیگ فعال می‌شود.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final gw = engine.gatewayConfig;
    final plans = engine.plans;
    final myOrders = engine.orders;
    final customPrice = (_customGb * gw.pricePerGbTomans).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('فروشگاه و خرید حجم',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'تیکت پشتیبانی',
            icon: const Icon(Icons.support_agent_rounded, color: DragonColors.electricBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TicketsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'بررسی تایید سفارش',
            icon: const Icon(Icons.refresh_rounded, color: DragonColors.electricBlue),
            onPressed: () async {
              await engine.syncOrdersFromServer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('وضعیت سفارش‌ها بروزرسانی شد')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.credit_card_rounded,
                      color: DragonColors.electricBlue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('روش پرداخت: ${gw.label}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          gw.merchantOrCard.isEmpty
                              ? 'شماره کارت توسط ادمین تنظیم می‌شود'
                              : gw.merchantOrCard,
                          style: const TextStyle(
                              fontSize: 13, color: DragonColors.electricBlue),
                        ),
                      ],
                    ),
                  ),
                  if (gw.merchantOrCard.isNotEmpty)
                    IconButton(
                      tooltip: 'کپی شماره کارت',
                      icon: const Icon(Icons.copy_rounded,
                          color: DragonColors.electricBlue, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: gw.merchantOrCard));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('شماره کارت کپی شد')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('انتخاب حجم دلخواه (سفارشی)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_customGb.round()} گیگابایت',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: DragonColors.electricBlue)),
                      Text('$customPrice تومان',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: DragonColors.crimsonRed)),
                    ],
                  ),
                  Slider(
                    value: _customGb,
                    min: 5,
                    max: 200,
                    divisions: 39,
                    activeColor: DragonColors.electricBlue,
                    onChanged: (v) => setState(() => _customGb = v),
                  ),
                  Row(
                    children: [
                      const Text('مدت اعتبار:',
                          style: TextStyle(
                              fontSize: 12, color: DragonColors.textSecondary)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('۳۰ روزه'),
                        selected: _customDays == 30,
                        onSelected: (_) => setState(() => _customDays = 30),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('۶۰ روزه'),
                        selected: _customDays == 60,
                        onSelected: (_) => setState(() => _customDays = 60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DragonColors.crimsonRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text('خرید و آپلود رسید (${_customGb.round()} GB)'),
                      onPressed: () => _openReceiptUploadSheet(
                        engine,
                        VpnPlan(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          title: 'سفارشی ${_customGb.round()} گیگ',
                          volumeGb: _customGb.roundToDouble(),
                          durationDays: _customDays,
                          priceTomans: customPrice,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('پکیج‌های آماده',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...plans.map((pl) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: Icon(Icons.diamond_outlined,
                        color: DragonColors.electricBlue),
                  ),
                  title: Text('${pl.title} (${pl.volumeGb.toStringAsFixed(0)} GB)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${pl.durationDays} روز اعتبار',
                      style: const TextStyle(
                          fontSize: 12, color: DragonColors.textSecondary)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DragonColors.electricBlue,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _openReceiptUploadSheet(engine, pl),
                    child: Text('${pl.priceTomans} T'),
                  ),
                ),
              )),
          if (myOrders.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('وضعیت رسیدهای من',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...myOrders.map((ord) {
              final statusText = ord.status == OrderStatus.approved
                  ? 'تایید و فعال شد'
                  : ord.status == OrderStatus.rejected
                      ? 'رد شد'
                      : 'در انتظار تایید ادمین';
              final statusColor = ord.status == OrderStatus.approved
                  ? DragonColors.electricBlue
                  : ord.status == OrderStatus.rejected
                      ? DragonColors.crimsonRed
                      : DragonColors.emberOrange;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${ord.planTitle} • ${ord.priceTomans} تومان'),
                  subtitle: Text(statusText,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.bold)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
