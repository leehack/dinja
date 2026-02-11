// ignore_for_file: non_constant_identifier_names
import '../types/value.dart';
import '../types/jinja_string.dart';
import 'dart:math' as math;
import 'dart:convert';

// Global built-ins map
final Map<String, JinjaFunctionHandler> globalBuiltins = {
  // Functions & Filters
  'range': _range,
  'tojson': _tojson,
  'json_encode': _tojson, // Alias
  'slice': _slice,
  'dict': _dict,
  'list': _list,
  'int': _int,
  'float': _float,
  'str': _str,
  'len': _len, // Python style
  'length': _len, // Jinja style
  'count': _len,
  'first': _first,
  'last': _last,
  'min': _min,
  'max': _max,
  'sum': _sum,
  'abs': _abs,
  'round': _round,
  'default': _default,
  'd': _default, // Alias
  'sort': _sort,
  'unique': _unique,
  'reverse': _reverse,
  'map': _map,
  'selectattr': _selectattr,
  'rejectattr': _rejectattr,
  'attr': _attr,
  'join': _join,
  'safe': _safe,
  'items': _items, // dict items as filter
  'keys': _keys,
  'values': _values,
  'strip': _strip,
  'trim': _strip,
  'lstrip': _lstrip,
  'rstrip': _rstrip,
  'namespace': _namespace,
  'raise_exception': _raiseException,

  // Tests (prefixed with test_is_)
  'test_is_defined': _testIsDefined,
  'test_is_undefined': _testIsUndefined,
  'test_is_none': _testIsNone,
  'test_is_boolean': _testIsBoolean,
  'test_is_integer': _testIsInteger,
  'test_is_float': _testIsFloat,
  'test_is_string': _testIsString,
  'test_is_number': _testIsNumber,
  'test_is_iterable': _testIsIterable,
  'test_is_sequence': _testIsSequence,
  'test_is_mapping': _testIsMapping,
  'test_is_startingwith': _testIsStartingWith,
  'test_is_endingwith': _testIsEndingWith,
  'test_is_equalto': _testIsEqualTo,
  'test_is_eq': _testIsEqualTo,
  'test_is_ieq': _testIsIequalTo,
  'test_is_ne': _testIsNotEqualTo,
  'test_is_gt': _testIsGreaterThan,
  'test_is_ge': _testIsGreaterThanOrEqual,
  'test_is_lt': _testIsLessThan,
  'test_is_le': _testIsLessThanOrEqual,
  'test_is_in': _testIsIn,
  'test_is_odd': _testIsOdd,
  'test_is_even': _testIsEven,
  'dictsort': _dictsort,
  'upper': _upper,
  'lower': _lower,
  'indent': _indent,
  'string': _string,
  'strftime_now': _strftime_now,

  'test_is_true': _testIsTrue,
  'test_is_false': _testIsFalse,
  'replace': _replaceFilter,
};

/// Resolves a member method on a value (e.g., list.append).
/// Returns a bound function (closure) or null if not found.
JinjaValue? resolveMember(JinjaValue obj, String name) {
  if (obj is JinjaList) return _resolveListMember(obj, name);
  if (obj is JinjaMap) return _resolveMapMember(obj, name);
  if (obj is JinjaStringValue) return _resolveStringMember(obj, name);
  if (obj is JinjaNone) return _resolveNoneMember(obj, name);
  if (obj is JinjaUndefined) return _resolveUndefinedMember(obj, name);
  return null;
}

// Implementations

JinjaValue _replaceFilter(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final obj = args[0];
  if (args.length < 3) return obj;
  final oldVal = args[1].toString();
  final newVal = args[2].toString();
  return JinjaStringValue(
    JinjaString.from(
      obj.toString().replaceAll(oldVal, newVal),
      isSafe: obj.isSafe,
    ),
  );
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
  if (args.isEmpty) throw Exception('tojson expects at least 1 argument');
  final val = args[0];
  final indent = kwargs['indent']?.asInt;
  final encoder = indent != null
      ? JsonEncoder.withIndent(' ' * indent)
      : const JsonEncoder();
  return JinjaStringValue(
    JinjaString.from(encoder.convert(val.toDart()), isSafe: true),
  );
}

JinjaValue _slice(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  return const JinjaNone();
}

JinjaValue _dict(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  return JinjaMap(kwargs);
}

JinjaValue _list(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final arg = args[0];
  if (arg is JinjaList) return arg;
  if (arg is JinjaTuple) return JinjaList(List.from(arg.items));
  if (arg is JinjaStringValue) {
    return JinjaList(
      arg.value.parts
          .map((p) => p.val)
          .expand((s) => s.split(''))
          .map((c) => JinjaStringValue.fromString(c))
          .toList(),
    );
  }
  if (arg is JinjaMap) {
    // list(dict) -> keys
    return JinjaList(
      arg.items.keys.map((k) => JinjaStringValue.fromString(k)).toList(),
    );
  }
  return JinjaList([
    arg,
  ]); // Wrap others? Or error? Standard Jinja tries to iterate.
}

JinjaValue _int(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final v = args[0];
  try {
    if (v is JinjaStringValue) return JinjaInteger(int.parse(v.toString()));
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
  return JinjaStringValue.fromString(args[0].toString());
}

JinjaValue _len(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaInteger(0);
  final v = args[0];
  if (v is JinjaList) return JinjaInteger(v.items.length);
  if (v is JinjaMap) return JinjaInteger(v.items.length);
  if (v is JinjaStringValue) return JinjaInteger(v.value.length);
  if (v is JinjaTuple) return JinjaInteger(v.items.length);
  return const JinjaInteger(0);
}

JinjaValue _first(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final v = args[0];
  if (v is JinjaList && v.items.isNotEmpty) return v.items.first;
  if (v is JinjaStringValue && v.value.length > 0) {
    return JinjaStringValue.fromString(v.value.toString()[0]);
  }
  if (v is JinjaTuple && v.items.isNotEmpty) return v.items.first;
  return const JinjaUndefined();
}

JinjaValue _last(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final v = args[0];
  if (v is JinjaList && v.items.isNotEmpty) return v.items.last;
  if (v is JinjaStringValue && v.value.length > 0) {
    return JinjaStringValue.fromString(
      v.value.toString().substring(v.value.length - 1),
    );
  }
  if (v is JinjaTuple && v.items.isNotEmpty) return v.items.last;
  return const JinjaUndefined();
}

JinjaValue _min(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final collection = args[0];
  final attribute = kwargs['attribute']?.toString();

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
    return attribute != null ? mVal : m;
  }
  return collection;
}

JinjaValue _max(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final collection = args[0];
  final attribute = kwargs['attribute']?.toString();

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
    return attribute != null ? mVal : m;
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
  final attribute = kwargs['attribute']?.toString();
  double startValue = kwargs['start']?.asDouble ?? 0.0;

  double total = startValue;
  bool isFloat = kwargs['start'] is JinjaFloat;

  if (collection is JinjaList || collection is JinjaTuple) {
    final items = collection is JinjaList
        ? collection.asList
        : collection.asList;
    for (final item in items) {
      final val = attribute != null ? _resolveAttribute(item, attribute) : item;
      if (val.isNumeric) {
        total += val.asDouble;
        if (val is JinjaFloat) isFloat = true;
      }
    }
  }
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

  if (v.isUndefined || (boolVal && !v.asBool)) return defaultVal;
  return v;
}

JinjaValue _sort(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
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
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);
  final caseSensitive = kwargs['case_sensitive']?.asBool ?? true;

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;

  final seen = <String, JinjaValue>{};
  final result = <JinjaValue>[];

  for (final item in items) {
    final val = attribute != null ? _resolveAttribute(item, attribute) : item;
    String key = val.toString();
    if (!caseSensitive) {
      key = key.toLowerCase();
    }
    if (!seen.containsKey(key)) {
      seen[key] = item;
      result.add(item);
    }
  }
  return JinjaList(result);
}

JinjaValue _reverse(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaList) return JinjaList(v.items.reversed.toList());
  if (v is JinjaStringValue) {
    return JinjaStringValue.fromString(
      v.value.toString().split('').reversed.join(''),
    );
  }
  return v;
}

JinjaValue _map(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? (collection).items
      : (collection as JinjaTuple).items;

  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);
  final defaultVal = kwargs['default'] ?? (args.length > 2 ? args[2] : null);

  if (attribute == null || attribute.isEmpty) return collection;

  final result = <JinjaValue>[];
  for (final item in items) {
    var val = _resolveAttribute(item, attribute);
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
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? (collection).items
      : (collection as JinjaTuple).items;
  final attribute = args.length > 1 ? args[1].toString() : null;
  final testName = args.length > 2 ? args[2].toString() : null;
  final testVal = args.length > 3 ? args[3] : null;

  final result = <JinjaValue>[];
  for (final item in items) {
    JinjaValue target = item;
    if (attribute != null && attribute.isNotEmpty) {
      target = _resolveAttribute(item, attribute);
    }

    bool matched = false;
    if (testName == null) {
      matched = target.asBool;
    } else {
      final testFunc = globalBuiltins['test_is_$testName'];
      if (testFunc != null) {
        final testArgs = [target];
        if (testVal != null) testArgs.add(testVal);
        matched = testFunc(testArgs, {}).asBool;
      }
    }

    if (matched) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _rejectattr(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final collection = args[0];
  if (collection is! JinjaList && collection is! JinjaTuple) return collection;

  final items = collection is JinjaList
      ? (collection).items
      : (collection as JinjaTuple).items;
  final attribute = args.length > 1 ? args[1].toString() : null;
  final testName = args.length > 2 ? args[2].toString() : null;
  final testVal = args.length > 3 ? args[3] : null;

  final result = <JinjaValue>[];
  for (final item in items) {
    JinjaValue target = item;
    if (attribute != null && attribute.isNotEmpty) {
      target = _resolveAttribute(item, attribute);
    }

    bool matched = false;
    if (testName == null) {
      matched = target.asBool;
    } else {
      final testFunc = globalBuiltins['test_is_$testName'];
      if (testFunc != null) {
        final testArgs = [target];
        if (testVal != null) testArgs.add(testVal);
        matched = testFunc(testArgs, {}).asBool;
      }
    }

    if (!matched) result.add(item);
  }
  return JinjaList(result);
}

JinjaValue _attr(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaUndefined();
  final obj = args[0];
  final name = args.length > 1 ? args[1].toString() : '';

  if (obj is JinjaMap) return obj.items[name] ?? const JinjaUndefined();
  return const JinjaUndefined();
}

JinjaValue _join(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final collection = args[0];
  if (collection is! JinjaList && collection is! JinjaTuple) {
    return JinjaStringValue.fromString(collection.toString());
  }

  final delimiter =
      (kwargs['d'] ?? (args.length > 1 ? args[1] : null))?.toString() ?? '';
  final attribute =
      kwargs['attribute']?.toString() ??
      (args.length > 2 ? args[2].toString() : null);

  final items = collection is JinjaList
      ? collection.items
      : (collection as JinjaTuple).items;

  final strings = items
      .map((e) {
        final val = attribute != null ? _resolveAttribute(e, attribute) : e;
        return val.toString();
      })
      .join(delimiter);

  return JinjaStringValue.fromString(strings);
}

JinjaValue _safe(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) {
    return const JinjaStringValue(JinjaString([], isSafe: true));
  }
  final v = args[0];
  if (v is JinjaStringValue) {
    return JinjaStringValue(v.value.markSafe());
  }
  return JinjaStringValue(JinjaString.from(v.toString(), isSafe: true));
}

JinjaValue _items(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaMap) {
    return JinjaList(
      v.items.entries
          .map((e) => JinjaTuple([JinjaStringValue.fromString(e.key), e.value]))
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
      v.items.keys.map((k) => JinjaStringValue.fromString(k)).toList(),
    );
  }
  return const JinjaList([]);
}

JinjaValue _values(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaList([]);
  final v = args[0];
  if (v is JinjaMap) return JinjaList(v.items.values.toList());
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

JinjaValue _testIsNumber(
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
  return JinjaBoolean(v.isList || v.isMap || v.isString);
}

JinjaValue _testIsSequence(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.isEmpty) return const JinjaBoolean(false);
  final v = args[0];
  return JinjaBoolean(v.isList || v.isString);
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
  if (args.length < 2) return const JinjaBoolean(false);
  final str = args[0].toString();
  final prefix = args[1].toString();
  return JinjaBoolean(str.startsWith(prefix));
}

JinjaValue _testIsEndingWith(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  final str = args[0].toString();
  final suffix = args[1].toString();
  return JinjaBoolean(str.endsWith(suffix));
}

JinjaValue _testIsEqualTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].toString() == args[1].toString());
}

JinjaValue _testIsIequalTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  return JinjaBoolean(
    args[0].toString().toLowerCase() == args[1].toString().toLowerCase(),
  );
}

JinjaValue _testIsNotEqualTo(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].toString() != args[1].toString());
}

JinjaValue _testIsGreaterThan(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble > args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsGreaterThanOrEqual(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble >= args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsLessThan(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble < args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsLessThanOrEqual(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  if (args.length < 2) return const JinjaBoolean(false);
  if (args[0].isNumeric && args[1].isNumeric) {
    return JinjaBoolean(args[0].asDouble <= args[1].asDouble);
  }
  return const JinjaBoolean(false);
}

JinjaValue _testIsIn(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.length < 2) return const JinjaBoolean(false);
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
    return JinjaBoolean(collection.items.containsKey(item.toString()));
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
  final v = args[0];
  if (v is JinjaInteger) return JinjaBoolean(v.value.isEven);
  if (v.isNumeric) return JinjaBoolean(v.asInt.isEven);
  return const JinjaBoolean(false);
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

        final seen = <String, JinjaValue>{};
        final result = <JinjaValue>[];

        for (final item in obj.items) {
          final val = attribute != null
              ? _resolveAttribute(item, attribute)
              : item;
          String key = val.toString();
          if (!caseSensitive) key = key.toLowerCase();

          if (!seen.containsKey(key)) {
            seen[key] = item;
            result.add(item);
          }
        }
        return JinjaList(result);
      });
  }
  return null;
}

JinjaValue? _resolveMapMember(JinjaMap obj, String name) {
  switch (name) {
    case 'keys':
      return JinjaFunction('keys', (args, kwargs) {
        return JinjaList(
          obj.items.keys.map((k) => JinjaStringValue.fromString(k)).toList(),
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
                (e) =>
                    JinjaTuple([JinjaStringValue.fromString(e.key), e.value]),
              )
              .toList(),
        );
      });
    case 'get':
      return JinjaFunction('get', (args, kwargs) {
        if (args.isEmpty) throw Exception('get expects key');
        final key = args[0].toString();
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
        final delimiter = args.isNotEmpty ? args[0].toString() : ' ';
        // Python split behavior is subtle with empty delimiter or None?
        // Jinja split(d, limit).
        // For now simple split.
        final parts = obj.value.toString().split(delimiter);
        return JinjaList(
          parts.map((s) => JinjaStringValue.fromString(s)).toList(),
        );
      });
    case 'replace':
      return JinjaFunction('replace', (args, kwargs) {
        if (args.length < 2) return obj;
        final oldVal = args[0].toString();
        final newVal = args[1].toString();
        return JinjaStringValue(
          JinjaString.from(
            obj.value.toString().replaceAll(oldVal, newVal),
            isSafe: obj.value.isSafe,
          ),
        );
      });
  }
  return null;
}

JinjaValue _strip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trim());
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
  return JinjaStringValue.fromString(s.substring(start, end));
}

JinjaValue _lstrip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trimLeft());
    return JinjaStringValue.fromString(v.toString().trimLeft());
  }

  String s = v.toString();
  final charSet = chars.split('').toSet();
  int start = 0;
  while (start < s.length && charSet.contains(s[start])) {
    start++;
  }
  return JinjaStringValue.fromString(s.substring(start));
}

JinjaValue _rstrip(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final chars =
      kwargs['chars']?.toString() ??
      (args.length > 1 ? args[1].toString() : null);

  if (chars == null) {
    if (v is JinjaStringValue) return JinjaStringValue(v.value.trimRight());
    return JinjaStringValue.fromString(v.toString().trimRight());
  }

  String s = v.toString();
  final charSet = chars.split('').toSet();
  int end = s.length;
  while (end > 0 && charSet.contains(s[end - 1])) {
    end--;
  }
  return JinjaStringValue.fromString(s.substring(0, end));
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

JinjaValue? _resolveUndefinedMember(JinjaUndefined obj, String name) {
  // undefined methods mostly return undefined or empty
  return JinjaFunction(name, (args, kwargs) => const JinjaUndefined());
}

JinjaValue _namespace(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  final Map<String, JinjaValue> items = {};
  if (args.isNotEmpty) {
    final arg = args[0];
    if (arg is JinjaMap) {
      items.addAll(arg.asMap);
    }
  }
  items.addAll(kwargs);
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
  entries.sort((a, b) {
    dynamic valA, valB;
    if (by == 'value') {
      valA = a.value.toString();
      valB = b.value.toString();
    } else {
      valA = a.key;
      valB = b.key;
    }

    if (!caseSensitive && valA is String && valB is String) {
      valA = valA.toLowerCase();
      valB = valB.toLowerCase();
    }

    final c = valA.compareTo(valB);
    return reverse ? -c : c;
  });

  return JinjaList(
    entries
        .map((e) => JinjaTuple([JinjaStringValue.fromString(e.key), e.value]))
        .toList(),
  );
}

JinjaValue _upper(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  if (v is JinjaStringValue) {
    return JinjaStringValue(v.value.toUpperCase());
  }
  return JinjaStringValue.fromString(v.toString().toUpperCase());
}

JinjaValue _lower(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  if (v is JinjaStringValue) {
    return JinjaStringValue(v.value.toLowerCase());
  }
  return JinjaStringValue.fromString(v.toString().toLowerCase());
}

JinjaValue _indent(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final str = args[0].toString();
  final width = args.length > 1 ? args[1].asInt : (kwargs['width']?.asInt ?? 4);
  final first = args.length > 2
      ? args[2].asBool
      : (kwargs['first']?.asBool ?? false);
  final blank = args.length > 3
      ? args[3].asBool
      : (kwargs['blank']?.asBool ?? false);

  final indentStr = ' ' * width;
  final lines = str.split('\n');
  final buffer = StringBuffer();

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty && !blank) {
      buffer.writeln(line);
      continue;
    }

    if (i == 0 && !first) {
      buffer.write(line);
    } else {
      buffer.write('$indentStr$line');
    }

    if (i < lines.length - 1) {
      buffer.write('\n');
    }
  }

  return JinjaStringValue.fromString(buffer.toString());
}

JinjaValue _string(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  return JinjaStringValue.fromString(args[0].toString());
}

JinjaValue _strftime_now(
  List<JinjaValue> args,
  Map<String, JinjaValue> kwargs,
) {
  final format = args.isNotEmpty ? args[0].toString() : '%Y-%m-%d %H:%M:%S';
  final now = DateTime.now();
  final result = format
      .replaceAll('%Y', now.year.toString())
      .replaceAll('%m', now.month.toString().padLeft(2, '0'))
      .replaceAll('%d', now.day.toString().padLeft(2, '0'))
      .replaceAll('%H', now.hour.toString().padLeft(2, '0'))
      .replaceAll('%M', now.minute.toString().padLeft(2, '0'))
      .replaceAll('%S', now.second.toString().padLeft(2, '0'));
  return JinjaStringValue(JinjaString.from(result, isSafe: true));
}

JinjaValue _testIsTrue(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(args[0].asBool);
}

JinjaValue _testIsFalse(List<JinjaValue> args, Map<String, JinjaValue> kwargs) {
  if (args.isEmpty) return const JinjaBoolean(false);
  return JinjaBoolean(!args[0].asBool);
}

JinjaValue _resolveAttribute(JinjaValue item, String attribute) {
  if (attribute.isEmpty) return item;
  if (item is JinjaMap) {
    return item.items[attribute] ?? const JinjaUndefined();
  }

  // Handle numeric index access for lists and tuples (e.g., map(attribute='0'))
  final index = int.tryParse(attribute);
  if (index != null) {
    if (item is JinjaList && index >= 0 && index < item.items.length) {
      return item.items[index];
    }
    if (item is JinjaTuple && index >= 0 && index < item.items.length) {
      return item.items[index];
    }
  }

  if (item is JinjaStringValue && attribute == 'length') {
    return JinjaInteger(item.value.length);
  }
  if (item is JinjaList && attribute == 'length') {
    return JinjaInteger(item.items.length);
  }
  if (item is JinjaTuple && attribute == 'length') {
    return JinjaInteger(item.items.length);
  }
  return const JinjaUndefined();
}
