import 'package:dinja/dinja.dart';

void main() {
  final template = Template('Hello {{ name }}!');
  print(template.render({'name': 'World'}));
}
