import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/dragon_theme.dart';

class WebTunnelScreen extends StatefulWidget {
  final String initialUrl;
  const WebTunnelScreen({super.key, required this.initialUrl});

  @override
  State<WebTunnelScreen> createState() => _WebTunnelScreenState();
}

class _WebTunnelScreenState extends State<WebTunnelScreen> {
  late final WebViewController _controller;
  late final TextEditingController _urlCtrl;
  int _progress = 0;

  String _normalizeUrl(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return 'https://morningg.ir';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      return 'http://$u';
    }
    return u;
  }

  @override
  void initState() {
    super.initState();
    final startUrl = _normalizeUrl(widget.initialUrl);
    _urlCtrl = TextEditingController(text: startUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DragonColors.oledBlack)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (url) {
            if (mounted) _urlCtrl.text = url;
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _urlCtrl,
          style: const TextStyle(fontSize: 13),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          decoration: const InputDecoration(
            hintText: 'http://IP:PORT یا آدرس سایت تانل',
            border: InputBorder.none,
            isDense: true,
          ),
          onSubmitted: (v) => _controller.loadRequest(Uri.parse(_normalizeUrl(v))),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DragonColors.electricBlue),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  color: DragonColors.electricBlue,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
