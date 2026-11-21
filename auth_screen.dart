import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final engine = context.read<VpnEngineService>();
    final ok = await engine.login(_userCtrl.text, _passCtrl.text);
    if (!ok && mounted) {
      setState(() => _error = 'نام کاربری و رمز عبور را وارد کنید');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DragonColors.oledBlack,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DragonScalePainter(accentColor: DragonColors.crimsonRed),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(74, 74),
                        painter: DragonLogoPainter(
                          primary: DragonColors.electricBlue,
                          secondary: DragonColors.crimsonRed,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'VPNSOPR TURBO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'احراز هویت ورود به شبکه اژدها',
                        style: TextStyle(
                            fontSize: 12, color: DragonColors.textSecondary),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نام کاربری (Username)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'رمز عبور (Password)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: DragonColors.crimsonRed, fontSize: 12)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DragonColors.crimsonRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _submit,
                          child: const Text('ورود به برنامه',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          context
                              .read<VpnEngineService>()
                              .login('DragonGuest', 'guest');
                        },
                        child: const Text(
                          'ورود سریع مهمان (بدون پنل ادمین)',
                          style: TextStyle(color: DragonColors.electricBlue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
