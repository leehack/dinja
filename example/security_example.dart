import 'package:dinja/dinja.dart';

void main() {
  print('--- Security / Auto-Escaping Example ---');

  const templateSource = 'Hello {{ name }}!';
  final template = Template(templateSource);

  // 1. Safe input
  print('1. Safe Input:');
  print(template.render({'name': 'World'}));

  // 2. Unsafe input (should be escaped)
  print('\n2. Unsafe input (auto-escaped):');
  final unsafeInput = '<script>alert("xss")</script>';
  final output = template.render({'name': unsafeInput});
  print(output);

  // 3. Mark as safe (if you trust the source)
  print('\n3. Marked as safe (raw html):');
  // Use JinjaString.from with isSafe: true to mark content as trusted
  final safeString = JinjaString.from(unsafeInput, isSafe: true);

  // Pass the JinjaString directly to render
  final outputSafe = template.render({'name': safeString});
  print(outputSafe);
}
