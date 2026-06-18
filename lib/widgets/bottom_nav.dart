import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomNavItem {
  final String label;
  final IconData icon;

  const BottomNavItem({required this.label, required this.icon});
}

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _activeIndex = 0;

  static const List<BottomNavItem> _items = [
    BottomNavItem(label: 'Dashboard', icon: Icons.grid_view_rounded),
    BottomNavItem(label: 'Inventory', icon: Icons.inventory_2_outlined),
    BottomNavItem(label: 'CRM', icon: Icons.bar_chart_rounded),
    BottomNavItem(label: 'Manager', icon: Icons.people_outline_rounded),
    BottomNavItem(label: 'More', icon: Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(
          top: BorderSide(color: Color(0x20E2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = _activeIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: isActive
                            ? const Color(0xFF3525CD)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isActive
                              ? const Color(0xFF3525CD)
                              : const Color(0xFF64748B),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
