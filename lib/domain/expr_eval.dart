/// A tiny, safe calculator for the arithmetic check on problem cards (D43). Pure Dart.
///
/// Understands numbers (1, 2.5, 1.2e3), + - * / ^ (power, right-associative), parentheses, unary minus,
/// the constants pi and e, and sqrt, abs, sin, cos, tan, asin, acos, atan, ln, log (base 10), exp.
/// Nothing else: no variables, no assignment, no calls out. Anything it does not understand gives
/// null (the check is then skipped), never an exception.
library;

import 'dart:math' as math;

const kMaxExprChars = 200;
const _maxDepth = 40;

double? evalExpression(String source) {
  final s = source.trim();
  if (s.isEmpty || s.length > kMaxExprChars) return null;
  try {
    final p = _Parser(s);
    final v = p.parseExpr(0);
    p.skipSpace();
    if (!p.atEnd) return null;
    return v.isFinite ? v : null;
  } catch (_) {
    return null;
  }
}

/// Is [claimed] (rounded by a person or an AI) the same number as [exact]? Within 3% or a hair.
bool numbersAgree(double claimed, double exact) {
  final diff = (claimed - exact).abs();
  return diff <= 1e-9 || diff <= 0.03 * math.max(claimed.abs(), exact.abs());
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  bool get atEnd => i >= s.length;
  void skipSpace() {
    while (i < s.length && (s[i] == ' ' || s[i] == '\t')) {
      i++;
    }
  }

  double parseExpr(int depth) {
    if (depth > _maxDepth) throw const FormatException('too deep');
    var v = parseTerm(depth);
    while (true) {
      skipSpace();
      if (atEnd) return v;
      final c = s[i];
      if (c == '+') {
        i++;
        v += parseTerm(depth);
      } else if (c == '-') {
        i++;
        v -= parseTerm(depth);
      } else {
        return v;
      }
    }
  }

  double parseTerm(int depth) {
    var v = parseUnary(depth);
    while (true) {
      skipSpace();
      if (atEnd) return v;
      final c = s[i];
      if (c == '*') {
        i++;
        v *= parseUnary(depth);
      } else if (c == '/') {
        i++;
        v /= parseUnary(depth);
      } else {
        return v;
      }
    }
  }

  // Unary minus binds looser than ^, so -2^2 = -4.
  double parseUnary(int depth) {
    skipSpace();
    if (!atEnd && s[i] == '-') {
      i++;
      return -parseUnary(depth + 1);
    }
    if (!atEnd && s[i] == '+') {
      i++;
      return parseUnary(depth + 1);
    }
    return parsePower(depth);
  }

  double parsePower(int depth) {
    final base = parseAtom(depth);
    skipSpace();
    if (!atEnd && s[i] == '^') {
      i++;
      final exp = parseUnary(depth + 1); // right-associative
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  double parseAtom(int depth) {
    skipSpace();
    if (atEnd) throw const FormatException('end');
    if (s[i] == '(') {
      i++;
      final v = parseExpr(depth + 1);
      skipSpace();
      if (atEnd || s[i] != ')') throw const FormatException('paren');
      i++;
      return v;
    }
    final num = RegExp(r'\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?').matchAsPrefix(s, i);
    if (num != null) {
      i = num.end;
      return double.parse(num[0]!);
    }
    final id = RegExp(r'[a-zA-Z]+').matchAsPrefix(s, i);
    if (id == null) throw const FormatException('unexpected');
    final name = id[0]!.toLowerCase();
    i = id.end;
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;
    skipSpace();
    if (atEnd || s[i] != '(') throw const FormatException('function needs (');
    i++;
    final arg = parseExpr(depth + 1);
    skipSpace();
    if (atEnd || s[i] != ')') throw const FormatException('paren');
    i++;
    return switch (name) {
      'sqrt' => math.sqrt(arg),
      'abs' => arg.abs(),
      'sin' => math.sin(arg),
      'cos' => math.cos(arg),
      'tan' => math.tan(arg),
      'asin' => math.asin(arg),
      'acos' => math.acos(arg),
      'atan' => math.atan(arg),
      'ln' => math.log(arg),
      'log' => math.log(arg) / math.ln10,
      'exp' => math.exp(arg),
      _ => throw const FormatException('unknown function'),
    };
  }
}
