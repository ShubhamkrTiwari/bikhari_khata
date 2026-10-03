import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final NumberFormat _currencyWhole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final DateFormat _date = DateFormat('d MMM yyyy');
final DateFormat _dateTime = DateFormat('d MMM yyyy • h:mm a');

String formatMoney(double value) =>
    value == value.roundToDouble()
        ? _currencyWhole.format(value)
        : _currency.format(value);

String signedMoney(double value) {
  final formatted = formatMoney(value.abs());
  if (value > 0.009) return '+$formatted';
  if (value < -0.009) return '-$formatted';
  return formatted;
}

String formatDate(DateTime date) => _date.format(date);

String formatDateTime(DateTime date) => _dateTime.format(date);
