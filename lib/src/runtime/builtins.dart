// ignore_for_file: non_constant_identifier_names
import '../types/value.dart';
import '../types/jinja_string.dart';
import '../types/marking.dart';
import '../types/repr.dart';
import 'strftime.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

// Global built-ins map
// Global registries
final Map<String, JinjaFunctionHandler> globalFunctions = {
  'range': _range,
  'dict': _dict,
  'list': _list,
  'int': _int,
  'float': _float,
  'str': _str,
  'namespace': _namespace,
  'strftime_now': _strftime_now,
  'raise_exception': _raiseException,
};

final Map<String, JinjaFunctionHandler> globalFilters = {
  'tojson': _tojson,
  'json_encode': _tojson,
  'slice': _slice,
  'int': _int,
  'float': _float,
  'str': _str,
  'length': _len,
  'count': _len,
  'first': _first,
  'last': _last,
  'min': _min,
  'max': _max,
  'sum': _sum,
  'abs': _abs,
  'round': _round,
  'default': _default,
  'd': _default,
  'sort': _sort,
  'unique': _unique,
  'reverse': _reverse,
  'map': _map,
  'select': _select,
  'reject': _reject,
  'selectattr': _selectattr,
  'rejectattr': _rejectattr,
  'attr': _attr,
  'join': _join,
  'safe': _safe,
  'items': _items,
  'keys': _keys,
  'values': _values,
  'strip': _strip,
  'trim': _strip,
  'lstrip': _lstrip,
  'rstrip': _rstrip,
  'dictsort': _dictsort,
  'upper': _upper,
  'lower': _lower,
  'indent': _indent,
  'format': _formatFilter,
  'string': _string,
  'title': (args, kwargs) =>
      (_resolveStringMember(_asString(args), 'title') as JinjaFunction).handler(
        args,
        kwargs,
      ),
  'capitalize': (args, kwargs) =>
      (_resolveStringMember(_asString(args), 'capitalize') as JinjaFunction)
          .handler(args, kwargs),
  'truncate': _truncate,
  'wordcount': _wordcount,
  'list': _list,
  'yesno': _yesno,
  'replace': _replaceFilter,
  'strftime_now': _strftime_now,
};

final Map<String, JinjaFunctionHandler> globalTests = {
  'defined': _testIsDefined,
  'undefined': _testIsUndefined,
  'none': _testIsNone,
  'number': _testIsNumeric,
  'numeric': _testIsNumeric,
  'string': _testIsString,
  'mapping': _testIsMapping,
  'iterable': _testIsIterable,
  'sequence': _testIsSequence,
  'in': _testIsIn,
  'odd': _testIsOdd,
  'even': _testIsEven,
  'escaped': _testIsEscaped,
  'filter': _testIsFilter,
  'test': _testIsTest,
  'divisibleby': _testIsDivisibleBy,
  'lower': _testIsLower,
  'upper': _testIsUpper,
  'sameas': _testIsSameAs,
  'callable': _testIsCallable,
  'true': _testIsTrue,
  'false': _testIsFalse,
  'boolean': _testIsBoolean,
  'integer': _testIsInteger,
  'float': _testIsFloat,
  'startingwith': _testIsStartingWith,
  'endingwith': _testIsEndingWith,
  'equalto': _testIsEqualTo,
  'eq': _testIsEqualTo,
  'ieq': _testIsIequalTo,
  'ne': _testIsNotEqualTo,
  'greaterthan': _testIsGreaterThan,
  'gt': _testIsGreaterThan,
  'ge': _testIsGreaterThanOrEqual,
  'lessthan': _testIsLessThan,
  'lt': _testIsLessThan,
  'le': _testIsLessThanOrEqual,
};

// For backward compatibility or internal resolution where distinction doesn't matter
final Map<String, JinjaFunctionHandler> globalBuiltins = {
  ...globalFunctions,
  ...globalFilters,
  ...globalTests.map((k, v) => MapEntry('test_is_$k', v)),
};

/// Resolves an attribute on a value (e.g., user.name or list.length).
/// This handles both properties (like length) and dictionary key access.
JinjaValue _resolveAttribute(JinjaValue item, String attribute) {
  if (attribute.isEmpty) return item;

  if (attribute.contains('.')) {
    final parts = attribute.split('.');
    var current = item;
    for (final part in parts) {
      current = _resolveAttribute(current, part);
      if (current.isUndefined) break;
    }
    return current;
  }

  // 1. Check for specialized properties (length, etc)
  if (attribute == 'length') {
    if (item is JinjaList) return JinjaInteger(item.items.length);
    if (item is JinjaTuple) return JinjaInteger(item.items.length);
    if (item is JinjaMap) return JinjaInteger(item.asJinjaMap.length);
    if (item is JinjaStringValue) {
      return JinjaInteger(item.value.toString().length);
    }
    // Note: Range would be a JinjaList here if returned by range()
  }

  // 2. Try Dot-style resolution (methods then keys)
  if (item is JinjaMap) {
    // Methods FIRST
    final method = resolveMember(item, attribute);
    if (method != null) return method;

    // Keys SECOND
    final key = JinjaStringValue.fromString(attribute);
    if (item.asJinjaMap.containsKey(key)) {
      return item.asJinjaMap[key]!;
    }
  } else {
    // Normal objects: methods
    final method = resolveMember(item, attribute);
    if (method != null) return method;
  }

  // 3. Sequential index lookup (for map('0'))
  final index = int.tryParse(attribute);
  if (index != null) {
    if (item is JinjaList) {
      int idx = index < 0 ? item.items.length + index : index;
      if (idx >= 0 && idx < item.items.length) return item.items[idx];
    }
    if (item is JinjaTuple) {
      int idx = index < 0 ? item.items.length + index : index;
      if (idx >= 0 && idx < item.items.length) return item.items[idx];
    }
  }

  return const JinjaUndefined();
}

/// Resolves a member method on a value (e.g., list.append).
/// Returns a bound function (closure) or null if not found.
JinjaValue? resolveMember(JinjaValue obj, String name) {
  if (obj is JinjaList) return _resolveListMember(obj, name);
  if (obj is JinjaMap) return _resolveMapMember(obj, name);
  if (obj is JinjaStringValue) return _resolveStringMember(obj, name);
  if (obj is JinjaNone) return _resolveNoneMember(obj, name);
  if (obj is JinjaUndefined) return _resolveUndefinedMember(obj, name);

  // Finally check for custom attributes (e.g. LoopContext, or other objects)
  final attr = obj.getAttribute(name);
  if (attr != null) return attr;

  return null;
}

// Implementations

/// The first argument as a string value, keeping the input marking of the
/// strings in a list or dict.
JinjaStringValue _asString(List<JinjaValue> args) {
  if (args.isEmpty) return JinjaStringValue.fromString('');
  final v = args[0];
  if (v is JinjaStringValue) return v;
  final s = stringOf(v);
  return hasRawInput(s)
      ? JinjaStringValue(joinRaw([s]))
      : JinjaStringValue.fromString(v.toString());
}

JinjaValue _replaceFilter(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final obj = args[0];
  if (args.length < 3) return obj;
  final newVal = stringOf(args[2]);
  return _derivedFrom(
    obj,
    _replaceIn(stringOf(obj), args[1].toString(), newVal, -1),
    [newVal],
  );
}

/// [s] with [old] replaced by [rep]: everywhere, as `String.replaceAll`, or
/// at most [count] times when it is not negative. Each character keeps the
/// input marking of the string it came from.
JinjaString _replaceIn(JinjaString s, String old, JinjaString rep, int count) {
  s = rawOf(s);
  rep = rawOf(rep);
  if (count < 0) {
    final text = s.toString();
    var prev = 0;
    final parts = <JinjaStringPart>[];
    for (final m in old.allMatches(text)) {
      parts
        ..addAll(s.substring(prev, m.start).parts)
        ..addAll(rep.parts);
      prev = m.end;
    }
    return JinjaString([...parts, ...s.substring(prev).parts]);
  }
  var res = s;
  var start = 0;
  for (var total = 0; total < count; total++) {
    final idx = res.toString().indexOf(old, start);
    if (idx == -1) break;
    res = JinjaString([
      ...res.substring(0, idx).parts,
      ...rep.parts,
      ...res.substring(idx + old.length).parts,
    ]);
    start = idx + rep.length;
  }
  return res;
}

/// [result], computed from [source] and the [inserted] strings.
///
/// When any of them has input-marked text still to escape, each character
/// keeps the input marking of where it came from, so input text is escaped
/// and template text is not. Otherwise [result] is marked as `_derived`
/// marks it.
JinjaStringValue _derivedFrom(
  JinjaValue source,
  JinjaString result, [
  List<JinjaString> inserted = const [],
]) {
  if (hasRawInput(stringOf(source)) || inserted.any(hasRawInput)) {
    return JinjaStringValue(joinRaw([result]));
  }
  return _derived(source, result.toString());
}

JinjaStringValue _derived(JinjaValue source, String text) {
  if (source is! JinjaStringValue) return JinjaStringValue.fromString(text);
  return JinjaStringValue(
    JinjaString.from(
      text,
      isSafe: source.isSafe,
    ).markInputBasedOn(source.value),
  );
}

/// [text], a case change of [source], with the input marking of [source].
///
/// When the change alters the length and [source] has input-marked text to
/// escape, [perPart] computes it part by part instead.
JinjaStringValue _retext(
  JinjaStringValue source,
  String text,
  JinjaString Function() perPart,
) {
  if (text.length != source.value.length) {
    if (hasRawInput(source.value)) return JinjaStringValue(perPart());
    return _derived(source, text);
  }
  final parts = <JinjaStringPart>[];
  var start = 0;
  for (final part in source.value.parts) {
    final end = start + part.val.length;
    parts.add(JinjaStringPart(text.substring(start, end), part.isInput));
    start = end;
  }
  return JinjaStringValue(JinjaString(parts, isSafe: source.isSafe));
}

JinjaValue _range(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  int start = 0;
  int stop = 0;
  int step = 1;

  if (args.length == 1) {
    stop = args[0].asInt;
  } else if (args.length == 2) {
    start = args[0].asInt;
    stop = args[1].asInt;
  } else if (args.length == 3) {
    start = args[0].asInt;
    stop = args[1].asInt;
    step = args[2].asInt;
  } else {
    throw Exception('range expects 1-3 arguments');
  }

  final items = <JinjaValue>[];
  if (step > 0) {
    for (int i = start; i < stop; i += step) {
      items.add(JinjaInteger(i));
    }
  } else if (step < 0) {
    for (int i = start; i > stop; i += step) {
      items.add(JinjaInteger(i));
    }
  }
  return JinjaList(items);
}

JinjaValue _tojson(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  JinjaValue? arg(String name, int pos) =>
      kwargs[name] ?? (pos < args.length ? args[pos] : null);

  final indentArg = arg('indent', 2);
  final indent = indentArg is JinjaInteger ? indentArg.value : -1;
  final separatorsArg = arg('separators', 3);
  final separators = separatorsArg is JinjaList || separatorsArg is JinjaTuple
      ? separatorsArg!.asList
      : const <JinjaValue>[];
  final out = _JsonOut();
  _writeJson(
    out,
    args[0],
    0,
    indent: indent,
    itemSep: separators.isNotEmpty
        ? stringOf(separators[0])
        : JinjaString.template(indent < 0 ? ', ' : ','),
    keySep: separators.length > 1
        ? stringOf(separators[1])
        : JinjaString.template(': '),
    ensureAscii: arg('ensure_ascii', 1)?.asBool ?? false,
    sortKeys: arg('sort_keys', 4)?.asBool ?? false,
  );
  final json = joinRaw(out.pieces);
  // Without input-marked text the output is safe template text, as before.
  if (!json.parts.any((p) => p.isInput)) {
    return JinjaStringValue(
      JinjaString([JinjaStringPart(json.toString(), false)], isSafe: true),
    );
  }
  return JinjaStringValue(json);
}

/// JSON output that keeps the input marking of the strings written to it.
class _JsonOut {
  final List<JinjaString> pieces = [];

  void write(Object text) => pieces.add(JinjaString.template('$text'));

  void writeString(JinjaString s, bool ensureAscii) {
    write('"');
    pieces.add(
      JinjaString([
        for (final p in rawOf(s).parts)
          JinjaStringPart(
            jsonEscape(p.val, ensureAscii: ensureAscii),
            p.isInput,
          ),
      ]),
    );
    write('"');
  }
}

void _writeJson(
  _JsonOut out,
  JinjaValue v,
  int level, {
  required int indent,
  required JinjaString itemSep,
  required JinjaString keySep,
  required bool ensureAscii,
  required bool sortKeys,
}) {
  final newline = indent >= 0 ? '\n' : '';
  final pad = indent > 0 ? ' ' * indent : '';
  void writeItems<T>(
    String open,
    String close,
    List<T> items,
    void Function(T item) writeItem,
  ) {
    out.write(open);
    if (items.isNotEmpty) {
      out.write(newline);
      for (var i = 0; i < items.length; i++) {
        out.write(pad * (level + 1));
        writeItem(items[i]);
        if (i < items.length - 1) out.pieces.add(itemSep);
        out.write(newline);
      }
      out.write(pad * level);
    }
    out.write(close);
  }

  void writeValue(JinjaValue item) => _writeJson(
    out,
    item,
    level + 1,
    indent: indent,
    itemSep: itemSep,
    keySep: keySep,
    ensureAscii: ensureAscii,
    sortKeys: sortKeys,
  );

  if (v is JinjaBoolean) {
    out.write(v.value ? 'true' : 'false');
  } else if (v is JinjaInteger) {
    out.write(v.value);
  } else if (v is JinjaFloat) {
    out.write(_formatDouble(v.value));
  } else if (v is JinjaStringValue) {
    out.writeString(v.value, ensureAscii);
  } else if (v is JinjaList || v is JinjaTuple) {
    writeItems('[', ']', v.asList, writeValue);
  } else if (v is JinjaMap) {
    final entries = v.items.entries
        .map((e) => MapEntry(stringOf(e.key), e.value))
        .toList();
    if (sortKeys) {
      entries.sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    }
    writeItems('{', '}', entries, (MapEntry<JinjaString, JinjaValue> e) {
      out.writeString(e.key, ensureAscii);
      out.pieces.add(keySep);
      writeValue(e.value);
    });
  } else {
    out.write('null');
  }
}

/// Formats [v] as C++ `std::ostream` does by default (`%g` with precision 6),
/// which llama.cpp's `tojson` uses for floats.
String _formatDouble(double v) {
  if (v.isNaN) return 'nan';
  if (v.isInfinite) return v > 0 ? 'inf' : '-inf';
  final sign = v.isNegative ? '-' : '';
  if (v == 0) return '${sign}0';

  final bytes = ByteData(8)..setFloat64(0, v.abs());
  final high = bytes.getUint32(0);
  final biased = high >> 20;
  var mantissa =
      (BigInt.from(high & 0xfffff) << 32) | BigInt.from(bytes.getUint32(4));
  var exp2 = -1074;
  if (biased != 0) {
    mantissa |= BigInt.one << 52;
    exp2 = biased - 1075;
  }
  final num = exp2 >= 0 ? mantissa << exp2 : mantissa;
  final den = exp2 >= 0 ? BigInt.one : BigInt.one << -exp2;

  const precision = 6;
  final ten = BigInt.from(10);
  bool atLeastPowerOfTen(int e) =>
      e >= 0 ? num >= den * ten.pow(e) : num * ten.pow(-e) >= den;
  var exp10 = int.parse(v.abs().toStringAsExponential(0).split('e')[1]);
  while (!atLeastPowerOfTen(exp10)) {
    exp10--;
  }
  while (atLeastPowerOfTen(exp10 + 1)) {
    exp10++;
  }

  final shift = precision - 1 - exp10;
  final scaledNum = shift >= 0 ? num * ten.pow(shift) : num;
  final scaledDen = shift >= 0 ? den : den * ten.pow(-shift);
  var digits = scaledNum ~/ scaledDen;
  final twiceRemainder = (scaledNum % scaledDen) * BigInt.two;
  if (twiceRemainder > scaledDen ||
      twiceRemainder == scaledDen && digits.isOdd) {
    digits += BigInt.one;
  }
  if (digits == ten.pow(precision)) {
    digits = ten.pow(precision - 1);
    exp10++;
  }

  final d = digits.toString();
  String withFraction(String whole, String fraction) {
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$sign$whole' : '$sign$whole.$trimmed';
  }

  if (exp10 < -4 || exp10 >= precision) {
    final e = exp10.abs().toString().padLeft(2, '0');
    return '${withFraction(d[0], d.substring(1))}e${exp10 < 0 ? '-' : '+'}$e';
  }
  if (exp10 >= 0) {
    return withFraction(d.substring(0, exp10 + 1), d.substring(exp10 + 1));
  }
  return withFraction('0', '${'0' * (-exp10 - 1)}$d');
}

JinjaValue _slice(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  return const JinjaNone();
}

JinjaValue _dict(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  return JinjaMap(
    kwargs.map(
      (k, v) => MapEntry(
        (k is JinjaValue ? k : JinjaStringValue.fromString(k.toString()))
            as JinjaValue,
        (v),
      ),
    ),
  );
}

JinjaValue _list(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final arg = args[0];
  if (arg is JinjaList) return arg;
  if (arg is JinjaTuple) return JinjaList(List.from(arg.items));
  if (arg is JinjaStringValue) return JinjaList(charsOf(arg.value));
  if (arg is JinjaMap) {
    // list(dict) -> keys
    return JinjaList(
      arg.asJinjaMap.keys
          .map(
            (k) => k is JinjaStringValue
                ? k
                : JinjaStringValue.fromString(k.toString()),
          )
          .toList(),
    );
  }
  return JinjaList([arg]);
}

JinjaValue _int(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final v = args[0];
  final base = kwargs['base']?.asInt ?? (args.length > 2 ? args[2].asInt : 10);
  try {
    if (v is JinjaStringValue) {
      return JinjaInteger(int.parse(v.toString(), radix: base));
    }
    if (v is JinjaFloat) return JinjaInteger(v.value.toInt());
    if (v is JinjaBoolean) return JinjaInteger(v.value ? 1 : 0);
    if (v is JinjaInteger) return v;
  } catch (_) {}
  final defaultVal =
      kwargs['default'] ?? args.elementAtOrNull(1) ?? const JinjaInteger(0);
  return defaultVal;
}

JinjaValue _float(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaFloat(0.0);
  final v = args[0];
  try {
    if (v is JinjaStringValue) return JinjaFloat(double.parse(v.toString()));
    if (v is JinjaInteger) return JinjaFloat(v.value.toDouble());
    if (v is JinjaBoolean) return JinjaFloat(v.value ? 1.0 : 0.0);
    if (v is JinjaFloat) return v;
  } catch (_) {}
  final defaultVal =
      kwargs['default'] ?? args.elementAtOrNull(1) ?? const JinjaFloat(0.0);
  return defaultVal;
}

JinjaValue _str(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  return JinjaStringValue(joinRaw([stringOf(args[0])]));
}

JinjaValue _len(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final v = args[0];
  if (v is JinjaList) return JinjaInteger(v.items.length);
  if (v is JinjaMap) return JinjaInteger(v.asJinjaMap.length);
  if (v is JinjaStringValue) return JinjaInteger(v.value.length);
  if (v is JinjaTuple) return JinjaInteger(v.items.length);
  return const JinjaInteger(0);
}

JinjaValue _first(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final v = args[0];
  if (v is JinjaList && v.items.isNotEmpty) return v.items.first;
  if (v is JinjaStringValue && v.value.length > 0) {
    return JinjaStringValue(rawOf(v.value)[0]);
  }
  if (v is JinjaTuple && v.items.isNotEmpty) return v.items.first;
  return const JinjaUndefined();
}

JinjaValue _last(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final v = args[0];
  if (v is JinjaList && v.items.isNotEmpty) return v.items.last;
  if (v is JinjaStringValue && v.value.length > 0) {
    return JinjaStringValue(rawOf(v.value)[v.value.length - 1]);
  }
  if (v is JinjaTuple && v.items.isNotEmpty) return v.items.last;
  return const JinjaUndefined();
}

JinjaValue _min(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final collection = args[0];
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  if ((collection is JinjaList || collection is JinjaTuple)) {
    final items = collection is JinjaList
        ? collection.items
        : (collection as JinjaTuple).items;
    if (items.isEmpty) return const JinjaUndefined();

    var m = items.first;
    var mVal = attribute != null ? _resolveAttribute(m, attribute) : m;

    for (final item in items.skip(1)) {
      final itemVal = attribute != null
          ? _resolveAttribute(item, attribute)
          : item;
      if (_compare(itemVal, mVal) < 0) {
        m = item;
        mVal = itemVal;
      }
    }
    return m;
  }
  return collection;
}

JinjaValue _max(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final collection = args[0];
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  if ((collection is JinjaList || collection is JinjaTuple)) {
    final items = collection is JinjaList
        ? collection.items
        : (collection as JinjaTuple).items;
    if (items.isEmpty) return const JinjaUndefined();

    var m = items.first;
    var mVal = attribute != null ? _resolveAttribute(m, attribute) : m;

    for (final item in items.skip(1)) {
      final itemVal = attribute != null
          ? _resolveAttribute(item, attribute)
          : item;
      if (_compare(itemVal, mVal) > 0) {
        m = item;
        mVal = itemVal;
      }
    }
    return m;
  }
  return collection;
}

int _compare(JinjaValue a, JinjaValue b) {
  if (a.isNumeric && b.isNumeric) {
    return a.asDouble.compareTo(b.asDouble);
  }
  return a.toString().compareTo(b.toString());
}

JinjaValue _sum(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final collection = args[0];
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);
  final startVal =
      kwargs['start'] ?? (args.length > 2 ? args[2] : const JinjaInteger(0));
  double total = startVal.asDouble;
  bool isFloat = startVal is JinjaFloat;

  if (collection is JinjaList || collection is JinjaTuple) {
    final items = collection is JinjaList
        ? collection.asList
        : (collection as JinjaTuple).asList;
    // print('DEBUG: Summing collection of length ${items.length}, attribute=$attribute');
    for (final item in items) {
      final val = attribute != null ? _resolveAttribute(item, attribute) : item;
      // print('DEBUG: Sum item val: $val (isNumeric: ${val.isNumeric})');
      if (val.isNumeric) {
        total += val.asDouble;
        if (val is JinjaFloat) isFloat = true;
      }
    }
  }
  // print('DEBUG: Sum total: $total');
  return isFloat ? JinjaFloat(total) : JinjaInteger(total.toInt());
}

JinjaValue _abs(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final v = args[0];
  if (v is JinjaInteger) return JinjaInteger(v.value.abs());
  if (v is JinjaFloat) return JinjaFloat(v.value.abs());
  return const JinjaInteger(0);
}

JinjaValue _round(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaFloat(0.0);
  final v = args[0];
  if (!v.isNumeric) return const JinjaFloat(0.0); // or error?

  int precision = 0;
  if (args.length > 1) precision = args[1].asInt;
  // logic for rounding
  double val = v.asDouble;
  String method = 'common';
  if (args.length > 2) method = args[2].toString();

  double mult = math.pow(10, precision).toDouble();
  double result;
  if (method == 'ceil') {
    result = (val * mult).ceil() / mult;
  } else if (method == 'floor') {
    result = (val * mult).floor() / mult;
  } else {
    result = (val * mult).round() / mult;
  }

  if (precision == 0) return JinjaInteger(result.toInt());
  return JinjaFloat(result);
}

JinjaValue _default(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final defaultVal = args.length > 1
      ? args[1]
      : const JinjaStringValue(JinjaString([]));
  final boolVal = args.length > 2 ? args[2].asBool : false;

  // As in llama.cpp, none also takes the default. Jinja2 keeps none.
  final missing = boolVal ? !v.asBool : v.isUndefined || v.isNone;
  return missing ? defaultVal : v;
}

JinjaValue _sort(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isUndefined || collection.isNone) return const JinjaList([]);
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final reverse =
      kwargs['reverse']?.asBool ?? (args.length > 1 ? args[1].asBool : false);
  final caseSensitive = kwargs['case_sensitive']?.asBool ?? false;
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  final items = collection is JinjaList
      ? List<JinjaValue>.from(collection.items)
      : List<JinjaValue>.from((collection as JinjaTuple).items);

  items.sort((a, b) {
    final valA = attribute != null ? _resolveAttribute(a, attribute) : a;
    final valB = attribute != null ? _resolveAttribute(b, attribute) : b;

    String sa = valA.toString();
    String sb = valB.toString();
    if (!caseSensitive) {
      sa = sa.toLowerCase();
      sb = sb.toLowerCase();
    }
    final c = sa.compareTo(sb);
    return reverse ? -c : c;
  });
  return JinjaList(items);
}

JinjaValue _unique(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  final List<JinjaValue> items;
  if (collection is JinjaList || collection is JinjaTuple) {
    items = collection.asList;
  } else if (collection is JinjaStringValue) {
    items = charsOf(collection.value);
  } else if (collection is JinjaMap) {
    items = collection.items.keys.toList();
  } else if (collection.isNone) {
    return const JinjaList([]);
  } else {
    return collection;
  }

  final caseSensitive =
      kwargs['case_sensitive']?.asBool ?? (args.length > 1 && args[1].asBool);
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  return JinjaList(_uniqueItems(items, caseSensitive, attribute));
}

List<JinjaValue> _uniqueItems(
  List<JinjaValue> items,
  bool caseSensitive,
  String? attribute,
) {
  final seen = <JinjaValue>{};
  final result = <JinjaValue>[];
  for (final item in items) {
    var key = attribute != null ? _resolveAttribute(item, attribute) : item;
    if (!caseSensitive && key is JinjaStringValue) {
      key = JinjaStringValue.fromString(key.value.toString().toLowerCase());
    }
    if (seen.add(key)) result.add(item);
  }
  return result;
}

JinjaValue _reverse(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaList) return JinjaList(v.items.reversed.toList());
  if (v is JinjaStringValue) {
    return JinjaStringValue(
      joinRaw(charsOf(v.value).reversed.map((c) => stringOf(c))),
    );
  }
  return v;
}

JinjaValue _map(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isUndefined || collection.isNone) return const JinjaList([]);

  final items = collection.asList;
  final firstArg = args.length > 1 ? args[1].toString() : null;

  // map(attribute='...') or map('attribute')
  final String? attribute =
      kwargs['attribute']?.toString() ??
      (firstArg != null && !globalFilters.containsKey(firstArg)
          ? firstArg
          : null);

  // map(filter='...') or map('filter')
  final String? filterName =
      (firstArg != null && globalFilters.containsKey(firstArg))
      ? firstArg
      : null;

  final defaultVal = kwargs['default'] ?? (args.length > 2 ? args[2] : null);

  final result = <JinjaValue>[];
  for (final item in items) {
    JinjaValue val;
    if (filterName != null) {
      val = globalFilters[filterName]!([item], {});
    } else if (attribute != null) {
      val = _resolveAttribute(item, attribute);
    } else {
      val = item;
    }

    if (val.isUndefined && defaultVal != null) {
      val = defaultVal;
    }
    result.add(val);
  }
  return JinjaList(result);
}

JinjaValue _selectattr(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isNone) return const JinjaList([]);
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;
  final attribute = args.length > 1 ? args[1].toString() : null;
  final testName = args.length > 2 ? args[2].toString() : null;
  final testArgs = args.length > 3 ? args.sublist(3) : <JinjaValue>[];
  final testKwargs = kwargs;

  final testFunc = testName != null ? globalTests[testName] : null;
  if (testName != null && testFunc == null) {
    throw Exception('Unknown test: $testName');
  }

  final result = <JinjaValue>[];
  for (final item in items) {
    final val = attribute != null ? _resolveAttribute(item, attribute) : item;
    bool match;
    if (testFunc != null) {
      match = testFunc([val, ...testArgs], testKwargs).asBool;
    } else {
      match = val.asBool;
    }
    if (match) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _rejectattr(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isNone) return const JinjaList([]);
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;
  final attribute = args.length > 1 ? args[1].toString() : null;
  final testName = args.length > 2 ? args[2].toString() : null;
  final testArgs = args.length > 3 ? args.sublist(3) : <JinjaValue>[];
  final testKwargs = kwargs;

  final testFunc = testName != null ? globalTests[testName] : null;
  if (testName != null && testFunc == null) {
    throw Exception('Unknown test: $testName');
  }

  final result = <JinjaValue>[];
  for (final item in items) {
    final val = attribute != null ? _resolveAttribute(item, attribute) : item;
    bool match;
    if (testFunc != null) {
      match = testFunc([val, ...testArgs], testKwargs).asBool;
    } else {
      match = val.asBool;
    }
    if (!match) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _select(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isNone) return const JinjaList([]);
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;
  final testName = args.length > 1 ? args[1].toString() : null;
  final testArgs = args.length > 2 ? args.sublist(2) : <JinjaValue>[];
  final testKwargs = kwargs;

  final testFunc = testName != null ? globalTests[testName] : null;
  if (testName != null && testFunc == null) {
    throw Exception('Unknown test: $testName');
  }

  final result = <JinjaValue>[];
  for (final item in items) {
    bool match;
    if (testFunc != null) {
      match = testFunc([item, ...testArgs], testKwargs).asBool;
    } else {
      match = item.asBool;
    }
    if (match) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _reject(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection.isNone) return const JinjaList([]);
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;
  final testName = args.length > 1 ? args[1].toString() : null;
  final testArgs = args.length > 2 ? args.sublist(2) : <JinjaValue>[];
  final testKwargs = kwargs;

  final testFunc = testName != null ? globalTests[testName] : null;
  if (testName != null && testFunc == null) {
    throw Exception('Unknown test: $testName');
  }

  final result = <JinjaValue>[];
  for (final item in items) {
    bool match;
    if (testFunc != null) {
      match = testFunc([item, ...testArgs], testKwargs).asBool;
    } else {
      match = item.asBool;
    }
    if (!match) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _attr(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final obj = args[0];
  final name = args.length > 1 ? args[1].toString() : '';

  if (obj is JinjaMap) {
    return obj.asJinjaMap[JinjaStringValue.fromString(name)] ??
        const JinjaUndefined();
  }
  return const JinjaUndefined();
}

JinjaValue _join(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final collection = args[0];
  if (collection is! JinjaList && collection is! JinjaTuple) {
    return JinjaStringValue(joinRaw([stringOf(collection)]));
  }

  final delimiterArg = kwargs['d'] ?? (args.length > 1 ? args[1] : null);
  final delimiter = delimiterArg == null
      ? JinjaString.template('')
      : stringOf(delimiterArg);
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;

  return JinjaStringValue(
    joinRaw([
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) delimiter,
        stringOf(
          attribute != null ? _resolveAttribute(items[i], attribute) : items[i],
        ),
      ],
    ]),
  );
}

JinjaValue _safe(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) {
    return const JinjaStringValue(JinjaString([], isSafe: true));
  }
  final v = args[0];
  if (v is JinjaStringValue) {
    if (isRendered(v.value)) return JinjaStringValue(v.value.escape());
    return JinjaStringValue(v.value.markSafe());
  }
  return JinjaStringValue(JinjaString.from(v.toString(), isSafe: true));
}

JinjaValue _items(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaMap) {
    return JinjaList(
      v.asJinjaMap.entries
          .map(
            (e) => JinjaTuple([
              e.key is JinjaStringValue
                  ? e.key
                  : JinjaStringValue.fromString(e.key.toString()),
              e.value,
            ]),
          )
          .toList(),
    );
  }
  return const JinjaList([]);
}

JinjaValue _keys(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaMap) {
    return JinjaList(
      v.asJinjaMap.keys
          .map(
            (k) => k is JinjaStringValue
                ? k
                : JinjaStringValue.fromString(k.toString()),
          )
          .toList(),
    );
  }
  return const JinjaList([]);
}

JinjaValue _values(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaMap) return JinjaList(v.asJinjaMap.values.toList());
  return const JinjaList([]);
}

// Tests implementation

JinjaValue _testIsDefined(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(!args[0].isUndefined);
}

JinjaValue _testIsUndefined(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(true);
  return JinjaBoolean(args[0].isUndefined);
}

JinjaValue _testIsNone(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].isNone);
}

JinjaValue _testIsBoolean(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0] is JinjaBoolean);
}

JinjaValue _testIsInteger(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0] is JinjaInteger);
}

JinjaValue _testIsFloat(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0] is JinjaFloat);
}

JinjaValue _testIsString(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].isString);
}

JinjaValue _testIsNumeric(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].isNumeric);
}

JinjaValue _testIsIterable(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(
    v is JinjaList ||
        v is JinjaTuple ||
        v is JinjaMap ||
        v is JinjaStringValue ||
        v is JinjaUndefined,
  ); // llama.cpp considers undefined iterable
}

JinjaValue _testIsSequence(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(
    v is JinjaList ||
        v is JinjaTuple ||
        v is JinjaStringValue ||
        v is JinjaUndefined,
  ); // llama.cpp considers undefined sequence
}

JinjaValue _testIsMapping(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].isMap);
}

JinjaValue _testIsStartingWith(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  final str = args[0].toString();
  final prefix = args[1].toString();
  return JinjaBoolean(str.startsWith(prefix));
}

JinjaValue _testIsEndingWith(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  final str = args[0].toString();
  final suffix = args[1].toString();
  return JinjaBoolean(str.endsWith(suffix));
}

JinjaValue _testIsEqualTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  return JinjaBoolean(args[0].toString() == args[1].toString());
}

JinjaValue _testIsIequalTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  return JinjaBoolean(
    args[0].toString().toLowerCase() == args[1].toString().toLowerCase(),
  );
}

JinjaValue _testIsNotEqualTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  return JinjaBoolean(args[0].toString() != args[1].toString());
}

JinjaValue _testIsGreaterThan(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble > args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsGreaterThanOrEqual(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble >= args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsLessThan(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble < args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsLessThanOrEqual(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble <= args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsIn(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  _requireTestArgument(args);
  final item = args[0];
  final collection = args[1];

  if (collection is JinjaList) {
    // iterate and check equal
    for (final i in collection.items) {
      if (i == item) return const JinjaBoolean(true);
    }
    return const JinjaBoolean(false);
  }
  if (collection is JinjaMap) {
    return JinjaBoolean(collection.asJinjaMap.containsKey(item));
  }
  if (collection is JinjaStringValue) {
    return JinjaBoolean(collection.value.toString().contains(item.toString()));
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsOdd(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  if (v is JinjaInteger) return JinjaBoolean(v.value.isOdd);
  if (v.isNumeric) return JinjaBoolean(v.asInt.isOdd);
  return const JinjaBoolean(false);
}

JinjaValue _testIsEven(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].asInt % 2 == 0);
}

JinjaValue _testIsEscaped(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(v.isSafe || v is JinjaStringValue && isRendered(v.value));
}

JinjaValue _testIsFilter(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(globalFilters.containsKey(args[0].toString()));
}

JinjaValue _testIsTest(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(globalTests.containsKey(args[0].toString()));
}

// Member resolution

JinjaValue? _resolveListMember(JinjaList obj, String name) {
  switch (name) {
    case 'append':
      return JinjaFunction('append', (args, kwargs) {
        if (args.isEmpty) throw Exception('append expects 1 argument');
        obj.items.add(args[0]);
        return const JinjaNone();
      });
    case 'pop':
      return JinjaFunction('pop', (args, kwargs) {
        // pop([index])
        int index = -1;
        if (args.isNotEmpty) index = args[0].asInt;

        if (index < 0) index += obj.items.length;
        if (index >= 0 && index < obj.items.length) {
          return obj.items.removeAt(index);
        }
        if (args.isEmpty) return obj.items.removeLast(); // -1 behavior
        throw Exception('pop index out of range');
      });
    case 'sort':
      return JinjaFunction('sort', (args, kwargs) {
        final reverse =
            kwargs['reverse']?.asBool ??
            (args.isNotEmpty ? args[0].asBool : false);
        final caseSensitive = kwargs['case_sensitive']?.asBool ?? false;
        final attribute =
            kwargs['attribute']?.toString() ??
            (args.length > 1 ? args[1].toString() : null);

        obj.items.sort((a, b) {
          final valA = attribute != null ? _resolveAttribute(a, attribute) : a;
          final valB = attribute != null ? _resolveAttribute(b, attribute) : b;

          String sa = valA.toString();
          String sb = valB.toString();
          if (!caseSensitive) {
            sa = sa.toLowerCase();
            sb = sb.toLowerCase();
          }
          final c = sa.compareTo(sb);
          return reverse ? -c : c;
        });
        return obj;
      });
    case 'reverse':
      return JinjaFunction('reverse', (args, kwargs) {
        obj.items.setAll(0, obj.items.reversed.toList());
        return obj;
      });
    case 'unique':
      return JinjaFunction('unique', (args, kwargs) {
        final attribute =
            kwargs['attribute']?.toString() ??
            (args.isNotEmpty ? args[0].toString() : null);
        final caseSensitive = kwargs['case_sensitive']?.asBool ?? true;
        return JinjaList(_uniqueItems(obj.items, caseSensitive, attribute));
      });
  }
  return null;
}

JinjaValue? _resolveMapMember(JinjaMap obj, String name) {
  switch (name) {
    case 'keys':
      return JinjaFunction('keys', (args, kwargs) {
        return JinjaList(
          obj.asJinjaMap.keys
              .map(
                (k) => k is JinjaStringValue
                    ? k
                    : JinjaStringValue.fromString(k.toString()),
              )
              .toList(),
        );
      });
    case 'values':
      return JinjaFunction('values', (args, kwargs) {
        return JinjaList(obj.items.values.toList());
      });
    case 'items':
      return JinjaFunction('items', (args, kwargs) {
        return JinjaList(
          obj.items.entries
              .map(
                (e) => JinjaTuple([
                  e.key is JinjaStringValue
                      ? e.key
                      : JinjaStringValue.fromString(e.key.toString()),
                  e.value,
                ]),
              )
              .toList(),
        );
      });
    case 'get':
      return JinjaFunction('get', (args, kwargs) {
        if (args.isEmpty) throw Exception('get expects key');
        final key = args[0];
        final defaultVal = args.length > 1 ? args[1] : const JinjaNone();
        return obj.items[key] ?? defaultVal;
      });
    case 'length':
      // Not standard method, usually filter | length. But llama.cpp might have it?
      // llama.cpp: "length" in value_object_t builtins.
      return JinjaFunction(
        'length',
        (args, kwargs) => JinjaInteger(obj.items.length),
      );
  }
  return null;
}

JinjaValue? _resolveStringMember(JinjaStringValue obj, String name) {
  // Common string methods
  switch (name) {
    case 'upper':
      return JinjaFunction(
        'upper',
        (args, kwargs) => JinjaStringValue(obj.value.toUpperCase()),
      );
    case 'lower':
      return JinjaFunction(
        'lower',
        (args, kwargs) => JinjaStringValue(obj.value.toLowerCase()),
      );
    case 'startswith':
      return JinjaFunction('startswith', (args, kwargs) {
        if (args.isEmpty) return const JinjaBoolean(false);
        return JinjaBoolean(
          obj.value.toString().startsWith(args[0].toString()),
        );
      });
    case 'endswith':
      return JinjaFunction('endswith', (args, kwargs) {
        if (args.isEmpty) return const JinjaBoolean(false);
        return JinjaBoolean(obj.value.toString().endsWith(args[0].toString()));
      });
    case 'strip':
      return JinjaFunction('strip', (args, kwargs) {
        return _strip([obj, ...args], kwargs);
      });
    case 'lstrip':
      return JinjaFunction('lstrip', (args, kwargs) {
        return _lstrip([obj, ...args], kwargs);
      });
    case 'rstrip':
      return JinjaFunction('rstrip', (args, kwargs) {
        return _rstrip([obj, ...args], kwargs);
      });
    case 'split':
      return JinjaFunction('split', (args, kwargs) {
        final delimiter = args.isNotEmpty ? args[0].toString() : null;
        final maxsplit =
            kwargs['maxsplit']?.asInt ?? (args.length > 1 ? args[1].asInt : -1);

        final src = rawOf(obj.value);
        final s = src.toString();
        List<JinjaString> parts;
        if (delimiter == null || delimiter == ' ') {
          // split by whitespace
          parts = _splitWhitespace(src);
          if (maxsplit >= 0 && parts.length > maxsplit + 1) {
            final rest = _joinSpaces(parts.sublist(maxsplit));
            parts = parts.sublist(0, maxsplit)..add(rest);
          }
        } else {
          if (maxsplit >= 0) {
            // Dart split doesn't have maxsplit, need careful implementation
            parts = [];
            int start = 0;
            for (int i = 0; i < maxsplit; i++) {
              int idx = s.indexOf(delimiter, start);
              if (idx == -1) break;
              parts.add(src.substring(start, idx));
              start = idx + delimiter.length;
            }
            parts.add(src.substring(start));
          } else {
            parts = _splitOn(src, delimiter);
          }
        }

        return JinjaList([
          for (var i = 0; i < parts.length; i++)
            _splitPiece(obj, parts[i], last: i == parts.length - 1),
        ]);
      });
    case 'rsplit':
      return JinjaFunction('rsplit', (args, kwargs) {
        final delimiter = args.isNotEmpty ? args[0].toString() : null;
        final maxsplit =
            kwargs['maxsplit']?.asInt ?? (args.length > 1 ? args[1].asInt : -1);

        final src = rawOf(obj.value);
        final s = src.toString();
        List<JinjaString> parts;
        if (delimiter == null || delimiter == ' ') {
          // rsplit by whitespace
          parts = _splitWhitespace(src);
          if (maxsplit >= 0 && parts.length > maxsplit + 1) {
            final rest = _joinSpaces(parts.sublist(0, parts.length - maxsplit));
            parts = [rest, ...parts.sublist(parts.length - maxsplit)];
          }
        } else {
          if (maxsplit >= 0) {
            parts = [];
            int end = s.length;
            for (int i = 0; i < maxsplit; i++) {
              int idx = s.lastIndexOf(delimiter, end - 1);
              if (idx == -1) break;
              parts.insert(0, src.substring(idx + delimiter.length, end));
              end = idx;
            }
            parts.insert(0, src.substring(0, end));
          } else {
            parts = _splitOn(src, delimiter);
          }
        }
        return JinjaList([
          for (var i = 0; i < parts.length; i++)
            _splitPiece(obj, parts[i], last: i == 0),
        ]);
      });
    case 'capitalize':
      return JinjaFunction('capitalize', (args, kwargs) {
        final s = obj.value.toString();
        if (s.isEmpty) return obj;
        return _retext(
          obj,
          s[0].toUpperCase() + s.substring(1).toLowerCase(),
          () => _capitalized(obj.value),
        );
      });
    case 'title':
      return JinjaFunction('title', (args, kwargs) {
        final s = obj.value.toString();
        return _retext(
          obj,
          s
              .split(' ')
              .map((w) {
                if (w.isEmpty) return w;
                return w[0].toUpperCase() + w.substring(1).toLowerCase();
              })
              .join(' '),
          () {
            final words = <JinjaString>[];
            var start = 0;
            for (final w in s.split(' ')) {
              if (start > 0) words.add(obj.value.substring(start - 1, start));
              words.add(
                _capitalized(obj.value.substring(start, start + w.length)),
              );
              start += w.length + 1;
            }
            return joinRaw(words);
          },
        );
      });
    case 'format':
      return JinjaFunction('format', (args, kwargs) => _format(obj, args));
    case 'replace':
      return JinjaFunction('replace', (args, kwargs) {
        if (args.length < 2) return obj;
        final newVal = stringOf(args[1]);
        final count =
            kwargs['count']?.asInt ?? (args.length > 2 ? args[2].asInt : -1);
        return _derivedFrom(
          obj,
          _replaceIn(obj.value, args[0].toString(), newVal, count),
          [newVal],
        );
      });
  }
  return null;
}

/// `s.trim().split(RegExp(r'\s+'))`, keeping input marking.
List<JinjaString> _splitWhitespace(JinjaString s) {
  final text = s.toString();
  final trimmed = text.trim();
  final lead = text.length - text.trimLeft().length;
  final src = s.substring(lead, lead + trimmed.length);
  final pieces = <JinjaString>[];
  var prev = 0;
  for (final m in RegExp(r'\s+').allMatches(trimmed)) {
    pieces.add(src.substring(prev, m.start));
    prev = m.end;
  }
  return pieces..add(src.substring(prev));
}

/// `s.split(delimiter)`, keeping input marking.
List<JinjaString> _splitOn(JinjaString s, String delimiter) {
  final text = s.toString();
  if (delimiter.isEmpty) {
    return [for (var i = 0; i < text.length; i++) s.substring(i, i + 1)];
  }
  final pieces = <JinjaString>[];
  var prev = 0;
  for (final m in delimiter.allMatches(text)) {
    pieces.add(s.substring(prev, m.start));
    prev = m.end;
  }
  return pieces..add(s.substring(prev));
}

/// [pieces] joined with single spaces.
JinjaString _joinSpaces(List<JinjaString> pieces) => JinjaString([
  for (var i = 0; i < pieces.length; i++) ...[
    if (i > 0) const JinjaStringPart(' ', false),
    ...pieces[i].parts,
  ],
]);

/// A piece of a `split` or `rsplit` of [source].
///
/// With input-marked text still to escape, the piece keeps its marking.
/// Otherwise only the [last] piece split off, the remainder, is marked, as
/// in llama.cpp: as input when all of [source] is.
JinjaStringValue _splitPiece(
  JinjaStringValue source,
  JinjaString piece, {
  required bool last,
}) {
  if (hasRawInput(source.value)) return JinjaStringValue(joinRaw([piece]));
  if (last) return _derived(source, piece.toString());
  return JinjaStringValue.fromString(piece.toString());
}

/// [s] with its first character upper case and the rest lower case, changed
/// part by part.
JinjaString _capitalized(JinjaString s) =>
    joinRaw([s.substring(0, 1).toUpperCase(), s.substring(1).toLowerCase()]);

/// Formats [args] into the `{}` placeholders of [fmt]. The literal text and
/// each argument keep their input marking.
JinjaStringValue _format(JinjaStringValue fmt, List<JinjaValue> args) {
  final format = rawOf(fmt.value);
  final source = format.toString();
  final parts = <JinjaStringPart>[];
  var literalStart = 0;
  void flushLiteral(int end) {
    parts.addAll(format.substring(literalStart, end).parts);
  }

  var next = 0;
  for (var i = 0; i < source.length; i++) {
    if (source[i] != '{') continue;
    if (i + 1 >= source.length || source[i + 1] != '}') {
      throw Exception("format() only supports simple '{}' placeholders");
    }
    if (next >= args.length) {
      throw Exception(
        'format() expected at least ${next + 1} arguments, got ${args.length}',
      );
    }
    flushLiteral(i);
    i++;
    literalStart = i + 1;
    final arg = args[next++];
    final text = stringOf(arg);
    parts.addAll(
      arg is JinjaStringValue
          ? rawOf(text).parts
          : hasRawInput(text)
          ? joinRaw([text]).parts
          : [JinjaStringPart('$arg', false)],
    );
  }
  flushLiteral(source.length);
  return JinjaStringValue(JinjaString(parts));
}

JinjaValue _formatFilter(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  final value = args.isEmpty ? const JinjaUndefined() : args[0];
  if (value is! JinjaStringValue) {
    throw Exception("Unknown filter 'format' for type ${value.typeName}");
  }
  return _format(value, args.sublist(1));
}

void _requireTestArgument(List<JinjaValue> args) {
  if (args.length < 2) {
    throw Exception('Test expected 2 arguments, got ${args.length}');
  }
}

JinjaValue _strip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trim());
    if (hasRawInput(stringOf(v))) {
      return JinjaStringValue(_asString(args).value.trim());
    }
    return JinjaStringValue.fromString(v.toString().trim());
  }

  String s = v.toString();
  final charSet = chars.split('').toSet();

  int start = 0;
  while (start < s.length && charSet.contains(s[start])) {
    start++;
  }
  int end = s.length;
  while (end > start && charSet.contains(s[end - 1])) {
    end--;
  }
  return _codeUnits(v, start, end);
}

/// Code units [start] to [end] of [v]'s string form, keeping their input
/// marking.
JinjaStringValue _codeUnits(JinjaValue v, int start, [int? end]) =>
    JinjaStringValue(joinRaw([stringOf(v).substring(start, end)]));

JinjaValue _lstrip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trimLeft());
    if (hasRawInput(stringOf(v))) {
      return JinjaStringValue(_asString(args).value.trimLeft());
    }
    return JinjaStringValue.fromString(v.toString().trimLeft());
  }

  String s = v.toString();
  final charSet = chars.split('').toSet();
  int start = 0;
  while (start < s.length && charSet.contains(s[start])) {
    start++;
  }
  return _codeUnits(v, start);
}

JinjaValue _rstrip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trimRight());
    if (hasRawInput(stringOf(v))) {
      return JinjaStringValue(_asString(args).value.trimRight());
    }
    return JinjaStringValue.fromString(v.toString().trimRight());
  }

  String s = v.toString();
  final charSet = chars.split('').toSet();
  int end = s.length;
  while (end > 0 && charSet.contains(s[end - 1])) {
    end--;
  }
  return _codeUnits(v, 0, end);
}

JinjaValue? _resolveNoneMember(JinjaNone obj, String name) {
  if (name == 'default' ||
      name == 'tojson' ||
      name == 'string' ||
      name == 'safe' ||
      name == 'strip') {
    // return "None" string or safe wrapper
    // llama.cpp returns "None" for string/safe/strip
    return JinjaFunction(
      name,
      (args, kwargs) =>
          const JinjaStringValue(JinjaString([JinjaStringPart('None', false)])),
    );
  }
  return null;
}

/// The members of undefined in llama.cpp, which return an empty value of
/// the filter's result type.
final Map<String, JinjaValue> _undefinedMembers = {
  for (final name in [
    'capitalize',
    'join',
    'lower',
    'replace',
    'safe',
    'string',
    'strip',
    'title',
    'truncate',
    'upper',
  ])
    name: const JinjaStringValue(JinjaString([])),
  for (final name in [
    'items',
    'list',
    'map',
    'reject',
    'rejectattr',
    'reverse',
    'select',
    'selectattr',
    'sort',
    'unique',
  ])
    name: const JinjaList([]),
  for (final name in ['length', 'sum', 'wordcount'])
    name: const JinjaInteger(0),
  for (final name in ['first', 'last', 'max', 'min'])
    name: const JinjaUndefined(),
};

JinjaValue? _resolveUndefinedMember(JinjaUndefined obj, String name) {
  if (name == 'default') {
    return _UndefinedMember(
      name,
      (args, kwargs) => _default([obj, ...args], kwargs),
    );
  }
  final empty = _undefinedMembers[name];
  if (empty == null) return null;
  return _UndefinedMember(name, (args, kwargs) {
    // A new list, as a template may append to it.
    return empty is JinjaList ? JinjaList([]) : empty;
  });
}

/// A member of undefined, such as `x.upper` for an undefined `x`. As in
/// llama.cpp, it prints as nothing.
class _UndefinedMember extends JinjaFunction {
  const _UndefinedMember(super.name, super.handler);

  @override
  String toString() => '';
}

JinjaValue _namespace(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  JinjaValue val(dynamic v) =>
      v is JinjaValue ? v : JinjaStringValue.fromString(v.toString());
  final Map<JinjaValue, JinjaValue> items = {};
  if (args.isNotEmpty) {
    final arg = args[0];
    if (arg is JinjaMap) {
      items.addAll(arg.asJinjaMap);
    }
  }
  items.addAll(kwargs.map((k, v) => MapEntry(val(k), val(v))));
  return JinjaMap(items);
}

JinjaValue _raiseException(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  final msg = args.isNotEmpty ? args[0].toString() : 'Template Error';
  throw Exception(msg);
}

JinjaValue _dictsort(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is! JinjaMap) return const JinjaList([]);

  final caseSensitive =
      kwargs['case_sensitive']?.asBool ??
      (args.length > 1 ? args[1].asBool : false);
  final by =
      kwargs['by']?.toString() ??
      (args.length > 2 ? args[2].toString() : 'key');
  final reverse =
      kwargs['reverse']?.asBool ?? (args.length > 3 ? args[3].asBool : false);

  final entries = v.items.entries.toList();
  final byValue = by == 'value';
  entries.sort((a, b) {
    dynamic valA, valB;
    int cmp;
    if (byValue) {
      valA = a.value.toString();
      valB = b.value.toString();
    } else {
      valA = a.key.toString();
      valB = b.key.toString();
    }

    if (!caseSensitive) {
      cmp = valA.toString().toLowerCase().compareTo(
        valB.toString().toLowerCase(),
      );
      if (cmp == 0) cmp = valA.toString().compareTo(valB.toString());
    } else {
      // Case-sensitive in Jinja2/Python: 'A' < 'a'
      cmp = valA.toString().compareTo(valB.toString());
    }
    return reverse ? -cmp : cmp;
  });

  return JinjaList(
    entries
        .map(
          (e) => JinjaTuple([
            e.key is JinjaStringValue
                ? e.key
                : JinjaStringValue.fromString(e.key.toString()),
            e.value,
          ]),
        )
        .toList(),
  );
}

JinjaValue _upper(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  if (v is JinjaStringValue || hasRawInput(stringOf(v))) {
    return JinjaStringValue(_asString(args).value.toUpperCase());
  }
  return JinjaStringValue.fromString(v.toString().toUpperCase());
}

JinjaValue _lower(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  if (v is JinjaStringValue || hasRawInput(stringOf(v))) {
    return JinjaStringValue(_asString(args).value.toLowerCase());
  }
  return JinjaStringValue.fromString(v.toString().toLowerCase());
}

JinjaValue _indent(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final source = rawOf(stringOf(args[0]));
  final str = source.toString();
  final width = args.length > 1 ? args[1] : kwargs['width'];
  final first = args.length > 2
      ? args[2].asBool
      : (kwargs['first']?.asBool ?? false);
  final blank = args.length > 3
      ? args[3].asBool
      : (kwargs['blank']?.asBool ?? false);

  final indentStr = width is JinjaStringValue
      ? width.value
      : JinjaString.template(' ' * (width?.asInt ?? 4));
  // Each line as a slice of [source], and the newline after it.
  final lines = <JinjaString>[];
  final newlines = <JinjaString>[];
  if (str.isNotEmpty) {
    var start = 0;
    for (final m in '\n'.allMatches(str)) {
      lines.add(source.substring(start, m.start));
      newlines.add(source.substring(m.start, m.end));
      start = m.end;
    }
    lines.add(source.substring(start));
  }
  final trailingNewline = str.endsWith('\n');
  if (trailingNewline) lines.removeLast();
  final out = <JinjaString>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i > 0) out.add(newlines[i - 1]);
    if (i == 0 ? first : (line.length > 0 || blank)) out.add(indentStr);
    out.add(line);
  }
  if (trailingNewline) {
    out.add(newlines.last);
    if (blank) out.add(indentStr);
  }

  return _derivedFrom(
    args[0],
    JinjaString([for (final piece in out) ...rawOf(piece).parts]),
    [indentStr],
  );
}

JinjaValue _string(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  return _asString(args);
}

JinjaValue _strftime_now(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) {
    throw Exception('strftime_now expects a format string');
  }
  final format = args[0];
  if (format is! JinjaStringValue) {
    throw Exception('strftime_now expects a string, got ${format.typeName}');
  }
  final result = strftime(format.toString(), DateTime.now());
  // llama.cpp formats into a 100-byte buffer and fails on an empty result.
  if (result.isEmpty || utf8.encode(result).length >= 100) {
    throw Exception('strftime_now: failed to format time');
  }
  // Text of an input-marked format may pass through, so it is escaped.
  if (hasRawInput(format.value)) {
    return JinjaStringValue(JinjaString.user(result));
  }
  return JinjaStringValue(JinjaString.from(result, isSafe: true));
}

JinjaValue _testIsTrue(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(v is JinjaBoolean && v.value == true);
}

JinjaValue _testIsFalse(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(v is JinjaBoolean && v.value == false);
}

JinjaValue _truncate(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final s = args[0].toString();
  final length =
      kwargs['length']?.asInt ?? (args.length > 1 ? args[1].asInt : 255);
  final killwords =
      kwargs['killwords']?.asBool ?? (args.length > 2 ? args[2].asBool : false);
  final endArg = kwargs['end'] ?? (args.length > 3 ? args[3] : null);
  final end = endArg == null ? JinjaString.template('...') : stringOf(endArg);

  if (s.length <= length) return args[0];

  int keep;
  if (killwords) {
    keep = length - end.length;
  } else {
    // find last whitespace before length
    int lastSpace = s.lastIndexOf(' ', length - end.length);
    if (lastSpace == -1) {
      keep = length - end.length;
    } else {
      keep = lastSpace;
    }
  }
  final kept = s.substring(0, keep);
  return JinjaStringValue(
    joinRaw([stringOf(args[0]).substring(0, kept.length), end]),
  );
}

JinjaValue _wordcount(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final s = args[0].toString().trim();
  if (s.isEmpty) return const JinjaInteger(0);
  return JinjaInteger(s.split(RegExp(r'\s+')).length);
}

JinjaValue _yesno(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  return JinjaStringValue.fromString(args[0].asBool ? 'yes' : 'no');
}

JinjaValue _testIsDivisibleBy(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  final n = args[1].asInt;
  if (n == 0) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].asInt % n == 0);
}

JinjaValue _testIsLower(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final s = args[0].toString();
  return JinjaBoolean(s == s.toLowerCase() && s != s.toUpperCase());
}

JinjaValue _testIsUpper(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final s = args[0].toString();
  return JinjaBoolean(s == s.toUpperCase() && s != s.toLowerCase());
}

JinjaValue _testIsSameAs(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  _requireTestArgument(args);
  return JinjaBoolean(identical(args[0], args[1]) || args[0] == args[1]);
}

JinjaValue _testIsCallable(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].isCallable);
}

// End of builtins.dart
