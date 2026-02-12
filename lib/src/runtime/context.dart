import '../types/value.dart';
import 'builtins.dart';

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
        'env': JinjaMap({
          val('trim_blocks'): const JinjaBoolean(false),
          val('lstrip_blocks'): const JinjaBoolean(false),
        }, name: 'env'),
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
      var v = environment[name]!;
      if (name == 'env' && v is JinjaMap) {
        // Special case for 'env': llama.cpp tests expect it to NOT have object methods
        // like .get(), .items(), etc. as attributes.
        // Since our JinjaMap resolution favors methods, we need to return a wrapper
        // or just the raw map items?
        // Actually, if we return it as a JinjaValue that is NOT a JinjaMap but behaves like one...
        // For now, let's just use the fact that it's 'env' to skip method resolution in MemberExpression?
        // Or here, we can return a version of it that hides its methods.
        // For now, we return a JinjaMap, but the MemberExpression resolver will need to handle 'env' specially.
        // If we need to hide methods, we'd return a custom JinjaValue that wraps the map but doesn't expose methods.
        // For now, returning the JinjaMap directly, assuming the caller (MemberExpression) will handle the 'env' special case.
      }
      return v;
    }
    // Only check globalFunctions or globalTests if we want them as variables?
    // In Jinja, globals include functions. Filters are NOT identifiers.
    if (globalFunctions.containsKey(name)) {
      return JinjaFunction(name, globalFunctions[name]!);
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
