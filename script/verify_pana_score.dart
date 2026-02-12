import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('pana_report.json');
  if (!file.existsSync()) {
    print('Error: pana_report.json not found.');
    exit(1);
  }

  final jsonString = file.readAsStringSync();
  final Map<String, dynamic> report = jsonDecode(jsonString);

  final scores = report['scores'] as Map<String, dynamic>?;
  if (scores == null) {
    print('Error: Could not find scores in pana report.');
    exit(1);
  }

  final grantedPoints = scores['grantedPoints'] as int?;
  final maxPoints = scores['maxPoints'] as int?;

  if (grantedPoints == null) {
    print('Error: Could not find grantedPoints in pana report.');
    exit(1);
  }

  print('Pana Score: $grantedPoints / ${maxPoints ?? "Unknown"}');

  if (grantedPoints < 160) {
    print(
      'Failure: Pana score $grantedPoints is below the required threshold of 160.',
    );
    exit(1);
  }

  print('Success: Pana score meets the requirement.');
}
