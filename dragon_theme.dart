import 'package:flutter/material.dart';

class DragonColors {
  static const Color oledBlack = Color(0xFFEDEAF3);      // Soft Lavender Pearl BG
  static const Color charcoal = Color(0xFFF6F4FA);       // Light Surface
  static const Color cardSurface = Color(0xFFF9F8FC);    // Neumorphic White Card
  static const Color electricBlue = Color(0xFF7B4DFF);   // Primary Violet Accent
  static const Color neonPurple = Color(0xFF9C6BFF);     // Secondary Lavender Purple
  static const Color crimsonRed = Color(0xFFFF453A);     // Status Red
  static const Color emberOrange = Color(0xFF2EC46D);    // Emerald Green (Connected / Discount)
  static const Color textPrimary = Color(0xFF1A1B2E);    // Deep Navy Text
  static const Color textSecondary = Color(0xFF7A7D96);  // Muted Slate Text
  static const Color shadowDark = Color(0xFFD2CEE0);
  static const Color shadowLight = Color(0xFFFFFFFF);
}

BoxDecoration neumorphicBox({
  double radius = 22,
  Color? color,
  bool isCircle = false,
  Border? border,
}) {
  return BoxDecoration(
    color: color ?? DragonColors.cardSurface,
    shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: isCircle ? null : BorderRadius.circular(radius),
    border: border,
    boxShadow: const [
      BoxShadow(
        color: DragonColors.shadowLight,
        offset: Offset(-5, -5),
        blurRadius: 12,
      ),
      BoxShadow(
        color: DragonColors.shadowDark,
        offset: Offset(6, 6),
        blurRadius: 14,
      ),
    ],
  );
}

ThemeData buildDragonTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: DragonColors.oledBlack,
    colorScheme: const ColorScheme.light(
      primary: DragonColors.electricBlue,
      secondary: DragonColors.neonPurple,
      error: DragonColors.crimsonRed,
      surface: DragonColors.cardSurface,
      onPrimary: Colors.white,
      onSurface: DragonColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: DragonColors.textPrimary,
      iconTheme: IconThemeData(color: DragonColors.electricBlue),
    ),
    cardTheme: CardTheme(
      color: DragonColors.cardSurface,
      elevation: 2,
      shadowColor: DragonColors.shadowDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDAD6E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDAD6E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DragonColors.electricBlue, width: 1.6),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DragonColors.cardSurface,
      selectedItemColor: DragonColors.electricBlue,
      unselectedItemColor: DragonColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

class DragonScaleBackground extends StatelessWidget {
  final Widget child;
  const DragonScaleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF1EEF7),
            Color(0xFFE9E5F2),
          ],
        ),
      ),
      child: child,
    );
  }
}

class DragonCrestLogo extends StatelessWidget {
  final double size;
  const DragonCrestLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: DragonColors.electricBlue.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            backgroundColor: DragonColors.electricBlue,
            child: Icon(Icons.shield_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}


class DragonScalePainter extends CustomPainter {
  final Color accentColor;
  DragonScalePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant DragonScalePainter oldDelegate) => false;
}

class DragonLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant DragonLogoPainter oldDelegate) => false;
}
