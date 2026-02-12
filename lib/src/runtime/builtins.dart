// ignore_for_file: non_constant_identifier_names
import '../types/value.dart';
import '../types/jinja_string.dart';
import 'dart:math' as math;
import 'dart:convert';

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
  'string': _string,
  'title': (args, kwargs) =>
      (_resolveStringMember(
                args.isNotEmpty && args[0] is JinjaStringValue
                    ? args[0] as JinjaStringValue
                    : JinjaStringValue.fromString(
                        args.isNotEmpty ? args[0].toString() : '',
                      ),
                'title',
              )
              as JinjaFunction)
          .handler(args, kwargs),
  'capitalize': (args, kwargs) =>
      (_resolveStringMember(
                args.isNotEmpty && args[0] is JinjaStringValue
                    ? args[0] as JinjaStringValue
                    : JinjaStringValue.fromString(
                        args.isNotEmpty ? args[0].toString() : '',
                      ),
                'capitalize',
              )
              as JinjaFunction)
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
  if (args.isEmpty) return const JinjaStringValue(JinjaString([]));
  final v = args[0];
  final indent = kwargs['indent']?.asInt;
  final sortKeys = kwargs['sort_keys']?.asBool ?? false;
  final ensureAscii = kwargs['ensure_ascii']?.asBool ?? true;

  Object? data = v.toDart();
  if (sortKeys) {
    data = _sortJsonData(data);
  }

  String itemSep = indent == null ? ',' : ', ';
  String keySep = indent == null ? ':' : ': ';

  final separatorsArg = kwargs['separators'];
  if (separatorsArg is JinjaList || separatorsArg is JinjaTuple) {
    final items = separatorsArg is JinjaList
        ? separatorsArg.items
        : (separatorsArg as JinjaTuple).items;
    if (items.length >= 2) {
      itemSep = items[0].toString();
      keySep = items[1].toString();
    }
  }

  final encoder = indent != null
      ? JsonEncoder.withIndent(' ' * indent)
      : const JsonEncoder();

  String result = encoder.convert(data);

  if (indent != null) {
    if (itemSep != ', ' || keySep != ': ') {
      result = result.replaceAll(', ', itemSep).replaceAll(': ', keySep);
    }
  } else {
    if (itemSep != ',' || keySep != ':') {
      result = result.replaceAll(',', itemSep).replaceAll(':', keySep);
    }
  }

  if (ensureAscii) {
    result = _ensureAscii(result);
  }

  return JinjaStringValue(
    JinjaString([JinjaStringPart(result, false)], isSafe: true),
  );
}

String _ensureAscii(String s) {
  var res = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    var char = s[i];
    var code = char.codeUnitAt(0);
    if (code > 127) {
      res.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
    } else {
      res.write(char);
    }
  }
  return res.toString();
}

Object? _sortJsonData(Object? data) {
  if (data is Map) {
    final sortedKeys = data.keys.toList()..sort();
    final result = <String, dynamic>{};
    for (final key in sortedKeys) {
      result[key.toString()] = _sortJsonData(data[key]);
    }
    return result;
  } else if (data is List) {
    return data.map((e) => _sortJsonData(e)).toList();
  }
  return data;
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
  return JinjaStringValue.fromString(args[0].toString());
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

  if (v.isUndefined || (boolVal && !v.asBool)) return defaultVal;
  return v;
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
  return JinjaBoolean(args[0].isSafe);
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

        String s = obj.value.toString();
        List<String> parts;
        if (delimiter == null || delimiter == ' ') {
          // split by whitespace
          parts = s.trim().split(RegExp(r'\s+'));
          if (maxsplit >= 0 && parts.length > maxsplit + 1) {
            final rest = parts.sublist(maxsplit).join(' ');
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
              parts.add(s.substring(start, idx));
              start = idx + delimiter.length;
            }
            parts.add(s.substring(start));
          } else {
            parts = s.split(delimiter);
          }
        }

        return JinjaList(
          parts.map((s) => JinjaStringValue.fromString(s)).toList(),
        );
      });
    case 'rsplit':
      return JinjaFunction('rsplit', (args, kwargs) {
        final delimiter = args.isNotEmpty ? args[0].toString() : null;
        final maxsplit =
            kwargs['maxsplit']?.asInt ?? (args.length > 1 ? args[1].asInt : -1);

        String s = obj.value.toString();
        List<String> parts;
        if (delimiter == null || delimiter == ' ') {
          // rsplit by whitespace
          parts = s.trim().split(RegExp(r'\s+'));
          if (maxsplit >= 0 && parts.length > maxsplit + 1) {
            final rest = parts.sublist(0, parts.length - maxsplit).join(' ');
            parts = [rest, ...parts.sublist(parts.length - maxsplit)];
          }
        } else {
          if (maxsplit >= 0) {
            parts = [];
            int end = s.length;
            for (int i = 0; i < maxsplit; i++) {
              int idx = s.lastIndexOf(delimiter, end - 1);
              if (idx == -1) break;
              parts.insert(0, s.substring(idx + delimiter.length, end));
              end = idx;
            }
            parts.insert(0, s.substring(0, end));
          } else {
            parts = s.split(delimiter);
          }
        }
        return JinjaList(
          parts.map((ps) => JinjaStringValue.fromString(ps)).toList(),
        );
      });
    case 'capitalize':
      return JinjaFunction('capitalize', (args, kwargs) {
        final s = obj.value.toString();
        if (s.isEmpty) return obj;
        return JinjaStringValue.fromString(
          s[0].toUpperCase() + s.substring(1).toLowerCase(),
        );
      });
    case 'title':
      return JinjaFunction('title', (args, kwargs) {
        final s = obj.value.toString();
        return JinjaStringValue.fromString(
          s
              .split(' ')
              .map((w) {
                if (w.isEmpty) return w;
                return w[0].toUpperCase() + w.substring(1).toLowerCase();
              })
              .join(' '),
        );
      });
    case 'replace':
      return JinjaFunction('replace', (args, kwargs) {
        if (args.length < 2) return obj;
        final oldVal = args[0].toString();
        final newVal = args[1].toString();
        final count =
            kwargs['count']?.asInt ?? (args.length > 2 ? args[2].asInt : -1);

        String s = obj.value.toString();
        if (count >= 0) {
          String res = s;
          int total = 0;
          int start = 0;
          while (total < count) {
            int idx = res.indexOf(oldVal, start);
            if (idx == -1) break;
            res = res.replaceRange(idx, idx + oldVal.length, newVal);
            start = idx + newVal.length;
            total++;
          }
          return JinjaStringValue(
            JinjaString.from(res, isSafe: obj.value.isSafe),
          );
        }

        return JinjaStringValue(
          JinjaString.from(
            s.replaceAll(oldVal, newVal),
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
  final end =
      kwargs['end']?.toString() ??
      (args.length > 3 ? args[3].toString() : '...');

  if (s.length <= length) return args[0];

  String res;
  if (killwords) {
    res = s.substring(0, length - end.length);
  } else {
    // find last whitespace before length
    int lastSpace = s.lastIndexOf(' ', length - end.length);
    if (lastSpace == -1) {
      res = s.substring(0, length - end.length);
    } else {
      res = s.substring(0, lastSpace);
    }
  }
  return JinjaStringValue.fromString(res + end);
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
  if (args.length < 2) return const JinjaBoolean(false);
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
  if (args.length < 2) return const JinjaBoolean(false);
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
