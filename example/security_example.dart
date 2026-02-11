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
  final safeString = JinjaString.from(unsafeInput, isSafe: true);
  // Or simply passing it as a trusted string if your logic allows
  // Here we simulate passing a marked safe string
  final outputSafe = template.render({
    'name': JinjaStringValue(safeString).toDart(),
  });
  print('Matches safe output: ${outputSafe == unsafeInput}');
  // Note: toDart() unwraps to string, so if we want to pass the wrapper we need to use
  // custom mechanics or just reliance on the fact that strings are inputs by default.
  // Wait, `render` converts values using `val()`.
  // `val()` wraps strings in `JinjaString.user(v)`.
  // If we want to pass a safe string, we should likely pass a JinjaString directly if allowed?
  // Let's check `val()` implementation in `value.dart`.
  // It handles `JinjaString`!

  final outputTrusted = template.render({'name': safeString});
  print(outputTrusted);
}
