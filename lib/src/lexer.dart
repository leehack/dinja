import 'package:meta/meta.dart';

/// The various types of tokens that the [Lexer] can produce.
enum TokenType {
  /// End of source.
  eof,

  /// The text between Jinja statements or expressions.
  text,

  /// A numeric literal (e.g., 123, 1.0).
  numericLiteral,

  /// A string literal (e.g., 'string').
  stringLiteral,

  /// An identifier (variables, functions, statements, booleans, etc.).
  identifier,

  /// The equals operator (=).
  equals,

  /// Opening parenthesis (().
  openParen,

  /// Closing parenthesis ()).
  closeParen,

  /// Opening statement tag ({%).
  openStatement,

  /// Closing statement tag (%}).
  closeStatement,

  /// Opening expression tag ({{).
  openExpression,

  /// Closing expression tag (}}).
  closeExpression,

  /// Opening square bracket ([).
  openSquareBracket,

  /// Closing square bracket (]).
  closeSquareBracket,

  /// Opening curly bracket ({).
  openCurlyBracket,

  /// Closing curly bracket (}).
  closeCurlyBracket,

  /// Comma (,).
  comma,

  /// Dot (.).
  dot,

  /// Colon (:).
  colon,

  /// Pipe (|).
  pipe,

  /// Call operator ().
  callOperator,

  /// Additive binary operators (+, -, ~).
  additiveBinaryOperator,

  /// Multiplicative binary operators (*, /, %).
  multiplicativeBinaryOperator,

  /// Power operator (**).
  power,

  /// Floor division operator (//).
  floorDivision,

  /// Comparison binary operators (<, >, <=, >=, ==, !=).
  comparisonBinaryOperator,

  /// Unary operators (!, -, +).
  unaryOperator,

  /// Comment tag ({# ... #}).
  comment,
}

/// Represents a single token produced by the [Lexer].
@immutable
class Token {
  /// The type of the token.
  final TokenType type;

  /// The literal value of the token as it appeared in the source.
  final String value;

  /// The starting position of the token in the source text.
  final int pos;

  /// The line number where the token starts (1-indexed).
  final int line;

  /// The column number where the token starts (1-indexed).
  final int col;

  const Token(this.type, this.value, this.pos, this.line, this.col);

  @override
  String toString() => 'Token($type, "$value", @$line:$col)';
}

/// Exception thrown when a lexical error is encountered.
class LexerException implements Exception {
  /// The error message.
  final String message;

  /// The source text being lexed.
  final String source;

  /// The position in the source where the error occurred.
  final int pos;

  /// The line number where the error occurred (1-indexed).
  final int? line;

  /// The column number where the error occurred (1-indexed).
  final int? col;

  LexerException(this.message, this.source, this.pos, [this.line, this.col]);

  @override
  String toString() {
    if (line != null && col != null) {
      return 'LexerException: $message at $line:$col';
    }
    return 'LexerException: $message at pos $pos';
  }
}

/// The result of a lexing operation, containing the list of tokens and the source.
class LexerResult {
  /// The list of tokens produced by the [Lexer].
  final List<Token> tokens;

  /// The original source text.
  final String source;

  LexerResult(this.tokens, this.source);
}

/// The lexer responsible for breaking the Jinja source into a stream of [Token]s.
class Lexer {
  /// The source text to be lexed.
  final String source;

  Lexer(this.source);
  static const Map<String, String> escapeChars = {
    'n': '\n',
    't': '\t',
    'r': '\r',
    'b': '\b',
    'f': '\f',
    'v': '\v',
    '\\': '\\',
    '\'': '\'',
    '"': '"',
  };

  static bool isWord(int charCode) {
    // 0-9, A-Z, a-z, _
    return (charCode >= 48 && charCode <= 57) ||
        (charCode >= 65 && charCode <= 90) ||
        (charCode >= 97 && charCode <= 122) ||
        charCode == 95; // _
  }

  static bool isDigit(int charCode) {
    return charCode >= 48 && charCode <= 57;
  }

  static bool isSpace(int charCode) {
    // space, tab, newline, cr, vt, ff
    return charCode == 32 ||
        charCode == 9 ||
        charCode == 10 ||
        charCode == 13 ||
        charCode == 11 ||
        charCode == 12;
  }

  static const List<MapEntry<String, TokenType>> orderedMappingTable = [
    // Trimmed control sequences
    MapEntry('{%-', TokenType.openStatement),
    MapEntry('-%}', TokenType.closeStatement),
    MapEntry('{{-', TokenType.openExpression),
    MapEntry('-}}', TokenType.closeExpression),
    // Control sequences
    MapEntry('{%', TokenType.openStatement),
    MapEntry('%}', TokenType.closeStatement),
    MapEntry('{{', TokenType.openExpression),
    MapEntry('}}', TokenType.closeExpression),
    // Single character tokens
    MapEntry('(', TokenType.openParen),
    MapEntry(')', TokenType.closeParen),
    MapEntry('{', TokenType.openCurlyBracket),
    MapEntry('}', TokenType.closeCurlyBracket),
    MapEntry('[', TokenType.openSquareBracket),
    MapEntry(']', TokenType.closeSquareBracket),
    MapEntry(',', TokenType.comma),
    MapEntry('.', TokenType.dot),
    MapEntry(':', TokenType.colon),
    MapEntry('|', TokenType.pipe),
    // Comparison operators
    MapEntry('<=', TokenType.comparisonBinaryOperator),
    MapEntry('>=', TokenType.comparisonBinaryOperator),
    MapEntry('==', TokenType.comparisonBinaryOperator),
    MapEntry('!=', TokenType.comparisonBinaryOperator),
    MapEntry('<', TokenType.comparisonBinaryOperator),
    MapEntry('>', TokenType.comparisonBinaryOperator),
    // Arithmetic operators
    MapEntry('+', TokenType.additiveBinaryOperator),
    MapEntry('-', TokenType.additiveBinaryOperator),
    MapEntry('~', TokenType.additiveBinaryOperator),
    MapEntry('**', TokenType.power),
    MapEntry('//', TokenType.floorDivision),
    MapEntry('*', TokenType.multiplicativeBinaryOperator),
    MapEntry('/', TokenType.multiplicativeBinaryOperator),
    MapEntry('%', TokenType.multiplicativeBinaryOperator),
    // Assignment operator
    MapEntry('=', TokenType.equals),
  ];

  /// Tokenizes the [source] and returns a [LexerResult].
  LexerResult tokenize() {
    final tokens = <Token>[];
    String src = source;

    if (src.isEmpty) {
      return LexerResult(tokens, src);
    }

    // Normalize newlines
    src = src.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Strip trailing newline if present (default config)
    if (src.endsWith('\n')) {
      src = src.substring(0, src.length - 1);
    }

    int pos = 0;
    int line = 1;
    int col = 1;
    int curlyBracketDepth = 0;

    void updateLineCol(int start, int end) {
      for (int i = start; i < end; i++) {
        if (src[i] == '\n') {
          line++;
          col = 1;
        } else {
          col++;
        }
      }
    }

    // Helper to consume chars based on predicate

    // Simpler consumeWhile for identifiers/numbers that don't allow escapes
    String consumeSimple(bool Function(int) predicate) {
      final start = pos;
      while (pos < src.length && predicate(src.codeUnitAt(pos))) {
        pos++;
      }
      final result = src.substring(start, pos);
      updateLineCol(start, pos);
      return result;
    }

    String consumeNumeric() {
      final start = pos;
      consumeSimple(isDigit);
      if (pos < src.length &&
          src[pos] == '.' &&
          pos + 1 < src.length &&
          isDigit(src.codeUnitAt(pos + 1))) {
        final dotStart = pos;
        pos++; // Consume '.'
        updateLineCol(dotStart, pos);
        consumeSimple(isDigit);
      }
      return src.substring(start, pos);
    }

    bool nextPosIs(List<String> chars, {int offset = 1}) {
      if (pos + offset >= src.length) return false;
      final charAtOffset = src[pos + offset];
      return chars.contains(charAtOffset);
    }

    // Default config
    final bool optLstripBlocks = true;
    final bool optTrimBlocks = true;
    bool isLstripBlock = false;
    bool isRstripBlock = false;

    while (pos < src.length) {
      int startPos = pos;

      TokenType lastTokenType = tokens.isEmpty
          ? TokenType.closeStatement
          : tokens.last.type;

      // 1. Text (outside of tags)
      if (lastTokenType == TokenType.closeStatement ||
          lastTokenType == TokenType.closeExpression ||
          lastTokenType == TokenType.comment) {
        // Treat end of comment as end of tag

        // logic for rstrip (stripping previous text trailing whitespace)
        // based on CURRENT block start
        // Wait, C++ logic:
        // is_rstrip_block determined by checking *src[pos-3..pos]* which is the END of the LAST block
        // IF we just finished a block, we check if it was a stripping block.

        bool lastBlockCanRmNewline = false;
        isRstripBlock = false;

        // Check if the PREVIOUS block ended with -%} or -}} or -#}
        // We know we just finished a block if lastTokenType is close* or comment.
        // But we don't look at tokens, we look at raw source char history?
        // C++: if (pos > 3) { ... src[pos-3] ... }
        // This relies on 'pos' being immediately after the closing tag.

        if (pos >= 3) {
          final c0 = src[pos - 3];
          final c1 = src[pos - 2];
          final c2 = src[pos - 1]; // This should be '}'

          isRstripBlock =
              c0 == '-' && (c1 == '%' || c1 == '}' || c1 == '#') && c2 == '}';
          lastBlockCanRmNewline =
              (c1 == '#' || c1 == '%' || c1 == '-') && c2 == '}';
        }

        int start = pos;
        int end = start;

        // Consume text until next tag start '{\%' or '{{' or '{#'
        while (pos < src.length) {
          if (src[pos] == '{' && (nextPosIs(['%', '{', '#']))) {
            break;
          }
          final oldPos = pos;
          pos++;
          updateLineCol(oldPos, pos);
          end = pos;
        }

        // lstrip_blocks: "Remove leading whitespace" from THIS text block
        // IF the NEXT block is a stripping block (starts with {%- or {{- or {#-)
        // C++: if (next block starts with -) -> lstrip current text TAIL.
        // wait, lstrip_blocks option usually means "strip leading whitespace of line for valid block" logic

        // C++ logic copy:
        if (optLstripBlocks &&
            pos < src.length &&
            src[pos] == '{' &&
            nextPosIs(['%', '#', '-'])) {
          // This logic in C++ seems to go BACKWARDS from 'end' to 'start' to find newline
          // and strip whitespace between newline and tag?
          int current = end;
          while (current > start) {
            final c = src.codeUnitAt(current - 1);
            if (current == 1) {
              // reached start of string
              end = 0;
              break;
            }
            if (c == 10) {
              // newline
              end = current; // stop at newline (keep newline?)
              break;
            }
            if (!isSpace(c)) {
              break; // non-space, stop
            }
            current--;
          }
        }

        String text = src.substring(start, end);

        // trim_blocks: "Remove first newline after a block"
        if (optTrimBlocks && lastBlockCanRmNewline) {
          if (text.isNotEmpty && text.startsWith('\n')) {
            text = text.substring(1);
          }
        }

        // is_rstrip_block (from LAST block): remove leading whitespace of THIS text
        if (isRstripBlock) {
          // lstrip(text)
          text = text
              .trimLeft(); // simplistic? C++ does string_lstrip with " \t\r\n"
        }

        // is_lstrip_block (from NEXT block): remove trailing whitespace of THIS text
        isLstripBlock =
            pos < src.length &&
            src[pos] == '{' &&
            nextPosIs(['{', '%', '#']) &&
            nextPosIs(['-'], offset: 2);

        if (isLstripBlock) {
          // rstrip(text)
          text = text.trimRight();
        }

        if (text.isNotEmpty) {
          tokens.add(Token(TokenType.text, text, startPos, line, col));
          continue;
        }
      } // end text parsing

      // 2. Comments '{# ... #}'
      if (pos < src.length && src[pos] == '{' && nextPosIs(['#'])) {
        final tokenLine = line;
        final tokenCol = col;
        startPos = pos;
        final oldStartPos = pos;
        pos += 2; // skip '{#'
        updateLineCol(oldStartPos, pos);

        // find end '#}'
        final endCommentIdx = src.indexOf('#}', pos);
        if (endCommentIdx == -1) {
          throw LexerException(
            'missing end of comment tag',
            src,
            pos,
            line,
            col,
          );
        }

        final comment = src.substring(pos, endCommentIdx);
        final oldPos = pos;
        pos = endCommentIdx + 2;
        updateLineCol(oldPos, pos);
        tokens.add(
          Token(TokenType.comment, comment, startPos, tokenLine, tokenCol),
        );

        continue;
      }

      // 3. Strip block start '{%-' or '{{-'
      // The '-' is a distinct character but we handle it here to skip?
      // C++: if src[pos] == '-' && (last == openStatement/Expression) -> consume '-'
      if (pos < src.length &&
          src[pos] == '-' &&
          (lastTokenType == TokenType.openExpression ||
              lastTokenType == TokenType.openStatement)) {
        final oldPos = pos;
        pos++;
        updateLineCol(oldPos, pos);
        if (pos >= src.length) break;
      }

      // 4. Whitespace inside tags
      while (pos < src.length && isSpace(src.codeUnitAt(pos))) {
        final oldPos = pos;
        pos++;
        updateLineCol(oldPos, pos);
      }
      if (pos >= src.length) break;

      final char = src[pos];
      final charCode = src.codeUnitAt(pos);

      bool isClosingBlock = char == '-' && nextPosIs(['%', '}']);

      // 5. Unary Operators (if not closing block)
      if (!isClosingBlock && (char == '-' || char == '+')) {
        // Check if binary or unary
        // Binary if previous token was identifier, literal, close paren/bracket
        bool isBinary = false;
        switch (lastTokenType) {
          case TokenType.identifier:
          case TokenType.numericLiteral:
          case TokenType.stringLiteral:
          case TokenType.closeParen:
          case TokenType.closeSquareBracket:
            isBinary = true;
            break;
          default:
            isBinary = false;
        }

        if (!isBinary) {
          startPos = pos;
          final tokenLine = line;
          final tokenCol = col;
          final oldPos = pos;
          pos++; // consume op
          updateLineCol(oldPos, pos);

          // check for number
          String num = consumeNumeric();
          if (num.isNotEmpty) {
            // Return as signed number literal
            tokens.add(
              Token(
                TokenType.numericLiteral,
                char + num,
                startPos,
                tokenLine,
                tokenCol,
              ),
            );
          } else {
            tokens.add(
              Token(
                TokenType.unaryOperator,
                char,
                startPos,
                tokenLine,
                tokenCol,
              ),
            );
          }
          continue;
        }
      }

      // 6. Mapping Table (Operators & Tags)
      bool matched = false;
      for (final entry in orderedMappingTable) {
        final seq = entry.key;
        final type = entry.value;

        startPos = pos;

        // Special case: don't treat '}}' as close expression if inside obj/array?
        // C++: if seq == "}}" && curlyBracketDepth > 0 -> continue
        if (seq == '}}' && curlyBracketDepth > 0) {
          continue;
        }

        if (pos + seq.length <= src.length &&
            src.substring(pos, pos + seq.length) == seq) {
          final oldPos = pos;
          pos += seq.length;
          final tokenLine = line;
          final tokenCol = col;
          updateLineCol(oldPos, pos);

          tokens.add(Token(type, seq, startPos, tokenLine, tokenCol));

          if (type == TokenType.openExpression) {
            curlyBracketDepth = 0;
          } else if (type == TokenType.openCurlyBracket) {
            curlyBracketDepth++;
          } else if (type == TokenType.closeCurlyBracket) {
            curlyBracketDepth--;
          }

          matched = true;
          break;
        }
      }
      if (matched) continue;

      // 7. Strings
      if (char == "'" || char == '"') {
        startPos = pos;
        final tokenLine = line;
        final tokenCol = col;

        final oldPos = pos;
        pos++; // skip quote
        updateLineCol(oldPos, pos);

        final buffer = StringBuffer();
        bool closed = false;
        while (pos < src.length) {
          if (src[pos] == char) {
            closed = true;
            break;
          }
          // Escape handling
          if (src[pos] == '\\') {
            final escStart = pos;
            pos++;
            if (pos >= src.length) {
              updateLineCol(escStart, pos);
              throw LexerException(
                'Unterminated string',
                src,
                pos,
                tokenLine,
                tokenCol,
              );
            }
            final esc = src[pos++];
            updateLineCol(escStart, pos);

            if (escapeChars.containsKey(esc)) {
              buffer.write(escapeChars[esc]);
            } else {
              throw LexerException(
                'Unknown escape \\$esc',
                src,
                pos,
                line,
                col,
              );
            }
            continue;
          }
          final charStart = pos;
          buffer.write(src[pos++]);
          updateLineCol(charStart, pos);
        }

        if (!closed) {
          throw LexerException(
            'Unterminated string',
            src,
            pos,
            tokenLine,
            tokenCol,
          );
        }

        tokens.add(
          Token(
            TokenType.stringLiteral,
            buffer.toString(),
            startPos,
            tokenLine,
            tokenCol,
          ),
        );

        final quoteEnd = pos;
        pos++; // skip closing quote
        updateLineCol(quoteEnd, pos);
        continue;
      }

      // 8. Numbers
      if (isDigit(charCode)) {
        startPos = pos;
        final tokenLine = line;
        final tokenCol = col;
        final num = consumeNumeric();
        tokens.add(
          Token(TokenType.numericLiteral, num, startPos, tokenLine, tokenCol),
        );
        continue;
      }

      // 9. Identifiers
      if (isWord(charCode)) {
        startPos = pos;
        final tokenLine = line;
        final tokenCol = col;
        final word = consumeSimple(isWord);
        tokens.add(
          Token(TokenType.identifier, word, startPos, tokenLine, tokenCol),
        );
        continue;
      }

      throw LexerException('Unexpected character $char', src, pos, line, col);
    }

    return LexerResult(tokens, src);
  }
}
