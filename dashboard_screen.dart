import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';
import '../widgets/ping_chart.dart';
import 'admin_panel_screen.dart';
import 'configs_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'subscriptions_screen.dart';
import 'tickets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _openMenuSheet(BuildContext context, VpnEngineService engine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.84,
        decoration: const BoxDecoration(
          color: DragonColors.oledBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: DragonColors.textSecondary.withOpacity(0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Account Header Card (matching screenshot)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: neumorphicBox(radius: 20),
                    child: Row(
                      children: [
                        const DragonCrestLogo(size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                engine.loggedInUser,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: DragonColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${engine.downloadSpeed} / ${engine.uploadSpeed} Data used',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DragonColors.electricBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Account',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DragonColors.textPrimary)),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.sync_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Refresh',
                    onTap: () {
                      Navigator.pop(ctx);
                      engine.refreshAllSubscriptions();
                      engine.syncOrdersFromServer();
                    },
                  ),
                  _menuTile(
                    icon: Icons.storefront_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Shop',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ShopScreen()));
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Support',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DragonColors.textPrimary)),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.support_agent_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Support & Tickets',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TicketsScreen()));
                    },
                  ),
                  _menuTile(
                    icon: Icons.send_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Telegram channel (@VPNSOPR1)',
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('کانال تلگرام: https://t.me/VPNSOPR1')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Settings',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DragonColors.textPrimary)),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.dns_rounded,
                    color: DragonColors.electricBlue,
                    title: 'DNS Changer & Settings',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()));
                    },
                  ),
                  _menuTile(
                    icon: Icons.rss_feed_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Subscriptions (${engine.subscriptions.length})',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SubscriptionsScreen()));
                    },
                  ),
                  _menuTile(
                    icon: Icons.terminal_rounded,
                    color: DragonColors.electricBlue,
                    title: 'Connection Logs',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LogsScreen()));
                    },
                  ),
                  if (engine.isAdmin)
                    _menuTile(
                      icon: Icons.admin_panel_settings_rounded,
                      color: DragonColors.crimsonRed,
                      title: 'Admin Command Center',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminPanelScreen()));
                      },
                    ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.logout_rounded,
                    color: DragonColors.crimsonRed,
                    title: 'Log out',
                    titleColor: DragonColors.crimsonRed,
                    onTap: () {
                      Navigator.pop(ctx);
                      engine.logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: neumorphicBox(radius: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: titleColor ?? DragonColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: titleColor ?? DragonColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final state = engine.connectionState;
    final active = engine.activeConfig;

    final isConnected = state == VpnConnectionState.connected;
    final isConnecting = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;

    final statusColor = isConnected
        ? DragonColors.emberOrange
        : (isConnecting ? DragonColors.electricBlue : DragonColors.crimsonRed);

    final statusText = isConnected
        ? 'Connected'
        : (isConnecting ? 'Connecting...' : 'Disconnect');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Neumorphic Grid Menu + Purple Shop Pill)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _openMenuSheet(context, engine),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: neumorphicBox(radius: 14),
                      child: const Icon(Icons.grid_view_rounded,
                          color: DragonColors.electricBlue),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A4FFF), Color(0xFF6B35FF)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: DragonColors.electricBlue.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Shop',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Status',
                      style: TextStyle(
                        color: DragonColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => engine.refreshPublicIp(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: neumorphicBox(radius: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConnected
                                  ? Icons.vpn_lock_rounded
                                  : Icons.public_rounded,
                              size: 15,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              engine.isLoadingIp
                                  ? 'در حال دریافت IP...'
                                  : '${isConnected ? 'IP کانفیگ' : 'IP اصلی'}: ${engine.currentPublicIp ?? 'نامشخص'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: DragonColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 4),
                      Text(
                        engine.duration,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: DragonColors.textSecondary,
                        ),
                      ),
                    ],
                    if (engine.quotaWarning != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: DragonColors.crimsonRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          engine.quotaWarning!,
                          style: const TextStyle(
                              color: DragonColors.crimsonRed, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Center 3D Neumorphic Power Button (Matching 21419.jpg)
                    GestureDetector(
                      onTap: engine.toggleConnection,
                      child: Container(
                        width: 184,
                        height: 184,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFDAD5E8),
                              Colors.white.withOpacity(0.95),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.white,
                              offset: Offset(-8, -8),
                              blurRadius: 18,
                            ),
                            BoxShadow(
                              color: DragonColors.shadowDark,
                              offset: Offset(10, 10),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: neumorphicBox(isCircle: true),
                          child: Center(
                            child: isConnecting
                                ? const CircularProgressIndicator(
                                    color: DragonColors.electricBlue)
                                : Icon(
                                    Icons.power_settings_new_rounded,
                                    size: 56,
                                    color: statusColor,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    if (engine.isAdmin && isConnected) ...[
                      const SizedBox(height: 14),
                      _buildAdminCountryBadge(engine),
                    ],

                    const SizedBox(height: 22),

                    // Stats Pill Card (Matching 21419.jpg)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: neumorphicBox(radius: 22),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: engine.refreshAllSubscriptions,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: neumorphicBox(radius: 14),
                              child: engine.isUpdatingSubs
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync_rounded,
                                      color: DragonColors.electricBlue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Download',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DragonColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(engine.downloadSpeed,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: DragonColors.textPrimary)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Upload',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DragonColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(engine.uploadSpeed,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: DragonColors.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Live Ping Chart (Compact)
                    PingChartWidget(
                      samples: engine.pingHistory,
                      avgPing: engine.avgPingMs,
                      jitterMs: engine.jitterMs,
                      isLiveMonitoring: engine.isLivePingEnabled,
                      onToggleMonitor: engine.toggleLivePingMonitor,
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Bottom Smart Server Bar (Matching 21419.jpg)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigsScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: DragonColors.cardSurface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: DragonColors.shadowDark,
                      blurRadius: 14,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const DragonCrestLogo(size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        active != null
                            ? '${active.name} (${active.protocolLabel})'
                            : 'Smart Server',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: DragonColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: DragonColors.electricBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countryCodeToEmoji(String code) {
    final upper = code.toUpperCase();
    if (upper.length != 2) return '🌍';
    return String.fromCharCode(0x1F1E6 + upper.codeUnitAt(0) - 65) +
        String.fromCharCode(0x1F1E6 + upper.codeUnitAt(1) - 65);
  }

  Widget _buildAdminCountryBadge(VpnEngineService engine) {
    final code = engine.connectedCountryCode;
    final country = engine.connectedCountry;
    final city = engine.connectedCity;
    final ip = engine.connectedExitIp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: neumorphicBox(radius: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (engine.isDetectingCountry)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: DragonColors.electricBlue),
            )
          else if (code != null && code.length == 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://flagcdn.com/w80/${code.toLowerCase()}.png',
                width: 34,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  _countryCodeToEmoji(code),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            )
          else
            const Icon(Icons.public_rounded,
                color: DragonColors.electricBlue, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engine.isDetectingCountry
                    ? 'در حال تشخیص کشور متصل...'
                    : (country != null
                        ? '$country${city != null && city.isNotEmpty ? ' • $city' : ''}'
                        : 'کشور نامشخص'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: DragonColors.textPrimary),
              ),
              if (ip != null && ip.isNotEmpty)
                Text(
                  'IP: $ip',
                  style: const TextStyle(
                      fontSize: 10, color: DragonColors.electricBlue),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
