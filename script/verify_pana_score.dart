import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final reportFile = File('pana_report.json');
  if (!reportFile.existsSync()) {
    print('Error: pana_report.json not found.');
    exit(1);
  }

  final report = jsonDecode(reportFile.readAsStringSync());
  final scores = report['scores'];
  final grantedPoints = scores['grantedPoints'] as int;
  final maxPoints = scores['maxPoints'] as int;

  // Default threshold is 140, but can be overridden by argument
  int threshold = 140;
  if (args.isNotEmpty) {
    threshold = int.tryParse(args[0]) ?? 140;
  }

  print('Pana Score: $grantedPoints / $maxPoints');

  if (grantedPoints < threshold) {
    print('Error: Score is below the threshold of $threshold.');
    exit(1);
  }

  print('Success: Score meets the threshold.');
}
