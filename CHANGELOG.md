## Unreleased

- Fixed a `{% filter %}` block, and a filter on the output of a block `set`, a macro or `caller()`, getting `JinjaString.user` text already escaped: with `x = JinjaString.user('<b>')`, `{% filter upper %}{{ x }}{% endfilter %}` is now `&lt;B&gt;`, not `&LT;B&GT;`, and `{% filter length %}{{ x }}{% endfilter %}` is `3`, not `9`, as in llama.cpp. Input text is now escaped once, when the template outputs it. `| safe` on such output, `{% filter safe %}`, and `| safe` on text made from it or from other safe text escape the input in it, as Jinja2 with autoescape does; `{{ x | safe }}` still outputs `x` as is. A block whose output also contains `| safe` input text is still escaped before the filter runs, as `~` does.
- Fixed `tojson` and `join` dropping the input marking, so `JinjaString.user` text in their output was not escaped: `{{ {"k": x} | tojson }}` is now `{"k": "&lt;b&gt;"}` and `{{ [x, "<i>"] | join }}` is `&lt;b&gt;<i>`. Only input text is escaped, after JSON escaping, in values, dict keys and separators; the JSON's own quotes and template text are not. `tojson` output with input text in it is no longer safe (`is escaped`).
- Fixed input text being output unescaped by string indexing, `first`, `last`, `reverse`, `list` and `for` on a string, `split` and `rsplit` pieces, `strip`, `lstrip` and `rstrip` with characters, `truncate`, `str()`, `~`, `+` and `format` with a list or dict, `string`, `upper`, `lower`, `title`, `capitalize`, `trim`, `replace` and `indent` on a list or dict, `replace`, `indent` and `format` on text that is only partly input, input passed as a `replace` replacement, input dict keys in a `for` loop, and an input `strftime_now` format.
- Changed `replace` and `indent` on input text to leave the template text they add unescaped: `x | replace('b', '<i>')` is now `&lt;<i>&gt;`, not `&lt;&lt;i&gt;&gt;`, and `x | indent('> ', true)` no longer escapes `> `. Each character keeps the marking of the text it came from; llama.cpp marks all of the result as input when all of the source is.
- Fixed `| safe` text being escaped when passed to `format`, or to `replace` or `indent` on input text, sliced with a step or split by `unique`, and escaped twice when it held escaped input: `'{}'.format(x ~ (y | safe))` is now `&lt;b&gt;<i>`, not `&amp;lt;b&amp;gt;<i>`.
- Fixed member access on an undefined value giving a function, which printed as `<function NAME>` and was `defined`: for an undefined `y`, `{{ y.text }}` and `{{ y[0]['text'] }}` now print nothing and are not `defined`, as in llama.cpp. As in llama.cpp, `y.upper`, `y.length` and the other filters that llama.cpp gives undefined are functions returning an empty value (`y.length()` is `0`, `y.default(1)` is `1`) that print nothing, and calling any other member, such as `y.get()`, throws. Devstral Small 2507 no longer prints `<function text>` for an assistant turn without `content`. Also as in llama.cpp, Command R+ tool use renders an `object` parameter without `additionalProperties` as `Dict[str, Union[]]`, not `Dict[str, Any]`, and QwQ-32B throws for an assistant tool-call turn without `content` before the last turn.
- Changed a number subscript of none, as in `x[0]` or `x[0]['text']` for `x = none`, to throw `Cannot access property with non-string: got Integer`, as llama.cpp does; it gave undefined. Devstral Small 2507 with an assistant turn whose content is none now throws, as in llama.cpp.

## 1.2.0

- Rewrote the README and example around rendering a chat template, and updated the pubspec description and topics.
- Fixed `lstrip_blocks` keeping the indentation before a `{%` or `{#` on the line after a block tag, as in `{% if x %}\n    {% set y = 1 %}`. It is now removed, as in llama.cpp and Jinja2. Qwen3-Coder, GLM-4.6, GLM-4.7-Flash, MiniMax-M2, Nemotron-3-Nano and Command R7B prompts no longer contain stray spaces.
- Fixed `strftime_now` supporting only `%Y %m %d %H %M %S`. It now formats as llama.cpp does, with C `strftime` in the C locale as glibc implements it: every conversion (`%b`, `%B`, `%a`, `%c`, `%%` and the rest), flags and widths. Like llama.cpp, it throws without a string argument and when the result is empty or 100 bytes or longer.
- Fixed `continue` and `break` dropping what the loop pass had already rendered: `{% for i in [1, 2] %}{{ i }}{% continue %}{% endfor %}` is now `12`. A `for` loop's `else` block now runs when no pass finishes without `continue` or `break`, as in llama.cpp and Jinja2. Output rendered in a nested block before the signal is kept, as in Jinja2; llama.cpp drops it. Output captured by a block `set`, a `filter` block, a macro or a `caller()` body that the signal leaves is discarded, as in llama.cpp.
- Fixed input-marked values in a `for` loop, including its `else` block, being escaped twice: `{% for i in [1] %}{{ x }}{% endfor %}` with `x = JinjaString.user('<b>')` is now `&lt;b&gt;`.
- Fixed `caller()` rendering `None` for a body statement without output, such as `{% set %}` or a comment, and not escaping `JinjaString.user` values in the body.
- Fixed `select`, `reject`, `selectattr`, `rejectattr` and `unique` on none returning none, so `none | selectattr(...) | list` was `[None]`. They now return an empty list, as in llama.cpp. This fixes the functionary v3.1 prompt without tools. `default` now also replaces none, as in llama.cpp.
- Fixed macro keyword arguments binding by position, which rendered `greet(last='Smith', first='John')` with empty values and made `add(1, b=10)` throw. Arguments now bind positionally, then by name, then from defaults, as in llama.cpp and Jinja2, including `caller(...)` arguments in a `{% call %}` block. A missing required argument throws `Not enough arguments provided`, as in llama.cpp; an unknown keyword or a keyword repeating a positional argument throws, as in Jinja2.
- Fixed unary `-` and `+` failing to parse before anything but a number literal, as in `{{ -n }}`, `{{ items[:-n] }}` and `{{ not -n }}`. As in llama.cpp and Jinja2, they bind tighter than filters, tests and `**`: `-n|abs` is `(-n)|abs`.
- Fixed `min` and `max` with `attribute` returning the attribute value instead of the item, as Jinja2 does. `attribute` can also be the second positional argument.
- Added llama.cpp's numeric member access (`{{ items.0 }}`, `{{ {10: 'Bob'}.10 }}`), empty subscript (`a[]` is undefined), `int * str` repetition, string `indent` width (`indent('> ')`) and `str.format` with `{}` placeholders. Other `format` fields, such as `{0}`, `{name}`, `{{` and `{:>5}`, throw, as in llama.cpp.
- Added `BlankExpression` to `package:dinja/ast.dart` for the `a[]` subscript.
- Fixed the README and `example/security_example.dart` claiming that plain strings passed to `render` are escaped; only values wrapped in `JinjaString.user` are.
- Fixed template text containing `"        "` (eight spaces in double quotes) being deleted from the output.
- Fixed `indent` adding a newline to input that ends with one: `'foo\n'|indent` is now `foo\n`, as in llama.cpp and Jinja2. An empty string stays empty with `first=true`, as in llama.cpp.
- Changed tests that take an argument, such as `divisibleby`, `eq` and `in`, to throw when called without one, as llama.cpp and Jinja2 do. `a is divisibleby -a` is `(a is divisibleby) - a` in both, so it now throws instead of rendering `-2`.
- Changed `*` argument unpacking, as in `f(*items)`, to throw, as llama.cpp does. It used to pass the list as a single argument.
- Added the `format` filter as llama.cpp has it: it calls `str.format`, so `'{}-{}'|format(1, 2)` is `1-2`. Jinja2's `%`-style formatting is not supported: `'%s'|format(x)` returns `%s`.

## 1.1.1

- Fixed `tojson` to match llama.cpp: `json.dumps` spacing (`{"a": 1, "b": [1, 2]}`), non-ASCII kept unless `ensure_ascii=true`, floats formatted as C++ `%g` with 6 significant digits (`1.0` is `1`, `3.14159265` is `3.14159`), non-string keys converted to strings, and positional arguments read as `(ensure_ascii, indent, separators, sort_keys)`. A negative or non-integer `indent` now gives one-line output, and one separator sets only the item separator.
- Fixed printing a list, dict or tuple HTML-escaping its quotes: `{{ [1, '1'] }}` now prints `[1, '1']`. Input-marked items are still escaped.
- Fixed `-0.0` and numbers outside the 64-bit integer range passed to `render` becoming integers on the web; they are now floats, as on the VM. Other whole-number doubles are still integers on the web, where they are indistinguishable from `int`.
- Changed list, dict and tuple string conversion to match llama.cpp: a string item containing `'` is written in JSON form, as in `["it's"]`.

## 1.1.0

- Added `package:dinja/ast.dart` for template analysis without importing `src/`: `parseTemplate`, which parses a template into a `Program`; the AST node types; and `LexerException` and `ParserException`. `package:dinja/dinja.dart` is unchanged.
- Fixed string equality to compare content only: `''.strip() == ''` is now true, and `safe` or input-marked strings equal plain ones.
- Removed a debug `print` to stdout when a `for` loop iterates a function; the error now names the function.
- Fixed tests with one unparenthesized argument, such as `1 is eq 1` and `'a' is in ['a']`, which failed to parse. As in Jinja2, a value after a test without a comma is now its argument: `[x is odd 1]` means `[x is odd(1)]`.
- Fixed `unique` to compare items with Python equality: `[1, '1']` keeps both, `[1, 1.0, true]` keeps one. It now ignores string case by default, as Jinja2 does.
- Fixed a `ParserException` at the end of the template reporting position `-1`; it now reports the end of the template.
- Fixed an incomplete expression at the end of the template, such as `{{ 1 +`, throwing `RangeError` instead of `ParserException`.
- Fixed `ParserException` from `Template` on templates with `\r\n` or a trailing newline: its `source`, `pos`, `line` and `col` now all refer to the normalized text, as with `parseTemplate`.
- Changed `unique` to follow Jinja2's signature, `unique(case_sensitive=false, attribute=none)`: the first positional argument is now `case_sensitive`, not `attribute`. `unique` now also deduplicates the characters of a string and the keys of a dict.
- Fixed input marking being dropped by `~`, string repetition (`*`), `replace`, `capitalize`, `title`, `string`, `indent` and the last piece of `split` (first of `rsplit`), matching llama.cpp. Input-marked text from these is now escaped on output like `{{ value }}`. `join` still drops the marking, as in llama.cpp.
- Fixed double escaping when an escaped block, such as a `{% set %}` block or macro output, is joined with `+` to plain text.

## 1.0.0

- Initial release of Dinja.
- Minimal Jinja2 implementation ported from llama.cpp.
- Support for LLM chat templates.
- Secure input marking system.
- Fixed unused declaration in `nodes.dart`.
- Fixed `not in` operator logic for Maps.
- Fixed duplicate key in `builtins.dart`.
- Added cross-compatibility generation script (`script/generate_cross_test.py`).
