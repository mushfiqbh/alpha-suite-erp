import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/sales_chart.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/bottom_nav.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      body: Column(
        children: [
          _AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingHeader(),
                  const SizedBox(height: 28),
                  _KpiGrid(),
                  const SizedBox(height: 24),
                  const SalesChartWidget(),
                  const SizedBox(height: 24),
                  const ActivityFeedWidget(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      floatingActionButton: _FabButton(),
    );
  }
}

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0x20E2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3525CD).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF3525CD).withOpacity(0.2),
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?auto=compress&cs=tinysrgb&w=64&h=64&dpr=2',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'SmartERP Pro',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: const Color(0xFF151C27),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 22,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Alex',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: const Color(0xFF151C27),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's what's happening across your enterprise today.",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF464555),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCardWidget(
                title: 'TOTAL SALES',
                value: '\$124,000',
                description: '+12% this month',
                descriptionColor: const Color(0xFF006C49),
                icon: _SalesIcon(),
                trendWidget: _TrendArrow(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: KpiCardWidget(
                title: 'REVENUE',
                value: '\$89,000',
                description: 'Target: \$100,000',
                descriptionColor: const Color(0xFF464555),
                icon: _RevenueIcon(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: KpiCardWidget(
                title: 'EMPLOYEES',
                value: '156',
                description: 'Active across 4 locations',
                descriptionColor: const Color(0xFF464555),
                icon: _EmployeesIcon(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: KpiCardWidget(
                title: 'LOW STOCK',
                value: '12',
                description: 'Critical alerts',
                descriptionColor: const Color(0xFF684000),
                icon: _LowStockIcon(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SalesIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.trending_up_rounded,
        size: 16,
        color: Color(0xFF2E7D32),
      ),
    );
  }
}

class _RevenueIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.account_balance_wallet_outlined,
        size: 16,
        color: Color(0xFF6A1B9A),
      ),
    );
  }
}

class _EmployeesIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.people_outline_rounded,
        size: 16,
        color: Color(0xFF1565C0),
      ),
    );
  }
}

class _LowStockIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: Color(0xFFF57F17),
      ),
    );
  }
}

class _TrendArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.arrow_upward_rounded,
      size: 14,
      color: Color(0xFF006C49),
    );
  }
}

class _FabButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFF3525CD),
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 24),
    );
  }
}
