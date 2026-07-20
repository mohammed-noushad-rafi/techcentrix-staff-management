import 'package:flutter/material.dart';

class AppTheme {
  static const primary    = Color(0xFF1B9CD8);
  static const secondary  = Color(0xFFF7941D);
  static const dark       = Color(0xFF1A1A2E);
  static const surface    = Color(0xFFF0F8FF);
  static const cardBg     = Colors.white;
  static const success    = Color(0xFF10B981);
  static const warning    = Color(0xFFF7941D);
  static const error      = Color(0xFFEF4444);
  static const info       = Color(0xFF1B9CD8);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B9CD8), Color(0xFF0E6FA3)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF0E6FA3), Color(0xFF1B9CD8), Color(0xFF2DB8F0)],
  );

  static Color statusColor(String s) {
    switch (s) {
      case 'present':     return success;
      case 'late':        return secondary;
      case 'absent':      return error;
      case 'leave':       return primary;
      case 'wfh':         return const Color(0xFF0D9488);
      case 'completed':   return success;
      case 'in_progress': return primary;
      case 'done_pending':return secondary;
      default:            return const Color(0xFF6B7280);
    }
  }

  static Color priorityColor(String p) {
    switch (p) {
      case 'urgent': return error;
      case 'high':   return secondary;
      case 'medium': return primary;
      default:       return success;
    }
  }

  static List<List<Color>> avatarGradients = [
    [Color(0xFF1B9CD8), Color(0xFF0E6FA3)],
    [Color(0xFFF7941D), Color(0xFFE07B0A)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    [Color(0xFFEF4444), Color(0xFFB91C1C)],
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
  ];

  static LinearGradient avatarGradient(String name) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % avatarGradients.length;
    return LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: avatarGradients[idx],
    );
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary, brightness: Brightness.light,
      surface: surface, secondary: secondary,
    ),
    scaffoldBackgroundColor: surface,
    cardTheme: CardThemeData(
      color: cardBg, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary, foregroundColor: Colors.white, elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE0F4FF),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class GradientAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? photoUrl;
  const GradientAvatar({super.key, required this.name, this.radius = 20, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl!));
    }
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const StatusPill({super.key, required this.label, required this.color, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
  );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ]),
    ),
  ));
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      if (action != null) action!,
    ]),
  );
}
