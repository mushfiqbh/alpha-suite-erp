import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityItem {
  final String title;
  final String meta;
  final _ActivityIconType iconType;
  final bool muted;

  const ActivityItem({
    required this.title,
    required this.meta,
    required this.iconType,
    this.muted = false,
  });
}

enum _ActivityIconType { inventory, invoice, employee, system }

class ActivityFeedWidget extends StatelessWidget {
  static const List<ActivityItem> _items = [
    ActivityItem(
      title: 'New Inventory Added',
      meta: 'WAREHOUSE A • 2M AGO',
      iconType: _ActivityIconType.inventory,
    ),
    ActivityItem(
      title: 'Invoice #882 Paid',
      meta: 'CLIENT: ACME CORP • 1H AGO',
      iconType: _ActivityIconType.invoice,
    ),
    ActivityItem(
      title: 'New Employee Onboarded',
      meta: 'HR DEPT • 4H AGO',
      iconType: _ActivityIconType.employee,
    ),
    ActivityItem(
      title: 'System Update Completed',
      meta: 'V2.4 STABLE • YESTERDAY',
      iconType: _ActivityIconType.system,
      muted: true,
    ),
  ];

  const ActivityFeedWidget({super.key});

  Widget _buildIcon(_ActivityIconType type) {
    switch (type) {
      case _ActivityIconType.inventory:
        return _ActivityIconContainer(
          backgroundColor: const Color(0xFFE8F5E9),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: const Color(0xFF2E7D32),
          ),
        );
      case _ActivityIconType.invoice:
        return _ActivityIconContainer(
          backgroundColor: const Color(0xFFE3F2FD),
          child: Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: const Color(0xFF1565C0),
          ),
        );
      case _ActivityIconType.employee:
        return _ActivityIconContainer(
          backgroundColor: const Color(0xFFFFF3E0),
          child: Icon(
            Icons.person_add_outlined,
            size: 20,
            color: const Color(0xFFE65100),
          ),
        );
      case _ActivityIconType.system:
        return _ActivityIconContainer(
          backgroundColor: const Color(0xFFF5F5F5),
          child: Icon(
            Icons.settings_outlined,
            size: 20,
            color: const Color(0xFF757575),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7C4D8).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF151C27),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ..._items.asMap().entries.map((entry) {
            final item = entry.value;
            return Opacity(
              opacity: item.muted ? 0.6 : 1.0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < _items.length - 1 ? 20 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIcon(item.iconType),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF151C27),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.meta,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.6,
                              color: const Color(0xFF464555),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {},
            child: Text(
              'View all logs →',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF3525CD),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityIconContainer extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;

  const _ActivityIconContainer({
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: child),
    );
  }
}
