import 'package:meta/meta.dart';

/// Represents a part of a string, tracking whether it originated from user input.
@immutable
class JinjaStringPart {
  final String val;
  final bool isInput;

  const JinjaStringPart(this.val, this.isInput);

  bool get isUppercase => val == val.toUpperCase();
  bool get isLowercase => val == val.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JinjaStringPart &&
          runtimeType == other.runtimeType &&
          val == other.val &&
          isInput == other.isInput;

  @override
  int get hashCode => val.hashCode ^ isInput.hashCode;

  @override
  String toString() => 'JinjaStringPart(val: "$val", isInput: $isInput)';
}

/// A string wrapper that tracks the origin of its parts (user input vs template).
///
/// This mechanics is the core of Dinja's security model. It distinguishes between
/// trusted template text and untrusted user input, allowing for automatic
/// escaping of the latter to prevent injection attacks.
@immutable
class JinjaString {
  final List<JinjaStringPart> parts;

  /// Whether this string is considered "safe" (not needing further escaping).
  final bool isSafe;

  const JinjaString(this.parts, {this.isSafe = false});

  factory JinjaString.from(
    String val, {
    bool isInput = false,
    bool isSafe = false,
  }) {
    return JinjaString([JinjaStringPart(val, isInput)], isSafe: isSafe);
  }

  /// Creates a JinjaString from a raw string, marking it as template (not input).
  factory JinjaString.template(String val) =>
      JinjaString.from(val, isInput: false);

  /// Creates a JinjaString from a raw string, marking it as user input.
  factory JinjaString.user(String val) => JinjaString.from(val, isInput: true);

  /// Returns the full string content, ignoring input markers.
  @override
  String toString() {
    return parts.map((p) => p.val).join();
  }

  /// The length of the full string.
  int get length => parts.fold(0, (sum, part) => sum + part.val.length);

  /// Returns true if ALL parts of this string are marked as user input.
  bool get allPartsAreInput => parts.every((p) => p.isInput);

  /// Helper to create a new JinjaString where all parts are marked as input.
  JinjaString markInput() {
    return JinjaString(
      parts.map((p) => JinjaStringPart(p.val, true)).toList(growable: false),
      isSafe: isSafe,
    );
  }

  /// Helper to create a new JinjaString marked as safe.
  JinjaString markSafe() {
    return JinjaString(parts, isSafe: true);
  }

  /// Mark this string as input if [other] has ALL parts as input.
  /// This is used for operations like `split` where the resulting parts should
  /// inherit the "taint" of the original string if the original was fully tainted.
  JinjaString markInputBasedOn(JinjaString other) {
    if (other.allPartsAreInput) {
      return markInput();
    }
    return this;
  }

  /// Concatenates this string with another.
  JinjaString operator +(JinjaString other) {
    final newParts = List<JinjaStringPart>.from(parts)..addAll(other.parts);
    return JinjaString(
      _mergeAdjacentParts(newParts),
      isSafe: isSafe && other.isSafe,
    );
  }

  /// Optimizes the parts list by merging adjacent parts with the same [isInput] flag.
  static List<JinjaStringPart> _mergeAdjacentParts(
    List<JinjaStringPart> parts,
  ) {
    if (parts.isEmpty) return parts;

    final merged = <JinjaStringPart>[];
    var current = parts.first;

    for (var i = 1; i < parts.length; i++) {
      final next = parts[i];
      if (current.isInput == next.isInput) {
        current = JinjaStringPart(current.val + next.val, current.isInput);
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  // transformation methods

  JinjaString toUpperCase() {
    return JinjaString(
      parts
          .map((p) => JinjaStringPart(p.val.toUpperCase(), p.isInput))
          .toList(),
      isSafe: isSafe,
    );
  }

  JinjaString toLowerCase() {
    return JinjaString(
      parts
          .map((p) => JinjaStringPart(p.val.toLowerCase(), p.isInput))
          .toList(),
      isSafe: isSafe,
    );
  }

  JinjaString substring(int start, [int? end]) {
    final fullStr = toString();
    final len = fullStr.length;
    if (end == null || end > len) end = len;
    if (start >= end) return const JinjaString([]);

    final newParts = <JinjaStringPart>[];
    int currentPos = 0;

    for (final part in parts) {
      final partStart = currentPos;
      final partEnd = currentPos + part.val.length;

      // Check overlap
      if (partEnd > start && partStart < end) {
        // Calculate interaction
        final sliceStart = start > partStart ? start - partStart : 0;
        final sliceEnd = end < partEnd ? end - partStart : part.val.length;

        newParts.add(
          JinjaStringPart(
            part.val.substring(sliceStart, sliceEnd),
            part.isInput,
          ),
        );
      }
      currentPos += part.val.length;
    }
    return JinjaString(newParts, isSafe: isSafe);
  }

  JinjaString trim() {
    final s = toString();
    final trimmed = s.trim();
    if (trimmed.isEmpty) return const JinjaString([]);
    final start = s.indexOf(trimmed);
    return substring(start, start + trimmed.length);
  }

  JinjaString trimLeft() {
    final s = toString();
    final trimmed = s.trimLeft();
    if (trimmed.isEmpty) return const JinjaString([]);
    final start = s.length - trimmed.length;
    return substring(start);
  }

  JinjaString trimRight() {
    final s = toString();
    final trimmed = s.trimRight();
    if (trimmed.isEmpty) return const JinjaString([]);
    return substring(0, trimmed.length);
  }

  JinjaString operator [](int index) {
    return substring(index, index + 1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JinjaString &&
          isSafe == other.isSafe &&
          parts.length == other.parts.length &&
          _partsListEqual(parts, other.parts);

  static bool _partsListEqual(
    List<JinjaStringPart> a,
    List<JinjaStringPart> b,
  ) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int h = isSafe.hashCode;
    for (final p in parts) {
      h ^= p.hashCode;
    }
    return h;
  }

  /// Returns a new JinjaString with special characters escaped.
  JinjaString escape() {
    if (isSafe) return this;
    final escapedParts = parts.map((p) {
      if (!p.isInput) return p;
      final escapedVal = p.val
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');
      return JinjaStringPart(escapedVal, p.isInput);
    }).toList();
    return JinjaString(escapedParts, isSafe: true);
  }
}
