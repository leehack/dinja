import 'package:dinja/dinja.dart';

void main() {
  print('--- Security / Auto-Escaping Example ---');

  const templateSource = 'Hello {{ name }}!';
  final template = Template(templateSource);

  final unsafeInput = '<script>alert("xss")</script>';

  // 1. A plain String is template text and is not escaped
  print('1. Plain string (not escaped):');
  print(template.render({'name': unsafeInput}));

  // 2. User input marked with JinjaString.user is escaped
  print('\n2. User input (auto-escaped):');
  print(template.render({'name': JinjaString.user(unsafeInput)}));

  // 3. Marked user input as safe (if you trust the source)
  print('\n3. User input marked as safe (raw html):');
  print(template.render({'name': JinjaString.user(unsafeInput).markSafe()}));
}
