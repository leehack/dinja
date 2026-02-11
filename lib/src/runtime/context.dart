import '../types/value.dart';

/// Manages the execution context and variable scopes.
class Context {
  // We use a stack of maps for scoping (global, function, loop, block)
  // or just a single map if we follow llama.cpp's simple implementation which
  // seems to copy the parent context on scope creation?
  // checking llama.cpp: context(const context & parent) : context() { inherit... }
  // So it creates a new context that copies variables.

  final Map<String, JinjaValue> environment;
  final Context? parent;

  Context({this.parent})
    : environment = <String, JinjaValue>{
        // Default built-ins (true, false, none)
        // In llama.cpp these are added in constructor
        'true': const JinjaBoolean(true),
        'True': const JinjaBoolean(true),
        'false': const JinjaBoolean(false),
        'False': const JinjaBoolean(false),
        'none': const JinjaNone(),
        'None': const JinjaNone(),
      } {
    if (parent != null) {
      // Inherit variables from parent
      // Note: shallow copy of references is fine as JinjaValues are immutable-ish
      environment.addAll(parent!.environment);
    }
  }

  /// Look up a variable by name. Returns [JinjaUndefined] if not found.
  JinjaValue get(String name) {
    if (environment.containsKey(name)) {
      return environment[name]!;
    }
    return JinjaUndefined(name);
  }

  // Alias for get
  JinjaValue resolve(String name) => get(name);

  /// Set a variable in the current scope.
  void set(String name, JinjaValue value) {
    environment[name] = value;
  }

  /// Create a child context (new scope).
  Context derive() {
    return Context(parent: this);
  }
}
