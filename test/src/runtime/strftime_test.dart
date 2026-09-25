import 'package:dinja/dinja.dart';
import 'package:dinja/src/runtime/strftime.dart';
import 'package:test/test.dart';

void main() {
  group('strftime', () {
    // glibc 2.41 strftime output with TZ=UTC. llama.cpp 7fe450e1's
    // strftime_now calls C strftime.
    const expected = {
      1790341509: {
        '%d %b %Y': '25 Sep 2026',
        '%B %d, %Y': 'September 25, 2026',
        '%a %A %h': 'Fri Friday Sep',
        '%c': 'Fri Sep 25 13:05:09 2026',
        '%x %X': '09/25/26 13:05:09',
        '%D %F %T %R %r': '09/25/26 2026-09-25 13:05:09 13:05 01:05:09 PM',
        '%e|%k|%l|%I|%p|%P': '25|13| 1|01|PM|pm',
        '%j %U %W %V %G %g %u %w': '268 38 38 39 2026 26 5 5',
        '%C %y %Y': '20 26 2026',
        '%%': '%',
        '%-d|%-m|%_m|%05e|%-e': '25|9| 9|00025|25',
        '%^a %^B %#b %#p %#P %^p %#Z': 'FRI SEPTEMBER SEP pm pm PM utc',
        '%10B|%-10d|%_5H|%010Y|%3z':
            ' September|        25|   13|0000002026|  +0000',
        '%Ey|%EY|%EC|%Ex|%Ec|%EX|%Od|%Oe|%OH|%Om|%OM|%OS|%Ou|%Ow|%Oy|%OV':
            '26|2026|20|09/25/26|Fri Sep 25 13:05:09 2026|13:05:09|25|25|13|09|05|09|5|5|26|39',
        '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%E%': '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%',
        '%Q|%+|%i': '%Q|%+|%i',
        '%': '%',
        'x%': 'x%',
        '%-': '%-',
        '%z %Z %s': '+0000 UTC 1790341509',
        '%p': 'PM',
      },
      1609459200: {
        '%d %b %Y': '01 Jan 2021',
        '%B %d, %Y': 'January 01, 2021',
        '%a %A %h': 'Fri Friday Jan',
        '%c': 'Fri Jan  1 00:00:00 2021',
        '%x %X': '01/01/21 00:00:00',
        '%D %F %T %R %r': '01/01/21 2021-01-01 00:00:00 00:00 12:00:00 AM',
        '%e|%k|%l|%I|%p|%P': ' 1| 0|12|12|AM|am',
        '%j %U %W %V %G %g %u %w': '001 00 00 53 2020 20 5 5',
        '%C %y %Y': '20 21 2021',
        '%%': '%',
        '%-d|%-m|%_m|%05e|%-e': '1|1| 1|00001|1',
        '%^a %^B %#b %#p %#P %^p %#Z': 'FRI JANUARY JAN am am AM utc',
        '%10B|%-10d|%_5H|%010Y|%3z':
            '   January|         1|    0|0000002021|  +0000',
        '%Ey|%EY|%EC|%Ex|%Ec|%EX|%Od|%Oe|%OH|%Om|%OM|%OS|%Ou|%Ow|%Oy|%OV':
            '21|2021|20|01/01/21|Fri Jan  1 00:00:00 2021|00:00:00|01| 1|00|01|00|00|5|5|21|53',
        '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%E%': '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%',
        '%Q|%+|%i': '%Q|%+|%i',
        '%': '%',
        'x%': 'x%',
        '%-': '%-',
        '%z %Z %s': '+0000 UTC 1609459200',
        '%p': 'AM',
      },
      1735689599: {
        '%d %b %Y': '31 Dec 2024',
        '%B %d, %Y': 'December 31, 2024',
        '%a %A %h': 'Tue Tuesday Dec',
        '%c': 'Tue Dec 31 23:59:59 2024',
        '%x %X': '12/31/24 23:59:59',
        '%D %F %T %R %r': '12/31/24 2024-12-31 23:59:59 23:59 11:59:59 PM',
        '%e|%k|%l|%I|%p|%P': '31|23|11|11|PM|pm',
        '%j %U %W %V %G %g %u %w': '366 52 53 01 2025 25 2 2',
        '%C %y %Y': '20 24 2024',
        '%%': '%',
        '%-d|%-m|%_m|%05e|%-e': '31|12|12|00031|31',
        '%^a %^B %#b %#p %#P %^p %#Z': 'TUE DECEMBER DEC pm pm PM utc',
        '%10B|%-10d|%_5H|%010Y|%3z':
            '  December|        31|   23|0000002024|  +0000',
        '%Ey|%EY|%EC|%Ex|%Ec|%EX|%Od|%Oe|%OH|%Om|%OM|%OS|%Ou|%Ow|%Oy|%OV':
            '24|2024|20|12/31/24|Tue Dec 31 23:59:59 2024|23:59:59|31|31|23|12|59|59|2|2|24|01',
        '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%E%': '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%',
        '%Q|%+|%i': '%Q|%+|%i',
        '%': '%',
        'x%': 'x%',
        '%-': '%-',
        '%z %Z %s': '+0000 UTC 1735689599',
        '%p': 'PM',
      },
      1767517200: {
        '%d %b %Y': '04 Jan 2026',
        '%B %d, %Y': 'January 04, 2026',
        '%a %A %h': 'Sun Sunday Jan',
        '%c': 'Sun Jan  4 09:00:00 2026',
        '%x %X': '01/04/26 09:00:00',
        '%D %F %T %R %r': '01/04/26 2026-01-04 09:00:00 09:00 09:00:00 AM',
        '%e|%k|%l|%I|%p|%P': ' 4| 9| 9|09|AM|am',
        '%j %U %W %V %G %g %u %w': '004 01 00 01 2026 26 7 0',
        '%C %y %Y': '20 26 2026',
        '%%': '%',
        '%-d|%-m|%_m|%05e|%-e': '4|1| 1|00004|4',
        '%^a %^B %#b %#p %#P %^p %#Z': 'SUN JANUARY JAN am am AM utc',
        '%10B|%-10d|%_5H|%010Y|%3z':
            '   January|         4|    9|0000002026|  +0000',
        '%Ey|%EY|%EC|%Ex|%Ec|%EX|%Od|%Oe|%OH|%Om|%OM|%OS|%Ou|%Ow|%Oy|%OV':
            '26|2026|20|01/04/26|Sun Jan  4 09:00:00 2026|09:00:00|04| 4|09|01|00|00|7|0|26|01',
        '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%E%': '%Eb|%OY|%Ea|%Ed|%OF|%Oc|%',
        '%Q|%+|%i': '%Q|%+|%i',
        '%': '%',
        'x%': 'x%',
        '%-': '%-',
        '%z %Z %s': '+0000 UTC 1767517200',
        '%p': 'AM',
      },
    };
    expected.forEach((seconds, cases) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      cases.forEach((format, output) {
        test('formats "$format" at $seconds', () {
          expect(strftime(format, time), output);
        });
      });
    });
  });

  group('strftime_now', () {
    test('formats the current local time in the C locale', () {
      const months = [
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
      final before = DateTime.now();
      final output = Template('{{ strftime_now("%B %Y") }}').render();
      final after = DateTime.now();
      expect(
        output,
        anyOf(
          '${months[before.month - 1]} ${before.year}',
          '${months[after.month - 1]} ${after.year}',
        ),
      );
    });

    test('accepts a 99-byte result', () {
      expect(Template('{{ strftime_now("%99Y") }}').render(), hasLength(99));
    });

    // llama.cpp 7fe450e1 throws for each of these.
    for (final source in [
      '{{ strftime_now() }}',
      '{{ strftime_now(1) }}',
      '{{ strftime_now("") }}',
      '{{ strftime_now("%100Y") }}',
      '{{ strftime_now("%A %A %A %A %A %A %A %A %A %A %A %A %A %A %A") }}',
    ]) {
      test('throws for $source', () {
        expect(() => Template(source).render(), throwsException);
      });
    }
  });
}
