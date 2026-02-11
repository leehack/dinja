import 'package:dinja/dinja.dart';

void main() {
  // A representative Mistral/Llama chat template.
  // Handles:
  // - System prompt
  // - User/Assistant loop
  // - [INST] markers
  // - BOS/EOS tokens
  const templateSource = '''
{{ bos_token }}
{% for message in messages %}
    {% if message['role'] == 'user' %}
        [INST] {{ message['content'] }} [/INST]
    {% elif message['role'] == 'assistant' %}
        {{ message['content'] }} {{ eos_token }}
    {% elif message['role'] == 'system' %}
        <<SYS>> {{ message['content'] }} <</SYS>>
    {% endif %}
{% endfor %}
''';

  final template = Template(templateSource);

  final data = {
    'bos_token': '<s>',
    'eos_token': '</s>',
    'messages': [
      {'role': 'system', 'content': 'You are a helpful assistant.'},
      {'role': 'user', 'content': 'What is the capital of France?'},
      {'role': 'assistant', 'content': 'Paris.'},
      {'role': 'user', 'content': 'And Germany?'},
    ],
  };

  try {
    final output = template.render(data);
    print('--- Rendered Output ---');
    print(output);
    print('-----------------------');
  } catch (e) {
    print('Error rendering template: $e');
  }
}
