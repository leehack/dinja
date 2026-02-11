import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('coverage/lcov.info not found');
    return;
  }

  final lines = file.readAsLinesSync();
  int totalLines = 0;
  int hitLines = 0;

  for (final line in lines) {
    if (line.startsWith('LF:')) {
      totalLines += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hitLines += int.parse(line.substring(3));
    }
  }

  if (totalLines == 0) {
    print('No lines found');
  } else {
    final percentage = (hitLines / totalLines) * 100;
    print(
      'Coverage: ${percentage.toStringAsFixed(2)}% ($hitLines/$totalLines)',
    );
  }
}
