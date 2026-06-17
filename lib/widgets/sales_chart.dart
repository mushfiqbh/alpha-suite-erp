import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/sales_providers.dart';

/// Range toggle for the chart. `yearly` aggregates the last 12 months;
/// `monthly` aggregates the last 30 days into roughly 4 buckets.
enum _ChartRange { yearly, monthly }

class SalesChartWidget extends ConsumerStatefulWidget {
  const SalesChartWidget({super.key});

  @override
  ConsumerState<SalesChartWidget> createState() => _SalesChartWidgetState();
}

class _SalesChartWidgetState extends ConsumerState<SalesChartWidget> {
  _ChartRange _activeRange = _ChartRange.yearly;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(recentSalesOrdersProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7C4D8).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'বিক্রয় কর্মক্ষমতা',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF151C27),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'মাসিক আয় ও প্রবৃদ্ধির ধারা',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF464555),
                    ),
                  ),
                ],
              ),
              Row(
                children: _ChartRange.values.map((range) {
                  final label = range == _ChartRange.yearly
                      ? 'বার্ষিক'
                      : 'মাসিক';
                  final isActive = _activeRange == range;
                  return GestureDetector(
                    onTap: () => setState(() => _activeRange = range),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFE7EEFE)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.6,
                          color: isActive
                              ? const Color(0xFF3525CD)
                              : const Color(0xFF151C27),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ordersAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3525CD),
                ),
              ),
            ),
            error: (error, _) => SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'বিক্রয় তথ্য লোড করা যায়নি',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF464555),
                  ),
                ),
              ),
            ),
            data: (orders) {
              final series = _activeRange == _ChartRange.yearly
                  ? _aggregateLast12Months(orders)
                  : _aggregateLast30Days(orders);
              return _ChartBody(series: series);
            },
          ),
        ],
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.series});

  final _ChartSeries series;

  @override
  Widget build(BuildContext context) {
    if (series.spots.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'এখনো কোনো বিক্রয় রেকর্ড করা হয়নি',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF464555),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x0D3525CD), Color(0x003525CD)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (series.spots.length - 1).toDouble(),
                minY: 0,
                maxY: series.maxValue,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF3525CD),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${series.tooltipLabel(spot.x.toInt())}\n'
                          '৳${_formatK(spot.y)}',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: series.spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: const Color(0xFF3525CD),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF3525CD).withValues(alpha: 0.15),
                          const Color(0xFF3525CD).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3525CD),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.currentLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '৳${_formatK(series.currentValue)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

/// Compact, dependency-free aggregator that buckets orders into evenly-spaced
/// chart spots. Holds a list of spots plus the labels rendered by the tooltip
/// and the "current" badge.
class _ChartSeries {
  const _ChartSeries({
    required this.spots,
    required this.tooltipLabels,
    required this.currentLabel,
    required this.currentValue,
    required this.maxValue,
  });

  final List<FlSpot> spots;
  final List<String> tooltipLabels;
  final String currentLabel;
  final double currentValue;
  final double maxValue;

  String tooltipLabel(int index) {
    if (index < 0 || index >= tooltipLabels.length) return '';
    return tooltipLabels[index];
  }
}

_ChartSeries _aggregateLast12Months(List<SalesOrderRecord> orders) {
  final now = DateTime.now();
  final buckets = List<double>.filled(12, 0);
  final labels = List<String>.generate(12, (i) {
    final month = DateTime(now.year, now.month - (11 - i));
    return _monthAbbr(month.month);
  });

  for (final order in orders) {
    final monthsAgo =
        (now.year - order.orderDate.year) * 12 +
        (now.month - order.orderDate.month);
    if (monthsAgo < 0 || monthsAgo > 11) continue;
    final index = 11 - monthsAgo;
    buckets[index] += order.grandTotal;
  }

  final maxRaw = buckets.fold<double>(0, (m, v) => v > m ? v : m);
  final maxValue = maxRaw <= 0 ? 1.0 : maxRaw * 1.2;

  return _ChartSeries(
    spots: [
      for (var i = 0; i < buckets.length; i++) FlSpot(i.toDouble(), buckets[i]),
    ],
    tooltipLabels: labels,
    currentLabel: labels.last,
    currentValue: buckets.last,
    maxValue: maxValue,
  );
}

_ChartSeries _aggregateLast30Days(List<SalesOrderRecord> orders) {
  final now = DateTime.now();
  // Four roughly 7-day buckets: 21-30d, 14-21d, 7-14d, 0-7d.
  final buckets = List<double>.filled(4, 0);
  final labels = <String>['সপ্তাহ ১', 'সপ্তাহ ২', 'সপ্তাহ ৩', 'সপ্তাহ ৪'];

  for (final order in orders) {
    final diff = now.difference(order.orderDate).inDays;
    if (diff < 0 || diff >= 28) continue;
    // Newest week first → index 3; oldest → index 0.
    final index = 3 - (diff ~/ 7);
    buckets[index] += order.grandTotal;
  }

  final maxRaw = buckets.fold<double>(0, (m, v) => v > m ? v : m);
  final maxValue = maxRaw <= 0 ? 1.0 : maxRaw * 1.2;

  return _ChartSeries(
    spots: [
      for (var i = 0; i < buckets.length; i++) FlSpot(i.toDouble(), buckets[i]),
    ],
    tooltipLabels: labels,
    currentLabel: labels.last,
    currentValue: buckets.last,
    maxValue: maxValue,
  );
}

String _monthAbbr(int month) {
  const names = <String>[
    'জানু',
    'ফেব্রু',
    'মার্চ',
    'এপ্রি',
    'মে',
    'জুন',
    'জুলা',
    'আগ',
    'সেপ্টে',
    'অক্টো',
    'নভে',
    'ডিসে',
  ];
  return names[(month - 1).clamp(0, 11)];
}

String _formatK(double value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
  }
  return value.toStringAsFixed(0);
}
