import 'dart:convert';

enum VpnProtocol { wireguard, v2ray, openvpn }

enum RoutingMode { gaming, web, manual }

enum PanelType { threeXUi, marzban, pasargad, nexora, custom }

enum IranianGateway { zarinpal, zibal, idpay, blubank }

class DnsPreset {
  final String name;
  final String primary;
  final String secondary;
  final String tag;

  const DnsPreset({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.tag,
  });

  static const List<DnsPreset> freePresets = [
    DnsPreset(name: 'Cloudflare', primary: '1.1.1.1', secondary: '1.0.0.1', tag: 'Fast'),
    DnsPreset(name: 'Google DNS', primary: '8.8.8.8', secondary: '8.8.4.4', tag: 'Global'),
    DnsPreset(name: 'Quad9', primary: '9.9.9.9', secondary: '149.112.112.112', tag: 'Secure'),
    DnsPreset(name: 'AdGuard DNS', primary: '94.140.14.14', secondary: '94.140.15.15', tag: 'AdBlock'),
    DnsPreset(name: 'Radar Game', primary: '10.202.10.10', secondary: '10.202.10.11', tag: 'Gaming'),
    DnsPreset(name: 'Electro', primary: '78.157.42.100', secondary: '78.157.42.101', tag: 'Gaming'),
    DnsPreset(name: 'Shecan', primary: '178.22.122.100', secondary: '185.51.200.2', tag: 'Bypass'),
    DnsPreset(name: '403.online', primary: '10.202.10.202', secondary: '10.202.10.102', tag: 'Bypass'),
    DnsPreset(name: 'Begzar', primary: '185.55.226.26', secondary: '185.55.225.25', tag: 'Bypass'),
    DnsPreset(name: 'OpenDNS', primary: '208.67.222.222', secondary: '208.67.220.220', tag: 'Classic'),
  ];
}

class VpnPlan {
  final String id;
  final String title;
  final double volumeGb;
  final int durationDays;
  final int priceTomans;
  final List<String> outboundIds;

  VpnPlan({
    required this.id,
    required this.title,
    required this.volumeGb,
    required this.durationDays,
    required this.priceTomans,
    this.outboundIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'volumeGb': volumeGb,
        'durationDays': durationDays,
        'priceTomans': priceTomans,
        'outboundIds': outboundIds,
      };

  factory VpnPlan.fromJson(Map<String, dynamic> json) => VpnPlan(
        id: json['id'] as String,
        title: json['title'] as String,
        volumeGb: (json['volumeGb'] as num).toDouble(),
        durationDays: json['durationDays'] as int? ?? 30,
        priceTomans: json['priceTomans'] as int,
        outboundIds: (json['outboundIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      );

  static String encodeList(List<VpnPlan> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<VpnPlan> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => VpnPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class PanelProfile {
  final String id;
  final String name;
  final PanelType type;
  final String baseUrl;
  final String username;
  final String password;
  DateTime? lastSynced;

  PanelProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.username,
    required this.password,
    this.lastSynced,
  });

  String get typeLabel {
    switch (type) {
      case PanelType.threeXUi:
        return '3x-UI / X-UI';
      case PanelType.marzban:
        return 'Marzban';
      case PanelType.pasargad:
        return 'Pasargad Panel';
      case PanelType.nexora:
        return 'Nexora Panel';
      case PanelType.custom:
        return 'Custom REST';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
        'lastSynced': lastSynced?.toIso8601String(),
      };

  factory PanelProfile.fromJson(Map<String, dynamic> json) => PanelProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        type: PanelType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PanelType.threeXUi,
        ),
        baseUrl: json['baseUrl'] as String,
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        lastSynced: json['lastSynced'] != null
            ? DateTime.tryParse(json['lastSynced'] as String)
            : null,
      );

  static String encodeList(List<PanelProfile> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<PanelProfile> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => PanelProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class PaymentGatewayConfig {
  IranianGateway gateway;
  bool enabled;
  String merchantOrCard;
  String callbackUrl;
  int pricePerGbTomans;

  PaymentGatewayConfig({
    this.gateway = IranianGateway.zarinpal,
    this.enabled = false,
    this.merchantOrCard = '',
    this.callbackUrl = 'https://morningg.ir/verify',
    this.pricePerGbTomans = 4000,
  });

  String get label {
    switch (gateway) {
      case IranianGateway.zarinpal:
        return 'زرین‌پال (ZarinPal)';
      case IranianGateway.zibal:
        return 'زیبال (Zibal)';
      case IranianGateway.idpay:
        return 'آیدی‌پی (IDPay)';
      case IranianGateway.blubank:
        return 'بلوبانک / کارت به کارت';
    }
  }

  Map<String, dynamic> toJson() => {
        'gateway': gateway.name,
        'enabled': enabled,
        'merchantOrCard': merchantOrCard,
        'callbackUrl': callbackUrl,
        'pricePerGbTomans': pricePerGbTomans,
      };

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) =>
      PaymentGatewayConfig(
        gateway: IranianGateway.values.firstWhere(
          (e) => e.name == json['gateway'],
          orElse: () => IranianGateway.zarinpal,
        ),
        enabled: json['enabled'] as bool? ?? false,
        merchantOrCard: json['merchantOrCard'] as String? ?? '',
        callbackUrl:
            json['callbackUrl'] as String? ?? 'https://morningg.ir/verify',
        pricePerGbTomans: json['pricePerGbTomans'] as int? ?? 4000,
      );
}

class SubscriptionItem {
  final String id;
  final String name;
  final String url;
  DateTime? lastUpdated;
  int configCount;

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdated,
    this.configCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'configCount': configCount,
      };

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) =>
      SubscriptionItem(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
        configCount: json['configCount'] as int? ?? 0,
      );

  static String encodeList(List<SubscriptionItem> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SubscriptionItem> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => SubscriptionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class VpnConfig {
  final String id;
  final String name;
  final VpnProtocol protocol;
  final String rawConfig;
  final String serverAddress;
  final int port;
  final bool isUdpPreferred;
  int? pingMs;
  String? subscriptionId;
  int? quotaBytes;
  int usedBytes;
  int? timeLimitMinutes;
  int usedSeconds;

  VpnConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rawConfig,
    required this.serverAddress,
    required this.port,
    this.isUdpPreferred = false,
    this.pingMs,
    this.subscriptionId,
    this.quotaBytes,
    this.usedBytes = 0,
    this.timeLimitMinutes,
    this.usedSeconds = 0,
  });

  bool get hasQuotaLimit => quotaBytes != null && quotaBytes! > 0;
  bool get hasTimeLimit => timeLimitMinutes != null && timeLimitMinutes! > 0;

  bool get isQuotaExceeded =>
      (hasQuotaLimit && usedBytes >= quotaBytes!) ||
      (hasTimeLimit && usedSeconds >= (timeLimitMinutes! * 60));

  double get quotaProgress {
    if (!hasQuotaLimit) return 0;
    return (usedBytes / quotaBytes!).clamp(0.0, 1.0);
  }

  double get timeProgress {
    if (!hasTimeLimit) return 0;
    return (usedSeconds / (timeLimitMinutes! * 60)).clamp(0.0, 1.0);
  }

  String get remainingQuotaLabel {
    if (!hasQuotaLimit) return 'Unlimited';
    final rem = (quotaBytes! - usedBytes).clamp(0, quotaBytes!);
    final gb = rem / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB left';
    final mb = rem / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB left';
  }

  String get remainingTimeLabel {
    if (!hasTimeLimit) return 'No Time Limit';
    final remSec =
        ((timeLimitMinutes! * 60) - usedSeconds).clamp(0, timeLimitMinutes! * 60);
    final h = remSec ~/ 3600;
    final m = (remSec % 3600) ~/ 60;
    return '${h}h ${m}m left';
  }

  String get protocolLabel {
    switch (protocol) {
      case VpnProtocol.wireguard:
        return 'WireGuard';
      case VpnProtocol.v2ray:
        return 'V2Ray / Xray';
      case VpnProtocol.openvpn:
        return 'OpenVPN';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'rawConfig': rawConfig,
        'serverAddress': serverAddress,
        'port': port,
        'isUdpPreferred': isUdpPreferred,
        'pingMs': pingMs,
        'subscriptionId': subscriptionId,
        'quotaBytes': quotaBytes,
        'usedBytes': usedBytes,
        'timeLimitMinutes': timeLimitMinutes,
        'usedSeconds': usedSeconds,
      };

  factory VpnConfig.fromJson(Map<String, dynamic> json) => VpnConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: VpnProtocol.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => VpnProtocol.v2ray,
        ),
        rawConfig: json['rawConfig'] as String,
        serverAddress: json['serverAddress'] as String? ?? 'unknown',
        port: json['port'] as int? ?? 443,
        isUdpPreferred: json['isUdpPreferred'] as bool? ?? false,
        pingMs: json['pingMs'] as int?,
        subscriptionId: json['subscriptionId'] as String?,
        quotaBytes: json['quotaBytes'] as int?,
        usedBytes: json['usedBytes'] as int? ?? 0,
        timeLimitMinutes: json['timeLimitMinutes'] as int?,
        usedSeconds: json['usedSeconds'] as int? ?? 0,
      );

  static String encodeList(List<VpnConfig> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<VpnConfig> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => VpnConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}


enum OrderStatus { pending, approved, rejected }

class PaymentOrder {
  final String id;
  final String username;
  final String planTitle;
  final double volumeGb;
  final int durationDays;
  final int priceTomans;
  final List<String> outboundIds;
  final String? receiptImagePath;
  final String? receiptBase64;
  final String? activatedConfigJson;
  final String trackingCode;
  OrderStatus status;
  final DateTime createdAt;

  PaymentOrder({
    required this.id,
    required this.username,
    required this.planTitle,
    required this.volumeGb,
    required this.durationDays,
    required this.priceTomans,
    this.outboundIds = const [],
    this.receiptImagePath,
    this.receiptBase64,
    this.activatedConfigJson,
    this.trackingCode = '',
    this.status = OrderStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'planTitle': planTitle,
        'volumeGb': volumeGb,
        'durationDays': durationDays,
        'priceTomans': priceTomans,
        'outboundIds': outboundIds,
        'receiptImagePath': receiptImagePath,
        'receiptBase64': receiptBase64,
        'activatedConfigJson': activatedConfigJson,
        'trackingCode': trackingCode,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        id: json['id'] as String,
        username: json['username'] as String? ?? 'Guest',
        planTitle: json['planTitle'] as String,
        volumeGb: (json['volumeGb'] as num).toDouble(),
        durationDays: json['durationDays'] as int? ?? 30,
        priceTomans: json['priceTomans'] as int,
        outboundIds: (json['outboundIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        receiptImagePath: json['receiptImagePath'] as String?,
        receiptBase64: json['receiptBase64'] as String?,
        activatedConfigJson: json['activatedConfigJson'] as String?,
        trackingCode: json['trackingCode'] as String? ?? '',
        status: OrderStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OrderStatus.pending,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  static String encodeList(List<PaymentOrder> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<PaymentOrder> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => PaymentOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}


class OutboundPool {
  final String id;
  final String name;
  final VpnProtocol protocol;
  final String rawConfig;
  final String serverAddress;
  final int port;
  final double totalGb;
  double reservedGb;

  OutboundPool({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rawConfig,
    required this.serverAddress,
    required this.port,
    required this.totalGb,
    this.reservedGb = 0,
  });

  double get remainingGb => (totalGb - reservedGb).clamp(0.0, totalGb);
  bool get isExhausted => remainingGb <= 0.01;
  bool canReserve(double gb) => remainingGb + 0.001 >= gb;
  double get usageRatio => totalGb > 0 ? (reservedGb / totalGb).clamp(0.0, 1.0) : 1.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'rawConfig': rawConfig,
        'serverAddress': serverAddress,
        'port': port,
        'totalGb': totalGb,
        'reservedGb': reservedGb,
      };

  factory OutboundPool.fromJson(Map<String, dynamic> json) => OutboundPool(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: VpnProtocol.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => VpnProtocol.v2ray,
        ),
        rawConfig: json['rawConfig'] as String,
        serverAddress: json['serverAddress'] as String? ?? 'outbound',
        port: json['port'] as int? ?? 443,
        totalGb: (json['totalGb'] as num).toDouble(),
        reservedGb: (json['reservedGb'] as num?)?.toDouble() ?? 0.0,
      );

  static String encodeList(List<OutboundPool> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<OutboundPool> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => OutboundPool.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}


class SupportTicket {
  final String id;
  final String username;
  final String subject;
  final String message;
  String adminReply;
  String status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.username,
    required this.subject,
    required this.message,
    this.adminReply = '',
    this.status = 'open',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'subject': subject,
        'message': message,
        'adminReply': adminReply,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        username: json['username'] as String? ?? 'Guest',
        subject: json['subject'] as String? ?? '',
        message: json['message'] as String? ?? '',
        adminReply: json['adminReply'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  static String encodeList(List<SupportTicket> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<SupportTicket> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
