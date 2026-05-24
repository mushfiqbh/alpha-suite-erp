import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alpha_suite_erp/core/constants/app_routes.dart';
import 'package:alpha_suite_erp/providers/auth_providers.dart';
import 'package:alpha_suite_erp/services/permission_service.dart';

class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<ShellNavItem> _allItems = [
    ShellNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.dashboard,
    ),
    ShellNavItem(
      label: 'CRM',
      icon: Icons.people_outline,
      route: AppRoutes.crm,
    ),
    ShellNavItem(
      label: 'Sales',
      icon: Icons.point_of_sale_outlined,
      route: AppRoutes.sales,
    ),
    ShellNavItem(
      label: 'HR',
      icon: Icons.badge_outlined,
      route: AppRoutes.hr,
    ),
    ShellNavItem(
      label: 'Payroll',
      icon: Icons.payments_outlined,
      route: '/payroll', // Placeholder for now
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionService = ref.watch(permissionServiceProvider);
    final role = ref.watch(roleProvider);

    final visibleItems = _allItems.toList(); // For UI cloning, let's show all

    final currentLocation = GoRouterState.of(context).uri.path;
    final selectedIndex = visibleItems.indexWhere(
      (item) => item.route == currentLocation,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SmartERP Pro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                      const Text(
                        'ENTERPRISE ADMIN CONSOLE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final isSelected = selectedIndex == index;
                      return _SidebarItem(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => context.go(item.route),
                      );
                    },
                  ),
                ),
                // User Profile at bottom
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo.shade600,
                        child: const Text('JD', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enterprise Pro',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'v2.4.0',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Sales POS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Search Bar
                      Container(
                        width: 400,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search products, SKU or category...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(top: 2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Stack(
                        children: [
                          Icon(Icons.notifications_none, color: Colors.grey.shade600),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 16),
                      const CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade600,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}