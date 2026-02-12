import 'package:meta/meta.dart';

import 'jinja_string.dart';

/// Base class for all runtime values under the Dinja type system.
@immutable
abstract class JinjaValue {
  const JinjaValue();

  /// Whether this value is the special 'env' object.
  bool get isEnv => false;

  /// Optional name for this value (e.g. 'env').
  String? get name => null;

  /// Returns the type name for debugging and error messages (e.g., 'String', 'List').
  String get typeName;

  /// Returns the truthy value of this object (for if/elif conditions).
  bool get asBool;

  /// Returns a string representation for debugging (like Python's repr()).
  String get asRepr => toString();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  /// Returns true if this value is considered "safe" (not needing escaping).
  bool get isSafe => false;

  // Type identification helpers
  bool get isNone => false;
  bool get isUndefined => false;
  bool get isNumeric => false;
  bool get isString => false;
  bool get isList => false;
  bool get isMap => false;
  bool get isCallable => false;

  // Conversion helpers (throw if not applicable)
  // We use standard Dart types for return where possible, or JinjaString
  int get asInt => throw Exception('$typeName is not an integer');
  double get asDouble => throw Exception('$typeName is not a float');
  JinjaString get asJinjaString => throw Exception('$typeName is not a string');
  List<JinjaValue> get asList => throw Exception('$typeName is not a list');
  Map<String, JinjaValue> get asMap =>
      throw Exception('$typeName is not a map');

  /// Returns a custom attribute of this value, or null if not found.
  /// Used for objects like `loop` that expose properties but aren't maps.
  JinjaValue? getAttribute(String name) => null;

  /// Converts this JinjaValue to a raw Dart object (Map, List, String, etc.).
  Object? toDart() {
    final v = this;
    if (v is JinjaNone || v is JinjaUndefined) return null;
    if (v is JinjaBoolean) return v.value;
    if (v is JinjaInteger) return v.value;
    if (v is JinjaFloat) return v.value;
    if (v is JinjaStringValue) return v.toString();
    if (v is JinjaList) return v.items.map((e) => e.toDart()).toList();
    if (v is JinjaTuple) return v.items.map((e) => e.toDart()).toList();
    if (v is JinjaMap) return v.items.map((k, v) => MapEntry(k, v.toDart()));
    return v.toString();
  }
}

class JinjaUndefined extends JinjaValue {
  final String hint;

  const JinjaUndefined([this.hint = '']);

  @override
  String get typeName => hint.isEmpty ? 'Undefined' : 'Undefined(hint: $hint)';

  @override
  bool get asBool => false;

  @override
  bool get isUndefined => true;

  @override
  bool operator ==(Object other) => other is JinjaUndefined;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => '';

  @override
  Object? toDart() => null;
}

class JinjaNone extends JinjaValue {
  const JinjaNone();

  @override
  String get typeName => 'None';

  @override
  bool get asBool => false;

  @override
  bool get isNone => true;

  @override
  bool operator ==(Object other) => other is JinjaNone;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'None';

  @override
  Object? toDart() => null;
}

class JinjaBoolean extends JinjaValue {
  final bool value;

  const JinjaBoolean(this.value);

  @override
  String get typeName => 'Boolean';

  @override
  bool get asBool => value;

  @override
  int get asInt => value ? 1 : 0;

  @override
  double get asDouble => value ? 1.0 : 0.0;

  @override
  bool get isNumeric => true; // Booleans are numeric in Jinja (True=1, False=0)

  @override
  bool operator ==(Object other) {
    if (other is JinjaBoolean) return value == other.value;
    if (other is JinjaInteger) return (value ? 1 : 0) == other.value;
    if (other is JinjaFloat) return (value ? 1.0 : 0.0) == other.value;
    return false;
  }

  @override
  int get hashCode => (value ? 1.0 : 0.0).hashCode;

  @override
  String toString() => value ? 'True' : 'False';

  @override
  Object? toDart() => value;
}

class JinjaInteger extends JinjaValue {
  final int value;

  const JinjaInteger(this.value);

  @override
  String get typeName => 'Integer';

  @override
  bool get asBool => value != 0;

  @override
  int get asInt => value;

  @override
  double get asDouble => value.toDouble();

  @override
  bool get isNumeric => true;

  @override
  bool operator ==(Object other) {
    if (other is JinjaInteger) return value == other.value;
    if (other is JinjaFloat) return value.toDouble() == other.value;
    if (other is JinjaBoolean) return value == (other.value ? 1 : 0);
    return false;
  }

  @override
  int get hashCode => value.toDouble().hashCode;

  @override
  String toString() => value.toString();

  @override
  Object? toDart() => value;
}

class JinjaFloat extends JinjaValue {
  final double value;

  const JinjaFloat(this.value);

  @override
  String get typeName => 'Float';

  @override
  bool get asBool => value != 0.0;

  @override
  int get asInt => value.toInt();

  @override
  double get asDouble => value;

  @override
  bool get isNumeric => true;

  @override
  bool operator ==(Object other) {
    if (other is JinjaFloat) return value == other.value;
    if (other is JinjaInteger) return value == other.value.toDouble();
    if (other is JinjaBoolean) return value == (other.value ? 1.0 : 0.0);
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    // Mimic Python/Jinja float formatting (remove trailing .0 if integer)
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  @override
  Object? toDart() => value;
}

class JinjaStringValue extends JinjaValue {
  final JinjaString value;

  const JinjaStringValue(this.value);

  factory JinjaStringValue.fromString(String s) =>
      JinjaStringValue(JinjaString.from(s));

  @override
  String get typeName => 'String';

  @override
  bool get asBool => value.length > 0;

  @override
  JinjaString get asJinjaString => value;

  @override
  bool get isString => true;

  @override
  String get asRepr => "'${value.toString().replaceAll("'", "\\'")}'";

  @override
  bool get isSafe => value.isSafe;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JinjaStringValue && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();

  @override
  Object? toDart() => value.toString();
}

class JinjaList extends JinjaValue {
  final List<JinjaValue> items;

  const JinjaList(this.items);

  @override
  String get typeName => 'List';

  @override
  bool get asBool => items.isNotEmpty;

  @override
  List<JinjaValue> get asList => items;

  @override
  bool get isList => true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JinjaList) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int h = 0;
    for (final i in items) {
      h ^= i.hashCode;
    }
    return h;
  }

  @override
  String toString() {
    return '[${items.map((e) => e.asRepr).join(', ')}]';
  }

  @override
  Object? toDart() => items.map((e) => e.toDart()).toList();
}

class JinjaMap extends JinjaValue {
  final Map<JinjaValue, JinjaValue> items;
  @override
  final String? name;

  const JinjaMap(this.items, {this.name});

  @override
  bool get isEnv => name == 'env';

  @override
  String get typeName => 'Map';

  @override
  bool get asBool => items.isNotEmpty;

  @override
  Map<String, JinjaValue> get asMap =>
      items.map((k, v) => MapEntry(k.toString(), v));

  Map<JinjaValue, JinjaValue> get asJinjaMap => items;

  @override
  bool get isMap => true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JinjaMap) return false;
    if (items.length != other.items.length) return false;
    for (final key in items.keys) {
      if (!other.items.containsKey(key)) return false;
      if (items[key] != other.items[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int h = 0;
    for (final entry in items.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }

  @override
  String toString() {
    return '{${items.entries.map((e) => '${e.key.asRepr}: ${e.value.asRepr}').join(', ')}}';
  }

  @override
  Object? toDart() => items.map((k, v) => MapEntry(k.toDart(), v.toDart()));
}

// Helper to create values easily
JinjaValue val(Object? v) {
  if (v == null) return const JinjaNone();
  if (v is JinjaValue) return v;
  if (v is JinjaString) return JinjaStringValue(v);
  if (v is bool) return JinjaBoolean(v);
  if (v is int) return JinjaInteger(v);
  if (v is double) return JinjaFloat(v);
  if (v is String) return JinjaStringValue.fromString(v);
  if (v is List) {
    return JinjaList(v.map(val).toList());
  }
  if (v is Map) {
    return JinjaMap(v.map((k, v) => MapEntry(val(k), val(v))));
  }
  return JinjaStringValue.fromString(v.toString());
}

class JinjaTuple extends JinjaValue {
  final List<JinjaValue> items;

  const JinjaTuple(this.items);

  @override
  String get typeName => 'Tuple';

  @override
  bool get asBool => items.isNotEmpty;

  @override
  List<JinjaValue> get asList => items;

  @override
  bool get isList => true; // Tuples are iterable sequences

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JinjaTuple) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int h = 0;
    for (final i in items) {
      h ^= i.hashCode;
    }
    return h;
  }

  @override
  String toString() {
    return '(${items.map((e) => e.asRepr).join(', ')})';
  }

  @override
  Object? toDart() => items.map((e) => e.toDart()).toList();
}

class JinjaLoopContext extends JinjaValue {
  final Map<String, JinjaValue> state;
  const JinjaLoopContext(this.state);

  @override
  String get typeName => 'LoopContext';

  @override
  bool get asBool => true;

  @override
  JinjaValue? getAttribute(String name) => state[name];

  @override
  String toString() => '<loop context>';

  @override
  Object? toDart() => state;
}

typedef JinjaFunctionHandler =
    JinjaValue Function(List<JinjaValue> args, Map<String, JinjaValue> kwargs);

class JinjaFunction extends JinjaValue {
  @override
  final String name;
  final JinjaFunctionHandler handler;

  const JinjaFunction(this.name, this.handler);

  @override
  String get typeName => 'Function';

  @override
  bool get asBool => true;

  @override
  bool get isCallable => true;

  @override
  String toString() => '<function $name>';

  @override
  Object? toDart() => null; // Functions cannot be converted to Dart objects easily
}
