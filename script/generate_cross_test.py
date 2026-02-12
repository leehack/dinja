
import re
import json
import os
import subprocess

# Path to the C++ test file
CPP_TEST_FILE = '../llama.cpp/tests/test-jinja.cpp'
# Output Dart test file
DART_TEST_FILE = 'test/llama_cross_test.dart'

def parse_cpp_test_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Regex to capture test_template calls
    # test_template(t, "name", "template", data, "expected");
    # We need to be careful with nested braces and escaped quotes.
    # This simplistic regex might fail on complex nested structures, but let's try.
    # Since C++ code can be messy, maybe we can assume specific formatting or use a state machine.
    
    tests = []
    
    # Let's iterate line by line to find test_template calls
    lines = content.split('\n')
    current_test = {}
    buffer = ""
    capturing = False
    
    for line in lines:
        if 'test_template(t,' in line:
            capturing = True
            buffer = line
        elif capturing:
            buffer += line
        
        if capturing and ');' in line:
            capturing = False
            # Now parse the buffer
            # Expected format: test_template(t, "name", "tmpl", json, "expect");
            # We can try to split by arguments, but commas in strings/json make it hard.
            # Let's use a simple state machine to parse arguments.
            args = parse_cpp_args(buffer)
            if len(args) >= 5:
                # args[0] is 't'
                name = args[1]
                tmpl = args[2]
                data = args[3]
                expect = args[4]
                
                # Cleanup quotes
                if name.startswith('"') and name.endswith('"'): name = name[1:-1]
                if tmpl.startswith('"') and tmpl.endswith('"'): tmpl = tmpl[1:-1]
                if expect.startswith('"') and expect.endswith('"'): expect = expect[1:-1]
                
                # Handle C++ string concatenation
                tmpl = tmpl.replace('" "', '').replace('"\n"', '').replace('" \n"', '')
                expect = expect.replace('" "', '').replace('"\n"', '').replace('" \n"', '')
                
                tests.append({
                    'name': name,
                    'template': tmpl,
                    'data': data,
                    'expected': expect
                })
    
    return tests

def parse_cpp_args(buffer):
    # Remove 'test_template(' prefix and ');' suffix
    content = buffer.strip()
    if content.startswith('test_template('):
        content = content[len('test_template('):]
    if content.endswith(');'):
        content = content[:-2]
        
    args = []
    current_arg = ""
    in_quote = False
    quote_char = ''
    brace_depth = 0
    in_escape = False
    
    for char in content:
        if in_escape:
            current_arg += char
            in_escape = False
            continue
            
        if char == '\\':
            current_arg += char
            in_escape = True
            continue
            
        if not in_quote and (char == '"' or char == "'"):
            in_quote = True
            quote_char = char
            current_arg += char
        elif in_quote and char == quote_char:
            in_quote = False
            current_arg += char
        elif not in_quote and (char == '{' or char == '(' or char == '['):
            brace_depth += 1
            current_arg += char
        elif not in_quote and (char == '}' or char == ')' or char == ']'):
            brace_depth -= 1
            current_arg += char
        elif not in_quote and brace_depth == 0 and char == ',':
            args.append(current_arg.strip())
            current_arg = ""
        else:
            current_arg += char
            
    if current_arg:
        args.append(current_arg.strip())
        
    return args


def convert_cpp_json_to_dart(data_str):
    data_str = data_str.strip()
    if not data_str:
        return '{}'
    if data_str == 'json::object()' or data_str == '{}':
        return '{}'
    if data_str == 'json::array()' or data_str == '[]':
        return '[]'
        
    # Helper to consume characters
    idx = 0
    length = len(data_str)
    
    def peek():
        if idx < length:
            return data_str[idx]
        return None
        
    def consume():
        nonlocal idx
        char = data_str[idx]
        idx += 1
        return char
        
    def match(s):
        nonlocal idx
        if data_str.startswith(s, idx):
            # Check if it's a word and if it's followed by another word char
            if s[0].isalpha():
                end_idx = idx + len(s)
                if end_idx < length and (data_str[end_idx].isalnum() or data_str[end_idx] == '_'):
                    return False
            idx += len(s)
            return True
        return False
        
    def parse_value():
        nonlocal idx
        # Skip whitespace
        while idx < length and data_str[idx].isspace():
            idx += 1
            
        if idx >= length:
            return None
            
        char = data_str[idx]
        
        # Handle C++ json constructors
        if match('json::array'):
            # json::array({ ... }) or json::array()
            if match('('):
                # Check for empty array literal inside
                if match('{'):
                    # parse list elements until }
                    elements = []
                    while idx < length:
                        while idx < length and data_str[idx].isspace(): idx += 1
                        if peek() == '}':
                            consume() # }
                            break
                        elements.append(parse_value())
                        while idx < length and data_str[idx].isspace(): idx += 1
                        if peek() == ',':
                            consume()
                    
                    # Consume closing )
                    while idx < length and data_str[idx].isspace(): idx += 1
                    if peek() == ')': consume()
                    return '[' + ', '.join(elements) + ']'
                elif match(')'):
                    return '[]'
                else: 
                     # json::array(...) -> probably just parens
                     pass 

        if match('json::object'):
             if match('('):
                 if match(')'): return '{}'

        # Handle explicit json(...) wrapper
        if match('json('):
             val = parse_value()
             while idx < length and data_str[idx].isspace(): idx += 1
             if peek() == ')': consume()
             return val

        # Handle strings
        if char == '"' or char == "'":
            quote = consume()
            val = quote
            while idx < length:
                c = consume()
                val += c
                if c == '\\':
                    if idx < length: val += consume()
                elif c == quote:
                    break
            return val
            
        # Handle initializer list for object { "k", v } (which is inside another brace usually)
        # BUT at top level or nested:
        # {{"key", val}} -> object
        # {{"k1", v1}, {"k2", v2}} -> object
        
        if char == '{':
            consume() # {
            elements = []
            while idx < length:
                while idx < length and data_str[idx].isspace(): idx += 1
                if peek() == '}':
                    consume()
                    break
                v = parse_value()
                if v: elements.append(v)
                while idx < length and data_str[idx].isspace(): idx += 1
                if peek() == ',': consume()
            
            is_object = len(elements) > 0
            for el in elements:
                el = el.strip()
                if not (el.startswith('[') and el.endswith(']')):
                    is_object = False
                    break
                inner = el[1:-1].strip()
                brace_level = 0
                comma_idx = -1
                for i, c in enumerate(inner):
                    if c in ('{', '['): brace_level += 1
                    elif c in ('}', ']'): brace_level -= 1
                    elif c == ',' and brace_level == 0:
                        comma_idx = i
                        break
                if comma_idx == -1:
                    is_object = False
                    break
                first_part = inner[:comma_idx].strip()
                if not (first_part.startswith('"') or first_part.startswith("'")):
                    is_object = False
                    break
            
            if is_object:
                entries = []
                for el in elements:
                    inner = el.strip()[1:-1]
                    brace_level = 0
                    comma_idx = -1
                    for i, c in enumerate(inner):
                        if c in ('{', '['): brace_level += 1
                        elif c in ('}', ']'): brace_level -= 1
                        elif c == ',' and brace_level == 0:
                            comma_idx = i
                            break
                    k = inner[:comma_idx].strip()
                    v = inner[comma_idx+1:].strip()
                    entries.append(f'{k}: {v}')
                return '{' + ', '.join(entries) + '}'
            else:
                return '[' + ', '.join(elements) + ']'

        # Primitives
        if match('nullptr'): return 'null'
        if match('true'): return 'true'
        if match('false'): return 'false'
        if match('null'): return 'null'
        
        if char.isdigit() or char == '-':
            start = idx
            consume() # digit or minus
            while idx < length and (data_str[idx].isdigit() or data_str[idx] == '.'):
                consume()
            return data_str[start:idx]
        
        # Fallback for other things (unquoted identifiers?)
        start = idx
        while idx < length and not data_str[idx].isspace() and data_str[idx] not in '{},:()[]':
            consume()
        return data_str[start:idx]

    res = parse_value()
    return res

def generate_dart_test(tests):
    dart_code = """
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Llama.cpp Cross Tests', () {
"""
    
    for i, test in enumerate(tests):
        name = test['name'].replace("'", "\\'")
        tmpl = test['template'].replace("'", "\\'").replace('\n', '\\n')
        
        # Normalize tojson expectations (Dinja produces compact JSON)
        raw_expect = test['expected']
        if 'tojson' in name:
             # Try to unescape C++ string to get real JSON
             # C++ string might have \" for quotes.
             candidate = raw_expect.replace('\\"', '"').replace('\\\\', '\\')
             if candidate.strip().startswith('{') or candidate.strip().startswith('['):
                 try:
                     import json
                     obj = json.loads(candidate)
                     raw_expect = json.dumps(obj, separators=(',', ':'))
                 except:
                     pass

        expect = raw_expect.replace("'", "\\'").replace('\n', '\\n')
        data = test['data']
        
        try:
            dart_data = convert_cpp_json_to_dart(data)
        except Exception as e:
            print(f"Failed to convert data for test '{test['name']}': {data}")
            print(f"Exception: {e}")
            # Fallback to empty dict to allow generation to continue
            dart_data = '{}'
        
        dart_code += f"""
    test('{name}', () {{
      final template = Template('{tmpl}');
      final Map<String, dynamic> data = {dart_data};
      expect(template.render(data), equals('{expect}'));
    }});
"""

    dart_code += """
  });
}
"""
    return dart_code


def main():
    if not os.path.exists(CPP_TEST_FILE):
        print(f"Error: {CPP_TEST_FILE} not found.")
        return

    tests = parse_cpp_test_file(CPP_TEST_FILE)
    print(f"Found {len(tests)} tests.")
    
    dart_content = generate_dart_test(tests)
    
    with open(DART_TEST_FILE, 'w') as f:
        f.write(dart_content)
    print(f"Generated {DART_TEST_FILE}")
    
    # Auto-fix lint issues (e.g. unnecessary escapes) and format
    try:
        print("Running dart fix...")
        subprocess.run(['dart', 'fix', '--apply', DART_TEST_FILE], check=True)
        print("Running dart format...")
        subprocess.run(['dart', 'format', DART_TEST_FILE], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running dart tools: {e}")

if __name__ == '__main__':
    main()
