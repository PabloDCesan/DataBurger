import 'package:intl/intl.dart';

class MoneyFmt {
  // sin símbolo, solo números con locale es_AR
  static final NumberFormat _noSymbol =
      NumberFormat.currency(locale: 'es_AR', symbol: '');

  /// "$ 1.234,56"
  static String format(num value, {String symbol = r'$'}) {
    final numStr = _noSymbol.format(value).trim();
    return '$symbol $numStr';
  }

  /// "1.234,56" (por si necesitás sin símbolo)
  static String formatNoSymbol(num value) => _noSymbol.format(value).trim();
}
