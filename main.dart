import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/configs_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/vpn_engine_service.dart';
import 'theme/dragon_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final engine = VpnEngineService();
  Future.microtask(() => engine.initialize());
  runApp(
    ChangeNotifierProvider.value(
      value: engine,
      child: const VpnSoprTurboApp(),
    ),
  );
}

class VpnSoprTurboApp extends StatelessWidget {
  const VpnSoprTurboApp({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VPNSOPR Turbo',
      theme: buildDragonTheme(),
      home: engine.isAuthenticated ? const MainShell() : const AuthScreen(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final scaleColor = engine.connectionState == VpnConnectionState.connected
        ? DragonColors.electricBlue
        : DragonColors.crimsonRed;

    final pages = <Widget>[
      const DashboardScreen(),
      const ShopScreen(),
      const ConfigsScreen(),
      const SubscriptionsScreen(),
      const LogsScreen(),
      const SettingsScreen(),
      if (engine.isAdmin) const AdminPanelScreen(),
    ];

    final safeIndex = _index >= pages.length ? 0 : _index;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DragonScalePainter(accentColor: scaleColor),
            ),
          ),
          IndexedStack(index: safeIndex, children: pages),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: DragonColors.charcoal,
        indicatorColor: DragonColors.electricBlue.withOpacity(0.18),
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: DragonColors.electricBlue),
            label: 'Core',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag, color: DragonColors.crimsonRed),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns, color: DragonColors.electricBlue),
            label: 'Configs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.rss_feed_outlined),
            selectedIcon:
                Icon(Icons.rss_feed, color: DragonColors.electricBlue),
            label: 'Subs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon:
                Icon(Icons.terminal, color: DragonColors.electricBlue),
            label: 'Logs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings, color: DragonColors.electricBlue),
            label: 'DNS',
          ),
          if (engine.isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings,
                  color: DragonColors.crimsonRed),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
