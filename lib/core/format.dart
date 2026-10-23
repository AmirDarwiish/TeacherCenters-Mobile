import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class _Cairo {
  static final tz.Location location = _initialize();
  static tz.Location _initialize() {
    data.initializeTimeZones();
    return tz.getLocation('Africa/Cairo');
  }
}

DateTime cairoDate(DateTime value) =>
    tz.TZDateTime.from(value, _Cairo.location);
String arDigits(Object? value) => '${value ?? '—'}'.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);
String arNumber(Object? value) {
  final n = value is num ? value : num.tryParse('$value');
  return n == null
      ? arDigits(value)
      : arDigits(
          NumberFormat(
            '#,##0.##',
            'ar_EG',
          ).format(n).replaceAll(',', '٬').replaceAll('.', '٫'),
        );
}

String money(Object? value) => '${arNumber(value)} ج.م';
String cairoWhen(Object? value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null
      ? '—'
      : arDigits(
          DateFormat('EEE d MMM · h:mm a', 'ar_EG').format(cairoDate(parsed)),
        );
}
