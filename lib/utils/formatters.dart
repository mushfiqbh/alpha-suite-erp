/// Lightweight formatters shared across the app so screens don't have to
/// hand-roll `toStringAsFixed(2)` / manual date padding on every label.
///
/// Kept dependency-free to match the rest of the project (no `intl` package).
library;

/// Formats numeric values as a fixed two-decimal money string.
///
/// Mirrors the `_money` helper used in `SalesService` so the POS, sales list,
/// and reports all render totals the same way.
class MoneyFormatter {
  const MoneyFormatter({this.symbol = '৳', this.decimals = 2});

  /// Currency symbol prepended to the formatted value. Defaults to `$`.
  final String symbol;

  /// Number of decimal places to keep.
  final int decimals;

  String format(num value) {
    final fixed = value.toStringAsFixed(decimals);
    return symbol.isEmpty ? fixed : '$symbol$fixed';
  }
}

/// Formats a [DateTime] as a `yyyy-MM-dd` string, matching the wire format
/// used by `SalesService._formatDate` when posting to Postgres.
class DateTimeFormatter {
  const DateTimeFormatter({this.separator = '-'});

  /// Separator placed between year, month, and day components.
  final String separator;

  String format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$separator$m$separator$d';
  }
}
