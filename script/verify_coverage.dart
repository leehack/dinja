import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart verify_coverage.dart <lcov_file> <min_percent>');
    exit(1);
  }

  final lcovPath = args[0];
  final minPercent = double.parse(args[1]);

  final file = File(lcovPath);
  if (!file.existsSync()) {
    print('Error: LCOV file not found at $lcovPath');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  int totalLines = 0;
  int hitLines = 0;

  for (final line in lines) {
    if (line.startsWith('DA:')) {
      // DA:<line_number>,<execution_count>
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        totalLines++;
        if (int.parse(parts[1]) > 0) {
          hitLines++;
        }
      }
    }
  }

  if (totalLines == 0) {
    print('Error: No lines found in coverage report.');
    exit(1);
  }

  final coverage = (hitLines / totalLines) * 100;
  print(
    'Coverage: ${coverage.toStringAsFixed(2)}% ($hitLines/$totalLines lines)',
  );

  if (coverage < minPercent) {
    print('Failure: Coverage is below the required threshold of $minPercent%.');
    exit(1);
  }

  print('Success: Coverage meets the requirement.');
}
