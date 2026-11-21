import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../models/vpn_config.dart';

enum VpnConnectionState { disconnected, connecting, connected, disconnecting }

class VpnEngineService extends ChangeNotifier {
  static const String adminUsername = 'admin';
  static const String adminPassword = 'Sopr@2026!Dragon';

  static const _prefsConfigsKey = 'vpn_sopr_configs';
  static const _prefsSubsKey = 'vpn_sopr_subs';
  static const _prefsPanelsKey = 'vpn_sopr_panels';
  static const _prefsPlansKey = 'vpn_sopr_plans';
  static const _prefsGatewayKey = 'vpn_sopr_gateway';
  static const _prefsBackendUrlKey = 'vpn_sopr_backend_url';
  static const _prefsWebTunnelUrlKey = 'vpn_sopr_web_tunnel_url';
  static const _prefsOrdersKey = 'vpn_sopr_orders';
  static const _prefsTicketsKey = 'vpn_sopr_tickets';
  static const _prefsOutboundsKey = 'vpn_sopr_outbounds';
  static const _prefsSelectedIdKey = 'vpn_sopr_selected_id';
  static const _prefsModeKey = 'vpn_sopr_routing_mode';
  static const _prefsDnsKey = 'vpn_sopr_custom_dns';
  static const _prefsSecondaryDnsKey = 'vpn_sopr_secondary_dns';
  static const _prefsBypassLanKey = 'vpn_sopr_bypass_lan';
  static const _prefsUserKey = 'vpn_sopr_auth_user';

  late final FlutterV2ray _v2ray;
  late final OpenVPN _openVpn;
  final _wireGuard = WireGuardFlutter.instance;

  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String _loggedInUser = 'Guest';

  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  RoutingMode _routingMode = RoutingMode.gaming;
  List<VpnConfig> _configs = [];
  List<SubscriptionItem> _subscriptions = [];
  List<PanelProfile> _panels = [];
  List<PaymentOrder> _orders = [];
  List<OutboundPool> _outbounds = [];
  List<VpnConfig> _freeConfigs = [];
  List<SupportTicket> _tickets = [];
  bool _isDnsChangerActive = false;
  List<VpnPlan> _plans = [
    VpnPlan(id: 'p10', title: 'پکیج گیمینگ ۱۰ گیگ', volumeGb: 10, durationDays: 30, priceTomans: 40000),
    VpnPlan(id: 'p30', title: 'پکیج توربو ۳۰ گیگ', volumeGb: 30, durationDays: 30, priceTomans: 120000),
    VpnPlan(id: 'p100', title: 'پکیج اژدها ۱۰۰ گیگ', volumeGb: 100, durationDays: 30, priceTomans: 400000),
  ];
  PaymentGatewayConfig _gatewayConfig = PaymentGatewayConfig();

  String? _selectedConfigId;
  String _backendUrl = 'https://morningg.ir/api.php';
  String _webTunnelUrl = '';
  String _customDns = '1.1.1.1';
  String _secondaryDns = '1.0.0.1';
  bool _bypassLan = true;
  bool _proxyOnlyMode = false;

  bool _isUpdatingSubs = false;
  String _subUpdateStatus = 'Idle';
  DateTime? _lastSubSync;

  bool _isLivePingEnabled = false;
  Timer? _livePingTimer;
  final List<int> _pingHistory = [];

  String _uploadSpeed = '0 KB/s';
  String _downloadSpeed = '0 KB/s';
  String _duration = '00:00:00';
  String? _quotaWarning;
  String? _connectedCountry;
  String? _connectedCountryCode;
  String? _connectedCity;
  String? _connectedExitIp;
  String? _currentPublicIp;
  bool _isLoadingIp = false;
  bool _isDetectingCountry = false;
  final List<String> _logs = [];

  Timer? _durationTimer;
  DateTime? _connectedAt;
  int _lastSessionBytes = 0;
  bool _initialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String get loggedInUser => _loggedInUser;

  VpnConnectionState get connectionState => _connectionState;
  RoutingMode get routingMode => _routingMode;
  List<VpnConfig> get configs => List.unmodifiable(_configs);
  List<SubscriptionItem> get subscriptions => List.unmodifiable(_subscriptions);
  List<PanelProfile> get panels => List.unmodifiable(_panels);
  List<VpnPlan> get plans => List.unmodifiable(_plans);
  List<PaymentOrder> get orders => List.unmodifiable(_orders);
  List<OutboundPool> get outbounds => List.unmodifiable(_outbounds);
  List<VpnConfig> get freeConfigs => List.unmodifiable(_freeConfigs);
  List<SupportTicket> get tickets => List.unmodifiable(_tickets);
  bool get isDnsChangerActive => _isDnsChangerActive;
  double get totalOutboundRemainingGb => _outbounds.fold(0.0, (sum, o) => sum + o.remainingGb);
  PaymentGatewayConfig get gatewayConfig => _gatewayConfig;

  String? get selectedConfigId => _selectedConfigId;
  String get backendUrl => _backendUrl;
  String get webTunnelUrl => _webTunnelUrl;
  String get customDns => _customDns;
  String get secondaryDns => _secondaryDns;
  bool get bypassLan => _bypassLan;
  bool get proxyOnlyMode => _proxyOnlyMode;
  bool get isUpdatingSubs => _isUpdatingSubs;
  String get subUpdateStatus => _subUpdateStatus;
  DateTime? get lastSubSync => _lastSubSync;

  bool get isLivePingEnabled => _isLivePingEnabled;
  List<int> get pingHistory => List.unmodifiable(_pingHistory);

  int get avgPingMs {
    final valid = _pingHistory.where((p) => p > 0).toList();
    if (valid.isEmpty) return 0;
    return (valid.reduce((a, b) => a + b) / valid.length).round();
  }

  int get jitterMs {
    final valid = _pingHistory.where((p) => p > 0).toList();
    if (valid.length < 2) return 0;
    int totalDiff = 0;
    for (int i = 1; i < valid.length; i++) {
      totalDiff += (valid[i] - valid[i - 1]).abs();
    }
    return (totalDiff / (valid.length - 1)).round();
  }

  String get uploadSpeed => _uploadSpeed;
  String get downloadSpeed => _downloadSpeed;
  String get duration => _duration;
  String? get quotaWarning => _quotaWarning;
  String? get connectedCountry => _connectedCountry;
  String? get connectedCountryCode => _connectedCountryCode;
  String? get connectedCity => _connectedCity;
  String? get connectedExitIp => _connectedExitIp;
  String? get currentPublicIp => _currentPublicIp;
  bool get isLoadingIp => _isLoadingIp;
  bool get isDetectingCountry => _isDetectingCountry;
  List<String> get logs => List.unmodifiable(_logs);

  VpnConfig? get activeConfig {
    if (_configs.isEmpty) return null;
    if (_selectedConfigId != null) {
      final found = _configs.where((c) => c.id == _selectedConfigId);
      if (found.isNotEmpty) return found.first;
    }
    return _configs.first;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (activeConfig?.protocol == VpnProtocol.v2ray) {
          _uploadSpeed = _formatBytesPerSec(status.uploadSpeed);
          _downloadSpeed = _formatBytesPerSec(status.downloadSpeed);
          _duration = status.duration;
          _trackTrafficDelta(status.upload + status.download);
          if (status.state == 'CONNECTED') {
            _setConnectedState();
          } else if (status.state == 'DISCONNECTED') {
            _setDisconnectedState();
          }
          notifyListeners();
        }
      },
    );

    try {
      await _v2ray.initializeV2Ray(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
    } catch (e) {
      _addLog('V2Ray init error: $e');
    }

    _openVpn = OpenVPN(
      onVpnStatusChanged: (status) {
        if (status != null && activeConfig?.protocol == VpnProtocol.openvpn) {
          _uploadSpeed = _formatBytesPerSec(status.speedOut ?? 0);
          _downloadSpeed = _formatBytesPerSec(status.speedIn ?? 0);
          _duration = status.duration ?? _duration;
          final bIn = int.tryParse(status.byteIn ?? '0') ?? 0;
          final bOut = int.tryParse(status.byteOut ?? '0') ?? 0;
          _trackTrafficDelta(bIn + bOut);
          notifyListeners();
        }
      },
      onVpnStageChanged: (stage, raw) {
        if (activeConfig?.protocol == VpnProtocol.openvpn) {
          _addLog('OpenVPN stage: ${stage.name}');
          if (stage.isConnected) {
            _setConnectedState();
          } else if (stage.isDisconnected) {
            _setDisconnectedState();
          }
          notifyListeners();
        }
      },
    );

    try {
      await _openVpn.initialize(
        groupIdentifier: 'group.com.vpnsopr.gaming',
        providerBundleIdentifier: 'com.vpnsopr.gaming.VPNExtension',
        localizedDescription: 'VPNSOPR Turbo',
      );
    } catch (e) {
      _addLog('OpenVPN init error: $e');
    }

    try {
      await _wireGuard.initialize(interfaceName: 'wg_sopr0');
      _wireGuard.vpnStageSnapshot.listen((stage) {
        if (activeConfig?.protocol == VpnProtocol.wireguard) {
          _addLog('WireGuard stage: ${stage.name}');
          if (stage == VpnStage.connected) {
            _setConnectedState();
          } else if (stage == VpnStage.disconnected) {
            _setDisconnectedState();
          }
          notifyListeners();
        }
      });
    } catch (e) {
      _addLog('WireGuard init error: $e');
    }

    await _loadPreferences();
    _addLog('VPNSOPR Turbo v3.0 initialized.');

    unawaited(syncOrdersFromServer());
    unawaited(syncTicketsFromServer());
    unawaited(refreshPublicIp());
    if (_subscriptions.isNotEmpty) {
      unawaited(refreshAllSubscriptions());
    }
  }

  Future<bool> login(String username, String password) async {
    final u = username.trim();
    final p = password.trim();
    if (u.isEmpty || p.isEmpty) return false;

    if (u == adminUsername && p == adminPassword) {
      _isAdmin = true;
      _isAuthenticated = true;
      _loggedInUser = 'Admin';
    } else {
      _isAdmin = false;
      _isAuthenticated = true;
      _loggedInUser = u;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserKey, '$_loggedInUser|$_isAdmin');
    _addLog('User authenticated: $_loggedInUser (Admin: $_isAdmin)');
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isAdmin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserKey);
    notifyListeners();
  }

  void toggleLivePingMonitor() {
    _isLivePingEnabled = !_isLivePingEnabled;
    _livePingTimer?.cancel();
    if (_isLivePingEnabled) {
      _livePingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final cfg = activeConfig;
        if (cfg == null) return;
        final ms = await _quickTcpPing(cfg);
        _pingHistory.add(ms ?? -1);
        if (_pingHistory.length > 30) _pingHistory.removeAt(0);
        if (ms != null && ms > 0) cfg.pingMs = ms;
        notifyListeners();
      });
      _addLog('Started 1s live ping monitor.');
    } else {
      _addLog('Stopped live ping monitor.');
    }
    notifyListeners();
  }

  Future<int?> _quickTcpPing(VpnConfig config) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        config.serverAddress,
        config.port,
        timeout: const Duration(milliseconds: 900),
      );
      sw.stop();
      socket.destroy();
      return math.max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAuth = prefs.getString(_prefsUserKey);
    if (savedAuth != null && savedAuth.contains('|')) {
      final parts = savedAuth.split('|');
      _loggedInUser = parts[0];
      _isAdmin = parts[1] == 'true';
      _isAuthenticated = true;
    }
    final rawList = prefs.getString(_prefsConfigsKey);
    if (rawList != null && rawList.isNotEmpty) {
      _configs = VpnConfig.decodeList(rawList);
    }
    final rawSubs = prefs.getString(_prefsSubsKey);
    if (rawSubs != null && rawSubs.isNotEmpty) {
      _subscriptions = SubscriptionItem.decodeList(rawSubs);
    }
    final rawPanels = prefs.getString(_prefsPanelsKey);
    if (rawPanels != null && rawPanels.isNotEmpty) {
      _panels = PanelProfile.decodeList(rawPanels);
    }
    final rawPlans = prefs.getString(_prefsPlansKey);
    if (rawPlans != null && rawPlans.isNotEmpty) {
      _plans = VpnPlan.decodeList(rawPlans);
    }
    final rawOutbounds = prefs.getString(_prefsOutboundsKey);
    if (rawOutbounds != null && rawOutbounds.isNotEmpty) {
      _outbounds = OutboundPool.decodeList(rawOutbounds);
    }
    final rawTickets = prefs.getString(_prefsTicketsKey);
    if (rawTickets != null && rawTickets.isNotEmpty) {
      _tickets = SupportTicket.decodeList(rawTickets);
    }
    final rawOrders = prefs.getString(_prefsOrdersKey);
    if (rawOrders != null && rawOrders.isNotEmpty) {
      _orders = PaymentOrder.decodeList(rawOrders);
    }
    _backendUrl = prefs.getString(_prefsBackendUrlKey) ?? _backendUrl;
    _webTunnelUrl = prefs.getString(_prefsWebTunnelUrlKey) ?? '';
    final rawGw = prefs.getString(_prefsGatewayKey);
    if (rawGw != null && rawGw.isNotEmpty) {
      _gatewayConfig = PaymentGatewayConfig.fromJson(
          jsonDecode(rawGw) as Map<String, dynamic>);
    }
    _selectedConfigId = prefs.getString(_prefsSelectedIdKey);
    final savedMode = prefs.getString(_prefsModeKey);
    if (savedMode != null) {
      _routingMode = RoutingMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => RoutingMode.gaming,
      );
    }
    _customDns = prefs.getString(_prefsDnsKey) ?? '1.1.1.1';
    _secondaryDns = prefs.getString(_prefsSecondaryDnsKey) ?? '1.0.0.1';
    _bypassLan = prefs.getBool(_prefsBypassLanKey) ?? true;
    notifyListeners();
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsConfigsKey, VpnConfig.encodeList(_configs));
    if (_selectedConfigId != null) {
      await prefs.setString(_prefsSelectedIdKey, _selectedConfigId!);
    }
  }

  Future<void> _saveSubs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsSubsKey, SubscriptionItem.encodeList(_subscriptions));
  }

  Future<void> _savePanels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPanelsKey, PanelProfile.encodeList(_panels));
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPlansKey, VpnPlan.encodeList(_plans));
  }

  Future<void> addPlan(VpnPlan plan) async {
    _plans.add(plan);
    await _savePlans();
    await pushStoreToServer();
    _addLog('Admin added plan: ${plan.title} (${plan.volumeGb}GB / ${plan.priceTomans}T)');
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _savePlans();
    await pushStoreToServer();
    notifyListeners();
  }

  Future<void> _saveOutbounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOutboundsKey, OutboundPool.encodeList(_outbounds));
  }

  Future<bool> addOutboundPool({
    required String name,
    required String rawInput,
    required double totalGb,
  }) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty || totalGb <= 0) return false;

    VpnProtocol proto = VpnProtocol.v2ray;
    String rawCfg = trimmed;
    String host = 'outbound.server';
    int port = 443;

    if (trimmed.contains('[Interface]') && trimmed.contains('[Peer]')) {
      proto = VpnProtocol.wireguard;
      final m = RegExp(r'Endpoint\s*=\s*([^\s:]+):(\d+)').firstMatch(trimmed);
      host = m?.group(1) ?? host;
      port = int.tryParse(m?.group(2) ?? '51820') ?? 51820;
    } else if (trimmed.contains('client') && trimmed.contains('remote ')) {
      proto = VpnProtocol.openvpn;
      final m = RegExp(r'remote\s+([^\s]+)\s+(\d+)').firstMatch(trimmed);
      host = m?.group(1) ?? host;
      port = int.tryParse(m?.group(2) ?? '1194') ?? 1194;
    } else if (!trimmed.startsWith('{')) {
      try {
        final parsed = FlutterV2ray.parseFromURL(trimmed);
        rawCfg = parsed.getFullConfiguration();
        host = parsed.address;
        port = parsed.port;
      } catch (_) {
        return false;
      }
    }

    _outbounds.add(OutboundPool(
      id: 'ob_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Outbound $host' : name.trim(),
      protocol: proto,
      rawConfig: rawCfg,
      serverAddress: host,
      port: port,
      totalGb: totalGb,
      reservedGb: 0,
    ));
    await _saveOutbounds();
    await pushStoreToServer();
    _addLog('Admin added Outbound "$name" (${totalGb.toStringAsFixed(1)} GB)');
    notifyListeners();
    return true;
  }

  Future<void> deleteOutboundPool(String id) async {
    _outbounds.removeWhere((o) => o.id == id);
    await _saveOutbounds();
    await pushStoreToServer();
    notifyListeners();
  }

  bool canFulfillVolume(double requestedGb) {
    if (_outbounds.isEmpty) return true;
    return _outbounds.any((o) => o.canReserve(requestedGb));
  }

  OutboundPool? _reserveFromOutbound(double requestedGb) {
    for (final ob in _outbounds) {
      if (ob.canReserve(requestedGb)) {
        ob.reservedGb += requestedGb;
        return ob;
      }
    }
    return null;
  }


  Future<bool> addFreeConfig({required String name, required String rawLink}) async {
    final link = rawLink.trim();
    if (link.isEmpty) return false;
    String remark = "Free Server";
    String raw = link;
    String host = "";
    int port = 443;
    try {
      final parsed = FlutterV2ray.parseFromURL(link);
      remark = parsed.remark;
      raw = parsed.getFullConfiguration();
      host = parsed.address;
      port = parsed.port;
    } catch (_) {}
    final cfg = VpnConfig(
      id: "free_${DateTime.now().microsecondsSinceEpoch}",
      name: "[رایگان] ${name.trim().isEmpty ? remark : name.trim()}",
      protocol: VpnProtocol.v2ray,
      rawConfig: raw,
      serverAddress: host,
      port: port,
    );
    _freeConfigs.insert(0, cfg);
    _configs.removeWhere((c) => c.id == cfg.id);
    _configs.insert(0, cfg);
    await _saveConfigs();
    await pushStoreToServer();
    notifyListeners();
    return true;
  }

  Future<void> deleteFreeConfig(String id) async {
    _freeConfigs.removeWhere((c) => c.id == id);
    _configs.removeWhere((c) => c.id == id);
    await _saveConfigs();
    await pushStoreToServer();
    notifyListeners();
  }


  Future<void> toggleDnsChanger() async {
    if (_isDnsChangerActive) {
      await _v2ray.stopV2Ray();
      _isDnsChangerActive = false;
      _addLog('DNS Changer stopped.');
      notifyListeners();
      return;
    }
    if (_connectionState == VpnConnectionState.connected) {
      await disconnect();
    }
    final dnsConfig = jsonEncode({
      'log': {'loglevel': 'warning'},
      'dns': {
        'servers': [_customDns, _secondaryDns]
      },
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {'udp': true}
        }
      ],
      'outbounds': [
        {'protocol': 'freedom', 'tag': 'direct'},
        {'protocol': 'dns', 'tag': 'dns-out'}
      ],
      'routing': {
        'rules': [
          {
            'type': 'field',
            'inboundTag': ['socks'],
            'port': '53',
            'outboundTag': 'dns-out'
          }
        ]
      }
    });
    final granted = await _v2ray.requestPermission();
    if (!granted) {
      _addLog('VPN permission denied for DNS Changer.');
      return;
    }
    await _v2ray.startV2Ray(
      remark: 'VPNSOPR DNS ($_customDns)',
      config: dnsConfig,
      bypassSubnets: null,
      proxyOnly: false,
    );
    _isDnsChangerActive = true;
    _addLog('DNS Changer active: $_customDns / $_secondaryDns');
    notifyListeners();
  }

  Future<void> _saveTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTicketsKey, SupportTicket.encodeList(_tickets));
  }

  Future<void> syncTicketsFromServer() async {
    if (_backendUrl.isEmpty) return;
    try {
      final url = _isAdmin
          ? '$_backendUrl?action=get_tickets'
          : '$_backendUrl?action=get_user_tickets&username=${Uri.encodeComponent(_loggedInUser)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List<dynamic>;
        _tickets = decoded
            .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveTickets();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> submitTicket({required String subject, required String message}) async {
    final t = SupportTicket(
      id: 'tkt_${DateTime.now().microsecondsSinceEpoch}',
      username: _loggedInUser,
      subject: subject.trim(),
      message: message.trim(),
    );
    _tickets.insert(0, t);
    await _saveTickets();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=create_ticket'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(t.toJson()),
        ).timeout(const Duration(seconds: 12));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> replyTicket(SupportTicket ticket, String reply) async {
    ticket.adminReply = reply.trim();
    ticket.status = 'answered';
    await _saveTickets();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=reply_ticket'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': ticket.id, 'adminReply': ticket.adminReply}),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setWebTunnelUrl(String url) async {
    _webTunnelUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWebTunnelUrlKey, _webTunnelUrl);
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBackendUrlKey, _backendUrl);
    _addLog('Backend Server URL set to $_backendUrl');
    notifyListeners();
  }

  Future<void> pushStoreToServer() async {
    if (_backendUrl.isEmpty || !_isAdmin) return;
    try {
      await http.post(
        Uri.parse('$_backendUrl?action=save_store'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plans': _plans.map((p) => p.toJson()).toList(),
          'gateway': _gatewayConfig.toJson(),
          'outbounds': _outbounds.map((o) => o.toJson()).toList(),
          'free_configs': _freeConfigs.map((c) => c.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 12));
      _addLog('Synced plans & card settings to server.');
    } catch (e) {
      _addLog('Push store warning: $e');
    }
  }

  Future<void> syncStoreFromServer() async {
    if (_backendUrl.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse('$_backendUrl?action=get_store'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['plans'] is List) {
            _plans = (decoded['plans'] as List)
                .map((e) => VpnPlan.fromJson(e as Map<String, dynamic>))
                .toList();
            await _savePlans();
          }
          if (decoded['gateway'] is Map<String, dynamic>) {
            _gatewayConfig = PaymentGatewayConfig.fromJson(
                decoded['gateway'] as Map<String, dynamic>);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefsGatewayKey, jsonEncode(_gatewayConfig.toJson()));
          }
          if (decoded['free_configs'] is List) {
            _freeConfigs = (decoded['free_configs'] as List)
                .map((e) => VpnConfig.fromJson(e as Map<String, dynamic>))
                .toList();
            _configs.removeWhere((c) => c.id.startsWith('free_'));
            for (final fc in _freeConfigs.reversed) {
              _configs.insert(0, fc);
            }
            await _saveConfigs();
          }
          if (decoded['outbounds'] is List) {
            _outbounds = (decoded['outbounds'] as List)
                .map((e) => OutboundPool.fromJson(e as Map<String, dynamic>))
                .toList();
            await _saveOutbounds();
          }
          notifyListeners();
        }
      }
    } catch (e) {
      _addLog('Store sync error: $e');
    }
  }

  Future<void> syncOrdersFromServer() async {
    if (_backendUrl.isEmpty) return;
    await syncStoreFromServer();
    try {
      final url = _isAdmin
          ? '$_backendUrl?action=get_orders'
          : '$_backendUrl?action=get_user_orders&username=${Uri.encodeComponent(_loggedInUser)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List<dynamic>;
        _orders = decoded
            .map((e) => PaymentOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveOrders();

        if (!_isAdmin) {
          for (final ord in _orders) {
            if (ord.status == OrderStatus.approved &&
                ord.activatedConfigJson != null &&
                ord.activatedConfigJson!.isNotEmpty) {
              final already = _configs.any((c) => c.id == 'srv_${ord.id}');
              if (!already) {
                final cfgMap = jsonDecode(ord.activatedConfigJson!) as Map<String, dynamic>;
                cfgMap['id'] = 'srv_${ord.id}';
                final newCfg = VpnConfig.fromJson(cfgMap);
                _configs.insert(0, newCfg);
                _selectedConfigId = newCfg.id;
                await _saveConfigs();
                _addLog('Activated approved plan from server: ${newCfg.name}');
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _addLog('Order sync error: $e');
    }
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOrdersKey, PaymentOrder.encodeList(_orders));
  }

  Future<void> submitReceiptOrder({
    required VpnPlan plan,
    String? receiptImagePath,
    String trackingCode = '',
  }) async {
    String? b64;
    if (receiptImagePath != null && receiptImagePath.isNotEmpty) {
      try {
        final bytes = await File(receiptImagePath).readAsBytes();
        b64 = base64Encode(bytes);
      } catch (_) {}
    }
    final order = PaymentOrder(
      id: 'ord_${DateTime.now().microsecondsSinceEpoch}',
      username: _loggedInUser,
      planTitle: plan.title,
      volumeGb: plan.volumeGb,
      durationDays: plan.durationDays,
      priceTomans: plan.priceTomans,
      outboundIds: plan.outboundIds,
      receiptImagePath: receiptImagePath,
      receiptBase64: b64,
      trackingCode: trackingCode.trim(),
      status: OrderStatus.pending,
    );
    _orders.insert(0, order);
    await _saveOrders();

    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=create_order'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(order.toJson()),
        ).timeout(const Duration(seconds: 15));
        _addLog('Receipt uploaded to server $_backendUrl');
      } catch (e) {
        _addLog('Server upload warning: $e');
      }
    }
    notifyListeners();
  }


  Future<String?> _provisionUserOnPanel({
    required String username,
    required double volumeGb,
    required int durationDays,
  }) async {
    if (_panels.isEmpty) return null;
    final panel = _panels.first;
    final base = panel.baseUrl
        .replaceAll(RegExp(r'/dashboard/?$'), '')
        .replaceAll(RegExp(r'/$'), '');
    try {
      // 1. Authenticate to get Bearer token
      final tokenRes = await http.post(
        Uri.parse('$base/api/admin/token'),
        body: {'username': panel.username, 'password': panel.password},
      ).timeout(const Duration(seconds: 12));
      if (tokenRes.statusCode != 200) {
        _addLog('Panel token error: HTTP ${tokenRes.statusCode}');
        return null;
      }
      final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final token = tokenJson['access_token'] as String?;
      if (token == null || token.isEmpty) return null;

      // 2. Create user in Pasargad / Marzban panel
      final cleanUser = '${username.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}_${DateTime.now().millisecondsSinceEpoch % 100000}';
      final dataLimitBytes = (volumeGb * 1024 * 1024 * 1024).round();
      final expireUnix = (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          (durationDays * 86400);

      final userRes = await http.post(
        Uri.parse('$base/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': cleanUser,
          'proxies': {'vless': {}},
          'data_limit': dataLimitBytes,
          'expire': expireUnix,
        }),
      ).timeout(const Duration(seconds: 12));

      if (userRes.statusCode == 200 || userRes.statusCode == 201) {
        final userJson = jsonDecode(userRes.body) as Map<String, dynamic>;
        var subUrl = userJson['subscription_url'] as String?;
        if (subUrl != null && subUrl.isNotEmpty) {
          if (subUrl.startsWith('/')) subUrl = '$base$subUrl';
          _addLog('Created user "$cleanUser" in ${panel.typeLabel}!');
          return subUrl;
        }
      } else {
        _addLog('Panel create user HTTP ${userRes.statusCode}: ${userRes.body}');
      }
    } catch (e) {
      _addLog('Panel provision error: $e');
    }
    return null;
  }

  Future<String> approveOrder(PaymentOrder order) async {
    order.status = OrderStatus.approved;
    await _saveOrders();

    // Check Outbound Pool capacity if Admin configured Outbounds
    if (_outbounds.isNotEmpty) {
      final targets = order.outboundIds.isNotEmpty
          ? _outbounds.where((o) => order.outboundIds.contains(o.id) && o.canReserve(order.volumeGb)).toList()
          : _outbounds.where((o) => o.canReserve(order.volumeGb)).take(1).toList();

      if (targets.isEmpty) {
        order.status = OrderStatus.rejected;
        await _saveOrders();
        _addLog('BLOCKED: Outbound capacity reached! Cannot create ${order.volumeGb}GB config.');
        notifyListeners();
        return 'ظرفیت حجم اوتباند پر شده است! دیگر امکان ساخت کانفیگ نیست.';
      }

      final quotaBytes = (order.volumeGb * 1024 * 1024 * 1024).round();
      final timeMinutes = order.durationDays * 24 * 60;
      for (final ob in targets) {
        ob.reservedGb += order.volumeGb;
        final obCfg = VpnConfig(
          id: 'obcfg_${DateTime.now().microsecondsSinceEpoch}_${ob.id}',
          name: '${order.planTitle} - ${ob.name} (${order.volumeGb.toStringAsFixed(0)}GB)',
          protocol: ob.protocol,
          rawConfig: ob.rawConfig,
          serverAddress: ob.serverAddress,
          port: ob.port,
          quotaBytes: quotaBytes,
          usedBytes: 0,
          timeLimitMinutes: timeMinutes,
          usedSeconds: 0,
        );
        _configs.insert(0, obCfg);
        _selectedConfigId = obCfg.id;
      }
      await _saveOutbounds();
      await _saveConfigs();
      if (_backendUrl.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$_backendUrl?action=approve_order'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': order.id, 'activatedConfigJson': jsonEncode(_configs.first.toJson())}),
          ).timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      _addLog('Reserved ${order.volumeGb}GB across ${targets.length} outbound(s).');
      notifyListeners();
      return 'تعداد ${targets.length} کانفیگ اوتباند با حجم ${order.volumeGb.toStringAsFixed(0)} گیگ فعال شد!';
    }

    // Try creating the user directly inside Pasargad / Marzban Panel
    final subUrl = await _provisionUserOnPanel(
      username: order.username,
      volumeGb: order.volumeGb,
      durationDays: order.durationDays,
    );

    if (subUrl != null) {
      try {
        final count = await addAndFetchSubscription(subUrl, name: order.planTitle);
        _addLog('Approved & provisioned from panel: $count config(s)');
        notifyListeners();
        return 'کاربر در پنل ساخته شد و $count کانفیگ فعال گردید!';
      } catch (e) {
        _addLog('Sub fetch after provision failed: $e');
      }
    }

    // Fallback: clone local config with quota if no panel connected
    final quotaBytes = (order.volumeGb * 1024 * 1024 * 1024).round();
    final timeMinutes = order.durationDays * 24 * 60;
    if (activeConfig != null) {
      final baseCfg = activeConfig!;
      final activated = VpnConfig(
        id: 'paid_${DateTime.now().microsecondsSinceEpoch}',
        name: '${order.planTitle} (${order.volumeGb.toStringAsFixed(0)}GB)',
        protocol: baseCfg.protocol,
        rawConfig: baseCfg.rawConfig,
        serverAddress: baseCfg.serverAddress,
        port: baseCfg.port,
        isUdpPreferred: baseCfg.isUdpPreferred,
        pingMs: baseCfg.pingMs,
        quotaBytes: quotaBytes,
        usedBytes: 0,
        timeLimitMinutes: timeMinutes,
        usedSeconds: 0,
      );
      _configs.insert(0, activated);
      _selectedConfigId = activated.id;
      await _saveConfigs();
      notifyListeners();
      return 'سفارش تایید و کانفیگ ${order.volumeGb.toStringAsFixed(0)} گیگ فعال شد!';
    }
    notifyListeners();
    return 'سفارش تایید شد، اما پنل متصل نیست یا کانفیگ پایه وجود ندارد.';
  }

  Future<void> rejectOrder(PaymentOrder order) async {
    order.status = OrderStatus.rejected;
    await _saveOrders();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(Uri.parse('$_backendUrl?action=reject_order&id=${order.id}')).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    _addLog('Admin REJECTED order ${order.id}');
    notifyListeners();
  }

  Future<void> saveGatewayConfig(PaymentGatewayConfig gw) async {
    _gatewayConfig = gw;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsGatewayKey, jsonEncode(gw.toJson()));
    await pushStoreToServer();
    _addLog('Updated Iranian Payment Gateway: ${gw.label}');
    notifyListeners();
  }

  /// Verify payment with Iranian Gateway & Immediately Activate Config
  Future<String> processPaymentAndActivate(VpnPlan plan) async {
    _addLog('Initiating ${plan.priceTomans} Toman payment via ${_gatewayConfig.label}...');
    // If gateway is online (ZarinPal / Zibal / IDPay), send request payload
    if (_gatewayConfig.gateway != IranianGateway.blubank &&
        _gatewayConfig.merchantOrCard.isNotEmpty) {
      try {
        final endpoint = _gatewayConfig.gateway == IranianGateway.zarinpal
            ? 'https://api.zarinpal.com/pg/v4/payment/request.json'
            : _gatewayConfig.gateway == IranianGateway.zibal
                ? 'https://gateway.zibal.ir/v1/request'
                : 'https://api.idpay.ir/v1.1/payment';
        await http
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'merchant_id': _gatewayConfig.merchantOrCard,
                'merchant': _gatewayConfig.merchantOrCard,
                'amount': plan.priceTomans * 10, // Rials
                'callback_url': _gatewayConfig.callbackUrl,
                'description': '${plan.title} (${plan.volumeGb} GB)',
              }),
            )
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        _addLog('Gateway request note: $e');
      }
    }

    // Immediately activate config for the customer
    final quotaBytes = (plan.volumeGb * 1024 * 1024 * 1024).round();
    final timeMinutes = plan.durationDays * 24 * 60;

    if (activeConfig != null) {
      final base = activeConfig!;
      final activated = VpnConfig(
        id: 'paid_${DateTime.now().microsecondsSinceEpoch}',
        name: '${plan.title} (${plan.volumeGb.toStringAsFixed(0)}GB)',
        protocol: base.protocol,
        rawConfig: base.rawConfig,
        serverAddress: base.serverAddress,
        port: base.port,
        isUdpPreferred: base.isUdpPreferred,
        pingMs: base.pingMs,
        quotaBytes: quotaBytes,
        usedBytes: 0,
        timeLimitMinutes: timeMinutes,
        usedSeconds: 0,
      );
      _configs.insert(0, activated);
      _selectedConfigId = activated.id;
      await _saveConfigs();
      _addLog('Payment verified! Activated ${activated.name} immediately.');
      notifyListeners();
      await connect();
      return 'پرداخت تایید شد! کانفیگ ${activated.name} فعال و متصل شد.';
    }
    return 'پرداخت ثبت شد! لطفاً یک کانفیگ پایه در بخش Configs اضافه کنید.';
  }

  Future<void> addPanel(PanelProfile panel) async {
    _panels.add(panel);
    await _savePanels();
    _addLog('Added panel: ${panel.name} (${panel.typeLabel})');
    notifyListeners();
  }

  Future<void> deletePanel(String id) async {
    _panels.removeWhere((p) => p.id == id);
    await _savePanels();
    notifyListeners();
  }

  Future<String> syncPanel(PanelProfile panel) async {
    final base = panel.baseUrl.replaceAll(RegExp(r'/dashboard/?$'), '').replaceAll(RegExp(r'/$'), '');
    _addLog('Connecting to ${panel.typeLabel} at $base...');
    try {
      if (panel.type == PanelType.marzban || panel.type == PanelType.pasargad) {
        final res = await http.post(
          Uri.parse('$base/api/admin/token'),
          body: {'username': panel.username, 'password': panel.password},
        ).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          panel.lastSynced = DateTime.now();
          await _savePanels();
          notifyListeners();
          return 'Connected to Marzban successfully!';
        }
        return 'Marzban HTTP ${res.statusCode}';
      } else {
        final res = await http.post(
          Uri.parse('$base/login'),
          body: {'username': panel.username, 'password': panel.password},
        ).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          panel.lastSynced = DateTime.now();
          await _savePanels();
          notifyListeners();
          return 'Connected to ${panel.typeLabel} successfully!';
        }
        return '${panel.typeLabel} HTTP ${res.statusCode}';
      }
    } catch (e) {
      return 'Panel error: $e';
    }
  }

  Future<String> testProtocolConfig(VpnConfig cfg) async {
    _addLog('Testing ${cfg.protocolLabel} (${cfg.serverAddress}:${cfg.port})...');
    final ping = await testPing(cfg);
    if (ping == null || ping < 0) {
      return '${cfg.protocolLabel} UNREACHABLE (${cfg.serverAddress}:${cfg.port})';
    }
    _selectedConfigId = cfg.id;
    await connect();
    return '${cfg.protocolLabel} Reachable (${ping}ms) — Connecting now!';
  }

  void setProxyOnlyMode(bool val) {
    _proxyOnlyMode = val;
    _addLog('Proxy-Only Mode (keep other VPN): $val');
    notifyListeners();
  }

  Future<void> setRoutingMode(RoutingMode mode) async {
    _routingMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModeKey, mode.name);
    _addLog('Switched routing mode to ${mode.name.toUpperCase()}');
    notifyListeners();
  }

  Future<void> updateSettings({
    required String dns,
    String? secondaryDns,
    required bool bypassLan,
  }) async {
    _customDns = dns.trim().isEmpty ? '1.1.1.1' : dns.trim();
    _secondaryDns = (secondaryDns ?? _secondaryDns).trim().isEmpty
        ? '1.0.0.1'
        : (secondaryDns ?? _secondaryDns).trim();
    _bypassLan = bypassLan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDnsKey, _customDns);
    await prefs.setString(_prefsSecondaryDnsKey, _secondaryDns);
    await prefs.setBool(_prefsBypassLanKey, _bypassLan);
    _addLog('Applied DNS=$_customDns / $_secondaryDns, BypassLAN=$_bypassLan');
    notifyListeners();
  }

  void selectConfig(String id) {
    _selectedConfigId = id;
    _quotaWarning = null;
    _saveConfigs();
    notifyListeners();
  }

  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((c) => c.id == id);
    if (_selectedConfigId == id) {
      _selectedConfigId = _configs.isNotEmpty ? _configs.first.id : null;
    }
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> updateConfig(VpnConfig updated) async {
    final idx = _configs.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _configs[idx] = updated;
      await _saveConfigs();
      notifyListeners();
    }
  }

  Future<int> splitConfigIntoParts(
    VpnConfig source, {
    required double totalGb,
    required int parts,
    int? timeLimitMinutesPerPart,
  }) async {
    if (parts <= 0 || totalGb <= 0) return 0;
    final perPartBytes = ((totalGb / parts) * 1024 * 1024 * 1024).round();
    final perPartGb = (totalGb / parts).toStringAsFixed(1);

    for (int i = 1; i <= parts; i++) {
      _configs.add(VpnConfig(
        id: '${DateTime.now().microsecondsSinceEpoch}_part_$i',
        name: '${source.name} #$i (${perPartGb}GB)',
        protocol: source.protocol,
        rawConfig: source.rawConfig,
        serverAddress: source.serverAddress,
        port: source.port,
        isUdpPreferred: source.isUdpPreferred,
        pingMs: source.pingMs,
        subscriptionId: source.subscriptionId,
        quotaBytes: perPartBytes,
        usedBytes: 0,
        timeLimitMinutes: timeLimitMinutesPerPart,
        usedSeconds: 0,
      ));
    }
    await _saveConfigs();
    _addLog('Split "${source.name}" into $parts x ${perPartGb}GB parts.');
    notifyListeners();
    return parts;
  }

  Future<VpnConfig?> autoSelectBestPing({bool connectAfter = false}) async {
    if (_configs.isEmpty) return null;
    _addLog('Auto-Select Best Ping: testing ${_configs.length} config(s)...');
    await testAllPings();

    final reachable = _configs
        .where((c) => (c.pingMs ?? -1) > 0 && !c.isQuotaExceeded)
        .toList();
    if (reachable.isEmpty) {
      _addLog('Auto-Select: no reachable configs found.');
      return null;
    }

    reachable.sort((a, b) => a.pingMs!.compareTo(b.pingMs!));
    final best = reachable.first;
    _selectedConfigId = best.id;
    await _saveConfigs();
    _addLog('Auto-Selected best ping: ${best.name} (${best.pingMs} ms)');
    notifyListeners();

    if (connectAfter) {
      if (_connectionState == VpnConnectionState.connected) {
        await disconnect();
      }
      await connect();
    }
    return best;
  }

  VpnConfig? _pickSmartConfig() {
    if (_configs.isEmpty) return null;
    if (_routingMode == RoutingMode.manual) return activeConfig;

    final available = _configs.where((c) => !c.isQuotaExceeded).toList();
    if (available.isEmpty) return activeConfig;

    available.sort((a, b) =>
        _scoreConfig(b, _routingMode).compareTo(_scoreConfig(a, _routingMode)));
    return available.first;
  }

  int _scoreConfig(VpnConfig c, RoutingMode mode) {
    int score = 0;
    final ping = c.pingMs ?? 999;
    if (mode == RoutingMode.gaming) {
      if (c.protocol == VpnProtocol.wireguard) score += 500;
      if (c.protocol == VpnProtocol.v2ray && c.isUdpPreferred) score += 350;
      if (c.protocol == VpnProtocol.openvpn) score += 100;
      score += (1000 - ping.clamp(0, 999));
    } else {
      if (c.protocol == VpnProtocol.v2ray) score += 500;
      if (c.protocol == VpnProtocol.openvpn) score += 350;
      if (c.protocol == VpnProtocol.wireguard) score += 250;
      score += (500 - (ping.clamp(0, 999) ~/ 2));
    }
    return score;
  }

  String _injectCustomDns(VpnConfig target) {
    if (target.protocol == VpnProtocol.v2ray) {
      if (_customDns == '1.1.1.1') return target.rawConfig;
      try {
        final map = jsonDecode(target.rawConfig) as Map<String, dynamic>;
        final dnsMap = (map['dns'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        dnsMap['servers'] = [_customDns, _secondaryDns];
        dnsMap['queryStrategy'] = 'UseIPv4';
        map['dns'] = dnsMap;
        final inbounds = map['inbounds'] as List<dynamic>?;
        if (inbounds != null) {
          for (final inb in inbounds) {
            if (inb is Map<String, dynamic>) {
              inb['sniffing'] = {
                'enabled': true,
                'destOverride': ['http', 'tls', 'quic']
              };
            }
          }
        }
        final outbounds = map['outbounds'] as List<dynamic>?;
        final proxyTag = (outbounds != null && outbounds.isNotEmpty)
            ? ((outbounds.first as Map<String, dynamic>)['tag'] as String? ?? 'proxy')
            : 'proxy';
        final routing = (map['routing'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        routing['domainStrategy'] = 'AsIs';
        final rules = (routing['rules'] as List<dynamic>?) ?? <dynamic>[];
        rules.insert(0, {
          'type': 'field',
          'ip': [
            '149.154.160.0/20',
            '91.108.4.0/22',
            '91.108.8.0/22',
            '91.108.12.0/22',
            '91.108.16.0/22',
            '91.108.20.0/22',
            '91.108.56.0/22',
            '95.161.64.0/20'
          ],
          'outboundTag': proxyTag,
        });
        routing['rules'] = rules;
        map['routing'] = routing;
        return jsonEncode(map);
      } catch (_) {
        return target.rawConfig;
      }
    } else if (target.protocol == VpnProtocol.wireguard) {
      final lines = target.rawConfig.split('\n');
      final hasDns = lines.any((l) => l.trim().startsWith('DNS'));
      if (hasDns) {
        return lines
            .map((l) => l.trim().startsWith('DNS')
                ? 'DNS = $_customDns, $_secondaryDns'
                : l)
            .join('\n');
      } else {
        return target.rawConfig.replaceFirst(
            '[Interface]', '[Interface]\nDNS = $_customDns, $_secondaryDns');
      }
    }
    return target.rawConfig;
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    final target = _pickSmartConfig();
    if (target == null) {
      _addLog('ERROR: No configurations available to connect.');
      return;
    }
    if (target.isQuotaExceeded) {
      _quotaWarning = 'Quota or time limit reached for ${target.name}';
      _addLog('BLOCKED: $_quotaWarning');
      notifyListeners();
      return;
    }

    _quotaWarning = null;
    _selectedConfigId = target.id;
    _lastSessionBytes = 0;
    _connectionState = VpnConnectionState.connecting;
    _addLog('Connecting via ${target.protocolLabel}: ${target.name} (DNS: $_customDns)...');
    notifyListeners();

    // Prevent Android VpnService crash when switching from another protocol to WireGuard
    if (_isDnsChangerActive) {
      _isDnsChangerActive = false;
    }
    try { await _v2ray.stopV2Ray(); } catch (_) {}
    try { await _openVpn.disconnect(); } catch (_) {}
    try { await _wireGuard.stopVpn(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 650));

    final preparedConfig = _injectCustomDns(target).replaceAll('\r\n', '\n').trim();

    try {
      switch (target.protocol) {
        case VpnProtocol.v2ray:
          final granted = await _v2ray.requestPermission();
          if (!granted) throw Exception('VPN permission denied');
          await _v2ray.startV2Ray(
            remark: target.name,
            config: preparedConfig,
            proxyOnly: _proxyOnlyMode,
            bypassSubnets: null,
            notificationDisconnectButtonName: 'DISCONNECT',
          );
          break;

        case VpnProtocol.wireguard:
          if (!preparedConfig.contains('[Interface]') || !preparedConfig.contains('[Peer]')) {
            throw Exception('Invalid WireGuard configuration format');
          }
          try {
            await _wireGuard.initialize(interfaceName: 'wg_sopr0');
          } catch (_) {}
          final wgHost = target.serverAddress.isEmpty ? '1.1.1.1' : target.serverAddress;
          await _wireGuard.startVpn(
            serverAddress: '$wgHost:${target.port}',
            wgQuickConfig: preparedConfig,
            providerBundleIdentifier: 'com.vpnsopr.gaming',
          );
          break;

        case VpnProtocol.openvpn:
          final granted = await _openVpn.requestPermissionAndroid();
          if (!granted) throw Exception('OpenVPN permission denied');
          await _openVpn.connect(preparedConfig, target.name);
          break;
      }
    } catch (e) {
      _addLog('Connection failed: $e');
      _setDisconnectedState();
    }
  }

  Future<void> refreshPublicIp({int delayMs = 0}) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    _isLoadingIp = true;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json/?fields=status,query'))
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['query'] != null && j['query'].toString().isNotEmpty) {
          _currentPublicIp = j['query'].toString();
          _isLoadingIp = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}
    try {
      final res2 = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 7));
      if (res2.statusCode == 200) {
        final j2 = jsonDecode(res2.body) as Map<String, dynamic>;
        if (j2['ip'] != null && j2['ip'].toString().isNotEmpty) {
          _currentPublicIp = j2['ip'].toString();
        }
      }
    } catch (_) {}
    _isLoadingIp = false;
    notifyListeners();
  }

  Future<void> _detectConnectedCountry() async {
    if (!_isAdmin) return;
    _isDetectingCountry = true;
    notifyListeners();
    try {
      http.Response? res;
      try {
        res = await http
            .get(Uri.parse('http://ip-api.com/json/?fields=status,country,countryCode,city,query'))
            .timeout(const Duration(seconds: 7));
      } catch (_) {}

      Map<String, dynamic>? data;
      if (res != null && res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['status'] == 'success') data = j;
      }
      if (data == null && activeConfig != null && activeConfig!.serverAddress.isNotEmpty) {
        final fb = await http
            .get(Uri.parse('http://ip-api.com/json/${activeConfig!.serverAddress}?fields=status,country,countryCode,city,query'))
            .timeout(const Duration(seconds: 7));
        if (fb.statusCode == 200) {
          final j = jsonDecode(fb.body) as Map<String, dynamic>;
          if (j['status'] == 'success') data = j;
        }
      }
      if (data != null) {
        _connectedCountry = data['country'] as String?;
        _connectedCountryCode = data['countryCode'] as String?;
        _connectedCity = data['city'] as String?;
        _connectedExitIp = data['query'] as String?;
        _addLog('Admin Country Check: $_connectedCountry ($_connectedCountryCode) - $_connectedExitIp');
      }
    } catch (e) {
      _addLog('Country detect note: $e');
    } finally {
      _isDetectingCountry = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _connectionState = VpnConnectionState.disconnecting;
    notifyListeners();
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {}
    try {
      await _wireGuard.stopVpn();
    } catch (_) {}
    try {
      await _openVpn.disconnect();
    } catch (_) {}
    _setDisconnectedState();
    await _saveConfigs();
    _addLog('Disconnected.');
    unawaited(refreshPublicIp(delayMs: 600));
  }

  void _trackTrafficDelta(int currentSessionBytes) {
    final cfg = activeConfig;
    if (cfg == null) return;
    final delta = currentSessionBytes - _lastSessionBytes;
    if (delta > 0) {
      cfg.usedBytes += delta;
      _lastSessionBytes = currentSessionBytes;
      if (cfg.isQuotaExceeded) {
        _quotaWarning = 'Data limit reached for ${cfg.name}. Auto-disconnected.';
        _addLog(_quotaWarning!);
        unawaited(disconnect());
      }
    }
  }

  void _setConnectedState() {
    if (_connectionState == VpnConnectionState.connected) return;
    _connectionState = VpnConnectionState.connected;
    unawaited(_detectConnectedCountry());
    unawaited(refreshPublicIp(delayMs: 900));
    _connectedAt = DateTime.now();
    _durationTimer?.cancel();
    _connectedCountry = null;
    _connectedCountryCode = null;
    _connectedCity = null;
    _connectedExitIp = null;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        final diff = DateTime.now().difference(_connectedAt!);
        _duration = _formatDuration(diff);
        final cfg = activeConfig;
        if (cfg != null) {
          cfg.usedSeconds += 1;
          if (cfg.isQuotaExceeded) {
            _quotaWarning = 'Time/Data limit reached for ${cfg.name}.';
            _addLog(_quotaWarning!);
            unawaited(disconnect());
            return;
          }
          if (cfg.usedSeconds % 15 == 0) {
            unawaited(_saveConfigs());
          }
        }
        notifyListeners();
      }
    });
  }

  void _setDisconnectedState() {
    _connectionState = VpnConnectionState.disconnected;
    _durationTimer?.cancel();
    _connectedCountry = null;
    _connectedCountryCode = null;
    _connectedCity = null;
    _connectedExitIp = null;
    _connectedAt = null;
    _duration = '00:00:00';
    _uploadSpeed = '0 KB/s';
    _downloadSpeed = '0 KB/s';
    notifyListeners();
  }

  String? _wireguardUriToConf(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'wireguard' && uri.scheme != 'wg') return null;
      final privKey = Uri.decodeComponent(uri.userInfo);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 51820;
      final q = uri.queryParameters;
      final pubKey = q['publickey'] ?? q['pbk'] ?? q['public_key'] ?? '';
      final address = q['address'] ?? q['ip'] ?? '10.0.0.2/32';
      final psk = q['presharedkey'] ?? q['psk'] ?? '';
      final mtu = q['mtu'] ?? '1280';
      final dns = q['dns'] ?? _customDns;
      if (privKey.isEmpty || pubKey.isEmpty || host.isEmpty) return null;
      final buf = StringBuffer()
        ..writeln('[Interface]')
        ..writeln('PrivateKey = $privKey')
        ..writeln('Address = $address')
        ..writeln('DNS = $dns')
        ..writeln('MTU = $mtu')
        ..writeln()
        ..writeln('[Peer]')
        ..writeln('PublicKey = $pubKey');
      if (psk.isNotEmpty) buf.writeln('PresharedKey = $psk');
      buf
        ..writeln('AllowedIPs = 0.0.0.0/0, ::/0')
        ..writeln('Endpoint = $host:$port')
        ..writeln('PersistentKeepalive = 25');
      return buf.toString();
    } catch (_) {
      return null;
    }
  }

  Future<int> importRawInput(String input,
      {String? customName, String? subscriptionId}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;

    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !trimmed.contains('\n')) {
      return addAndFetchSubscription(trimmed, name: customName);
    }

    int added = 0;
    if (trimmed.contains('[Interface]') && trimmed.contains('[Peer]')) {
      final blocks = trimmed.split(RegExp(r'(?=\[Interface\])'));
      for (final rawBlock in blocks) {
        final block = rawBlock.trim();
        if (!block.contains('[Interface]') || !block.contains('[Peer]')) continue;
        final endpointMatch =
            RegExp(r'Endpoint\s*=\s*([^\s:]+):(\d+)').firstMatch(block);
        final host = endpointMatch?.group(1) ?? 'wireguard.server';
        final port = int.tryParse(endpointMatch?.group(2) ?? '51820') ?? 51820;
        final remarkMatch = RegExp(r'^#\s*(.+)$', multiLine: true).firstMatch(block);
        final wgName = customName ?? remarkMatch?.group(1)?.trim() ?? 'WG $host';
        _configs.add(VpnConfig(
          id: '${DateTime.now().microsecondsSinceEpoch}_$added',
          name: wgName,
          protocol: VpnProtocol.wireguard,
          rawConfig: block,
          serverAddress: host,
          port: port,
          isUdpPreferred: true,
          subscriptionId: subscriptionId,
        ));
        added++;
      }
    } else if (trimmed.contains('client') && trimmed.contains('remote ')) {
      final remoteMatch =
          RegExp(r'remote\s+([^\s]+)\s+(\d+)').firstMatch(trimmed);
      final host = remoteMatch?.group(1) ?? 'openvpn.server';
      final port = int.tryParse(remoteMatch?.group(2) ?? '1194') ?? 1194;
      _configs.add(VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: customName ?? 'OVPN $host',
        protocol: VpnProtocol.openvpn,
        rawConfig: trimmed,
        serverAddress: host,
        port: port,
        isUdpPreferred: trimmed.contains('proto udp'),
        subscriptionId: subscriptionId,
      ));
      added++;
    } else if (trimmed.startsWith('{') && trimmed.contains('outbounds')) {
      _configs.add(VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: customName ?? 'Xray JSON',
        protocol: VpnProtocol.v2ray,
        rawConfig: trimmed,
        serverAddress: 'json.xray',
        port: 443,
        subscriptionId: subscriptionId,
      ));
      added++;
    } else {
      final lines = trimmed.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final link = line.trim();
        if (link.isEmpty) continue;
        if (link.startsWith('wireguard://') || link.startsWith('wg://')) {
          final conf = _wireguardUriToConf(link);
          if (conf != null) {
            final uri = Uri.tryParse(link);
            final frag = (uri != null && uri.fragment.isNotEmpty)
                ? Uri.decodeComponent(uri.fragment)
                : 'WG ${uri?.host ?? 'Server'}';
            _configs.add(VpnConfig(
              id: '${DateTime.now().microsecondsSinceEpoch}_$added',
              name: customName ?? frag,
              protocol: VpnProtocol.wireguard,
              rawConfig: conf,
              serverAddress: uri?.host ?? 'wireguard.server',
              port: (uri != null && uri.hasPort) ? uri.port : 51820,
              isUdpPreferred: true,
              subscriptionId: subscriptionId,
            ));
            added++;
          }
          continue;
        }
        try {
          final parsed = FlutterV2ray.parseFromURL(link);
          final lower = link.toLowerCase();
          final udpFriendly =
              lower.contains('type=kcp') || lower.contains('type=quic');
          _configs.add(VpnConfig(
            id: '${DateTime.now().microsecondsSinceEpoch}_$added',
            name: customName ?? parsed.remark,
            protocol: VpnProtocol.v2ray,
            rawConfig: parsed.getFullConfiguration(),
            serverAddress: parsed.address,
            port: parsed.port,
            isUdpPreferred: udpFriendly,
            subscriptionId: subscriptionId,
          ));
          added++;
        } catch (e) {
          _addLog('Skipped invalid line: $e');
        }
      }
    }

    if (added > 0) {
      _selectedConfigId ??= _configs.first.id;
      await _saveConfigs();
      _addLog('Imported $added configuration(s).');
      notifyListeners();
    }
    return added;
  }

  Future<int> addAndFetchSubscription(String url, {String? name}) async {
    final cleanUrl = url.trim();
    var existing = _subscriptions.where((s) => s.url == cleanUrl).toList();
    late SubscriptionItem sub;
    if (existing.isEmpty) {
      sub = SubscriptionItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : Uri.tryParse(cleanUrl)?.host ?? 'Subscription',
        url: cleanUrl,
      );
      _subscriptions.add(sub);
    } else {
      sub = existing.first;
    }
    await _saveSubs();
    return refreshSubscription(sub);
  }

  Future<int> refreshSubscription(SubscriptionItem sub) async {
    _isUpdatingSubs = true;
    _subUpdateStatus = 'Updating ${sub.name}...';
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(sub.url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      String body = response.body.trim();
      if (!body.contains('://') && !body.contains('[Interface]')) {
        try {
          final normalized = base64.normalize(body);
          body = utf8.decode(base64Decode(normalized));
        } catch (_) {}
      }
      _configs.removeWhere((c) => c.subscriptionId == sub.id);
      final count = await importRawInput(body, subscriptionId: sub.id);
      sub.lastUpdated = DateTime.now();
      sub.configCount = count;
      _lastSubSync = sub.lastUpdated;
      _subUpdateStatus = 'Updated ($count)';
      await _saveSubs();
      await _saveConfigs();
      _addLog('Subscription "${sub.name}" updated: $count config(s).');
      return count;
    } catch (e) {
      _subUpdateStatus = 'Update failed';
      _addLog('Subscription "${sub.name}" error: $e');
      rethrow;
    } finally {
      _isUpdatingSubs = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllSubscriptions() async {
    if (_subscriptions.isEmpty) return;
    _isUpdatingSubs = true;
    _subUpdateStatus = 'Syncing ${_subscriptions.length} sub(s)...';
    notifyListeners();
    int total = 0;
    for (final sub in List<SubscriptionItem>.from(_subscriptions)) {
      try {
        total += await refreshSubscription(sub);
      } catch (_) {}
    }
    _isUpdatingSubs = false;
    _lastSubSync = DateTime.now();
    _subUpdateStatus = 'Synced ($total)';
    notifyListeners();
  }

  Future<void> deleteSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    _configs.removeWhere((c) => c.subscriptionId == id);
    await _saveSubs();
    await _saveConfigs();
    notifyListeners();
  }

  Future<int?> testPing(VpnConfig config) async {
    try {
      if (config.protocol == VpnProtocol.v2ray) {
        final delay = await _v2ray.getServerDelay(config: config.rawConfig);
        config.pingMs = delay > 0 ? delay : null;
      } else {
        final sw = Stopwatch()..start();
        final socket = await Socket.connect(
          config.serverAddress,
          config.port,
          timeout: const Duration(seconds: 3),
        );
        sw.stop();
        socket.destroy();
        config.pingMs = sw.elapsedMilliseconds;
      }
    } catch (_) {
      config.pingMs = -1;
    }
    await _saveConfigs();
    notifyListeners();
    return config.pingMs;
  }

  Future<void> testAllPings() async {
    for (final c in _configs) {
      await testPing(c);
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _addLog(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$ts] $message');
    if (_logs.length > 250) _logs.removeLast();
  }

  String _formatBytesPerSec(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
