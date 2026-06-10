import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/services/permission_service.dart';

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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const double _desktopBreakpoint = 1080;
  static const double _expandedSidebarWidth = 280;
  static const double _collapsedSidebarWidth = 88;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;

  static const List<ShellNavItem> _sidebarItems = [
    ShellNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.dashboard,
    ),
    ShellNavItem(
      label: 'Customers',
      icon: Icons.groups_rounded,
      route: AppRoutes.customers,
    ),
    ShellNavItem(
      label: 'Products',
      icon: Icons.inventory_2_rounded,
      route: AppRoutes.products,
    ),
    ShellNavItem(
      label: 'Sales',
      icon: Icons.point_of_sale_outlined,
      route: AppRoutes.sales,
    ),
    ShellNavItem(label: 'HR', icon: Icons.badge_outlined, route: AppRoutes.hr),
    ShellNavItem(
      label: 'Users',
      icon: Icons.manage_accounts_outlined,
      route: AppRoutes.users,
    ),
    ShellNavItem(
      label: 'Account',
      icon: Icons.person_outline,
      route: AppRoutes.account,
    ),
  ];

  static const List<ShellNavItem> _mobileNavItems = [
    ShellNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.dashboard,
    ),
    ShellNavItem(
      label: 'POS',
      icon: Icons.groups_rounded,
      route: AppRoutes.pos,
    ),
    ShellNavItem(
      label: 'Products',
      icon: Icons.inventory_2_rounded,
      route: AppRoutes.products,
    ),
    ShellNavItem(
      label: 'Sales',
      icon: Icons.point_of_sale_outlined,
      route: AppRoutes.sales,
    ),
    ShellNavItem(
      label: 'Account',
      icon: Icons.person_outline,
      route: AppRoutes.account,
    ),
  ];

  void _navigateTo(BuildContext context, String route) {
    if (route == GoRouterState.of(context).uri.path) {
      return;
    }

    if (!_isDesktop(context) &&
        _scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }

    context.go(route);
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
  }

  String _pageTitleFor(String currentLocation) {
    switch (currentLocation) {
      case AppRoutes.dashboard:
        return 'Dashboard';
      case AppRoutes.inventory:
        return 'Inventory';
      case AppRoutes.sales:
        return 'Sales';
      case AppRoutes.pos:
        return 'Point of Sale';
      case AppRoutes.customers:
        return 'Customers';
      case AppRoutes.customerNew:
        return 'New Customer';
      case AppRoutes.products:
        return 'Product Catalogue';
      case AppRoutes.productNew:
        return 'New Product';
      case AppRoutes.hr:
        return 'HR Management';
      case AppRoutes.hrEmployeeNew:
        return 'Employee Details';
      case AppRoutes.hrShiftNew:
        return 'Shift Details';
      case AppRoutes.hrEmployeeShiftNew:
        return 'Shift Assignment';
      case AppRoutes.users:
        return 'User Management';
      case AppRoutes.account:
        return 'Account';
      default:
        return 'Workspace';
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionService = ref.watch(permissionServiceProvider);
    final role = ref.watch(roleProvider);

    final currentLocation = GoRouterState.of(context).uri.path;
    final isDesktop = _isDesktop(context);

    final sidebarItems = _sidebarItems.where((item) {
      return item.route == AppRoutes.account ||
          permissionService.canAccess(role: role, route: item.route);
    }).toList();

    final mobileNavItems = _mobileNavItems.where((item) {
      return item.route == AppRoutes.account ||
          permissionService.canAccess(role: role, route: item.route);
    }).toList();

    final selectedMobileIndex = mobileNavItems.indexWhere(
      (item) => item.route == currentLocation,
    );

    String roleAbbreviation = 'VW';
    String roleLabel = 'Viewer';
    if (role != null) {
      roleLabel = role.label;
      if (role == UserRole.admin) {
        roleAbbreviation = 'AD';
      } else if (role == UserRole.operations) {
        roleAbbreviation = 'OP';
      } else if (role == UserRole.sales) {
        roleAbbreviation = 'SL';
      } else if (role == UserRole.hr) {
        roleAbbreviation = 'HR';
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: _SidebarPanel(
                  compact: false,
                  items: sidebarItems,
                  selectedRoute: currentLocation,
                  roleAbbreviation: roleAbbreviation,
                  roleLabel: roleLabel,
                  onNavigate: (route) => _navigateTo(context, route),
                  onLogout: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (isDesktop)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _isSidebarCollapsed
                    ? _collapsedSidebarWidth
                    : _expandedSidebarWidth,
                child: _SidebarPanel(
                  compact: _isSidebarCollapsed,
                  items: sidebarItems,
                  selectedRoute: currentLocation,
                  roleAbbreviation: roleAbbreviation,
                  roleLabel: roleLabel,
                  onToggleCollapse: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  onNavigate: (route) => _navigateTo(context, route),
                  onLogout: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: _pageTitleFor(currentLocation),
                    isDesktop: isDesktop,
                    isSidebarCollapsed: _isSidebarCollapsed,
                    onMenuPressed: isDesktop
                        ? () {
                            setState(() {
                              _isSidebarCollapsed = !_isSidebarCollapsed;
                            });
                          }
                        : () => _scaffoldKey.currentState?.openDrawer(),
                    onAccountPressed: () =>
                        _navigateTo(context, AppRoutes.account),
                    onLogout: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(AppRoutes.login);
                      }
                    },
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop || mobileNavItems.isEmpty
          ? null
          : _MobileNavigationBar(
              items: mobileNavItems,
              selectedIndex: selectedMobileIndex < 0 ? 0 : selectedMobileIndex,
              onTap: (index) =>
                  _navigateTo(context, mobileNavItems[index].route),
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isDesktop,
    required this.isSidebarCollapsed,
    required this.onMenuPressed,
    required this.onAccountPressed,
    required this.onLogout,
  });

  final String title;
  final bool isDesktop;
  final bool isSidebarCollapsed;
  final VoidCallback onMenuPressed;
  final VoidCallback onAccountPressed;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: isDesktop
                ? (isSidebarCollapsed ? 'Expand left panel' : 'Hide left panel')
                : 'Open navigation',
            onPressed: onMenuPressed,
            icon: Icon(
              isDesktop
                  ? (isSidebarCollapsed ? Icons.chevron_right : Icons.menu_open)
                  : Icons.menu,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Enterprise workspace',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          if (isDesktop)
            Container(
              width: 360,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products, SKU or category...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 10),
                ),
              ),
            ),
          if (isDesktop) const SizedBox(width: 18),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.grey.shade700,
                ),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onAccountPressed,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade600,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          if (isDesktop)
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              onSelected: (value) async {
                if (value == 'account') {
                  onAccountPressed();
                }
                if (value == 'logout') {
                  await onLogout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(value: 'account', child: Text('Account')),
                PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
              ],
              child: Icon(Icons.more_vert, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.compact,
    required this.items,
    required this.selectedRoute,
    required this.roleAbbreviation,
    required this.roleLabel,
    required this.onNavigate,
    required this.onLogout,
    this.onToggleCollapse,
  });

  final bool compact;
  final List<ShellNavItem> items;
  final String selectedRoute;
  final String roleAbbreviation;
  final String roleLabel;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 18,
              20,
              compact ? 12 : 18,
              18,
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 44 : 52,
                  height: compact ? 44 : 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alpha Suite Pro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                        const Text(
                          'Enterprise admin console',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onToggleCollapse != null)
                    IconButton(
                      tooltip: 'Hide left panel',
                      onPressed: onToggleCollapse,
                      icon: const Icon(Icons.chevron_left),
                    ),
                ],
                if (compact) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'ERP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          tooltip: 'Expand left panel',
                          onPressed: onToggleCollapse,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: items
                  .map(
                    (item) => _SidebarItem(
                      item: item,
                      compact: compact,
                      isSelected: item.route == selectedRoute,
                      onTap: () => onNavigate(item.route),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 18,
              12,
              compact ? 10 : 18,
              20,
            ),
            child: compact
                ? Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo.shade600,
                        child: Text(
                          roleAbbreviation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: onLogout,
                        icon: Icon(
                          Icons.logout_rounded,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.indigo.shade600,
                          child: Text(
                            roleAbbreviation,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'v2.4.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: onLogout,
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
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
    required this.compact,
    required this.isSelected,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool compact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: compact ? 0 : 4, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 14,
          vertical: 2,
        ),
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade600,
        ),
        title: compact
            ? null
            : Text(
                item.label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.indigo.shade700
                      : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
        onTap: onTap,
        horizontalTitleGap: compact ? 0 : 12,
      ),
    );

    if (!compact) {
      return tile;
    }

    return Tooltip(message: item.label, child: tile);
  }
}

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<ShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}
