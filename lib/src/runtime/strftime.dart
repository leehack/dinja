/// C `strftime` in the C locale, as glibc implements it, which llama.cpp's
/// `strftime_now` calls.
///
/// Supports glibc's conversions, the `E` and `O` modifiers, the `_`, `-`,
/// `0`, `^` and `#` flags and field widths. An unknown conversion is copied
/// to the output, as glibc does.
///
/// `%Z` is [DateTime.timeZoneName], whose format depends on the platform: on
/// the web it is the browser's name for the zone, such as
/// `Eastern Daylight Time` where glibc gives `EDT`.
String strftime(String format, DateTime time) => _Strftime(format, time).run();

const _weekdays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _Strftime {
  _Strftime(this.format, this.time);

  final String format;
  final DateTime time;
  final StringBuffer out = StringBuffer();

  // State of the conversion being formatted.
  String pad = '';
  int width = -1;
  bool toUpper = false;
  bool toLower = false;

  int get _wday => time.weekday % 7;

  int get _yday => DateTime.utc(
    time.year,
    time.month,
    time.day,
  ).difference(DateTime.utc(time.year)).inDays;

  int get _hour12 => time.hour % 12 == 0 ? 12 : time.hour % 12;

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static String _upper(String s) =>
      s.replaceAllMapped(RegExp('[a-z]'), (m) => m[0]!.toUpperCase());

  static String _lower(String s) =>
      s.replaceAllMapped(RegExp('[A-Z]'), (m) => m[0]!.toLowerCase());

  void _add(String s) {
    final delta = width - s.length;
    if (delta > 0) out.write((pad == '0' ? '0' : ' ') * delta);
    out.write(s);
  }

  void _cpy(String s) => _add(toLower ? _lower(s) : (toUpper ? _upper(s) : s));

  void _subformat(String subformat) {
    final s = strftime(subformat, time);
    _add(toUpper ? _upper(s) : s);
  }

  void _number(int minDigits, int value, {bool spacePad = false}) {
    if (spacePad && pad != '0' && pad != '-') pad = '_';
    final digits = minDigits > width ? minDigits : width;
    _signAndPadding(value.abs().toString(), value < 0, digits);
  }

  void _signAndPadding(String digitText, bool negative, int digits) {
    var number = negative ? '-$digitText' : digitText;
    if (pad != '-') {
      final padding = digits - number.length;
      if (padding > 0) {
        if (pad == '_') {
          out.write(' ' * padding);
          width = width > padding ? width - padding : 0;
        } else {
          if (negative) {
            out.write('-');
            number = digitText;
          }
          out.write('0' * padding);
          width = 0;
        }
      }
    }
    _cpy(number);
  }

  int _isoWeekDays(int yday, int wday) =>
      yday - (yday - wday + 4 + 378) % 7 + 3;

  static bool _isLeap(int y) => y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);

  String run() {
    var f = 0;
    while (f < format.length) {
      if (format[f] != '%') {
        out.write(format[f++]);
        continue;
      }
      pad = '';
      width = -1;
      toUpper = false;
      toLower = false;
      var changeCase = false;

      f++;
      while (f < format.length) {
        final c = format[f];
        if (c == '_' || c == '-' || c == '0') {
          pad = c;
        } else if (c == '^') {
          toUpper = true;
        } else if (c == '#') {
          changeCase = true;
        } else {
          break;
        }
        f++;
      }
      if (f < format.length && _isDigit(format[f])) {
        width = 0;
        while (f < format.length && _isDigit(format[f])) {
          width = width * 10 + format.codeUnitAt(f) - 48;
          if (width > 0x7fffffff) width = 0x7fffffff;
          f++;
        }
      }
      var modifier = '';
      if (f < format.length && (format[f] == 'E' || format[f] == 'O')) {
        modifier = format[f++];
      }

      // Copies the format from its last `%` up to [f], as glibc does.
      void badFormat() =>
          _cpy(format.substring(format.lastIndexOf('%', f), f + 1));

      if (f >= format.length) {
        // `%` at the end of the format, possibly after flags and modifiers.
        f--;
        badFormat();
        f++;
        continue;
      }

      final year = time.year;
      switch (format[f]) {
        case '%':
          modifier.isEmpty ? _add('%') : badFormat();
        case 'a':
        case 'A':
          if (modifier.isNotEmpty) {
            badFormat();
            break;
          }
          if (changeCase) {
            toUpper = true;
            toLower = false;
          }
          final name = _weekdays[_wday];
          _cpy(format[f] == 'a' ? name.substring(0, 3) : name);
        case 'b':
        case 'h':
        case 'B':
          if (changeCase) {
            toUpper = true;
            toLower = false;
          }
          if (modifier == 'E') {
            badFormat();
            break;
          }
          final name = _months[time.month - 1];
          _cpy(format[f] == 'B' ? name : name.substring(0, 3));
        case 'c':
          modifier == 'O' ? badFormat() : _subformat('%a %b %e %H:%M:%S %Y');
        case 'C':
          _number(1, year ~/ 100 - (year.remainder(100) < 0 ? 1 : 0));
        case 'x':
          modifier == 'O' ? badFormat() : _subformat('%m/%d/%y');
        case 'D':
          modifier.isEmpty ? _subformat('%m/%d/%y') : badFormat();
        case 'F':
          modifier.isEmpty ? _subformat('%Y-%m-%d') : badFormat();
        case 'd':
          modifier == 'E' ? badFormat() : _number(2, time.day);
        case 'e':
          modifier == 'E' ? badFormat() : _number(2, time.day, spacePad: true);
        case 'H':
          modifier == 'E' ? badFormat() : _number(2, time.hour);
        case 'I':
          modifier == 'E' ? badFormat() : _number(2, _hour12);
        case 'k':
          modifier == 'E' ? badFormat() : _number(2, time.hour, spacePad: true);
        case 'l':
          modifier == 'E' ? badFormat() : _number(2, _hour12, spacePad: true);
        case 'j':
          modifier == 'E' ? badFormat() : _number(3, _yday + 1);
        case 'M':
          modifier == 'E' ? badFormat() : _number(2, time.minute);
        case 'm':
          modifier == 'E' ? badFormat() : _number(2, time.month);
        case 'S':
          modifier == 'E' ? badFormat() : _number(2, time.second);
        case 'n':
          _add('\n');
        case 't':
          _add('\t');
        case 'P':
        case 'p':
          if (format[f] == 'P') toLower = true;
          if (changeCase) {
            toUpper = false;
            toLower = true;
          }
          _cpy(time.hour < 12 ? 'AM' : 'PM');
        case 'R':
          _subformat('%H:%M');
        case 'r':
          _subformat('%I:%M:%S %p');
        case 'T':
          _subformat('%H:%M:%S');
        case 'X':
          modifier == 'O' ? badFormat() : _subformat('%H:%M:%S');
        case 's':
          final seconds = (time.millisecondsSinceEpoch / 1000).floor();
          _signAndPadding(seconds.abs().toString(), seconds < 0, 1);
        case 'u':
          _number(1, (_wday + 6) % 7 + 1);
        case 'U':
          modifier == 'E' ? badFormat() : _number(2, (_yday - _wday + 7) ~/ 7);
        case 'W':
          modifier == 'E'
              ? badFormat()
              : _number(2, (_yday - (_wday + 6) % 7 + 7) ~/ 7);
        case 'w':
          modifier == 'E' ? badFormat() : _number(1, _wday);
        case 'V':
        case 'g':
        case 'G':
          if (modifier == 'E') {
            badFormat();
            break;
          }
          var isoYear = year;
          var days = _isoWeekDays(_yday, _wday);
          if (days < 0) {
            isoYear--;
            days = _isoWeekDays(
              _yday + 365 + (_isLeap(isoYear) ? 1 : 0),
              _wday,
            );
          } else {
            final d = _isoWeekDays(
              _yday - 365 - (_isLeap(year) ? 1 : 0),
              _wday,
            );
            if (d >= 0) {
              isoYear++;
              days = d;
            }
          }
          switch (format[f]) {
            case 'g':
              _number(2, isoYear % 100);
            case 'G':
              _number(1, isoYear);
            default:
              _number(2, days ~/ 7 + 1);
          }
        case 'Y':
          modifier == 'O' ? badFormat() : _number(1, year);
        case 'y':
          _number(2, year % 100);
        case 'Z':
          if (changeCase) {
            toUpper = false;
            toLower = true;
          }
          _cpy(time.timeZoneName);
        case 'z':
          var minutes = time.timeZoneOffset.inSeconds ~/ 60;
          _add(minutes < 0 ? '-' : '+');
          minutes = minutes.abs();
          _number(4, minutes ~/ 60 * 100 + minutes % 60);
        default:
          badFormat();
      }
      f++;
    }
    return out.toString();
  }
}
