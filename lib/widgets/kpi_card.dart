import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KpiCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final Color descriptionColor;
  final Widget icon;
  final Widget? trendWidget;

  const KpiCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.descriptionColor,
    required this.icon,
    this.trendWidget,
  });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.6,
                  color: const Color(0xFF464555),
                ),
              ),
              icon,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: const Color(0xFF151C27),
            ),
          ),
          const SizedBox(height: 4),
          if (trendWidget != null)
            Row(
              children: [
                trendWidget!,
                const SizedBox(width: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: descriptionColor,
                  ),
                ),
              ],
            )
          else
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: descriptionColor,
              ),
            ),
        ],
      ),
    );
  }
}
