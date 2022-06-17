import 'dart:collection';

import 'ascii.dart';

const int tokenText = 1;
const int tokenIdent = 3;

class Token {
  final int type;
  final String value;
  final String? typeName;
  Token(this.type, this.value, [this.typeName]);
  @override
  String toString() =>
      '${['?', 'Text', 'At', 'Ident'][type]} "$value" "$typeName"';
}

typedef _ValueEncoder = String Function(String identifier, String? type);
typedef EncodeValue = String Function(dynamic value, String? type);

bool isIdentifier(int charCode) =>
    (charCode >= $a && charCode <= $z) ||
    (charCode >= $A && charCode <= $Z) ||
    (charCode >= $0 && charCode <= $9) ||
    (charCode == $underscore);

bool isDigit(int charCode) => (charCode >= $0 && charCode <= $9);

class ParseException {
  ParseException(this.message, [this.source, this.index]);
  final String message;
  final String? source;
  final int? index;

  @override
  String toString() => (source == null || index == null)
      ? message
      : '$message At character: $index, in source "$source"';
}

String substitute(String source, values, EncodeValue encodeValue) {
  _ValueEncoder valueEncoder;
  if (values is List) {
    valueEncoder = _createListValueEncoder(values, encodeValue);
  } else if (values is Map) {
    valueEncoder = _createMapValueEncoder(values, encodeValue);
  } else if (values == null) {
    valueEncoder = _nullValueEncoder;
  } else {
    throw ArgumentError('Unexpected type.');
  }

  final buf = StringBuffer(), s = Scanner(source), cache = HashMap();

  while (s.hasMore()) {
    var t = s.read()!;
    if (t.type == tokenIdent) {
      final id = t.value, typeName = t.typeName, key = Pair(id, typeName);
      buf.write(cache[key] ?? (cache[key] = valueEncoder(id, typeName)));
    } else {
      buf.write(t.value);
    }
  }

  return buf.toString();
}

String _nullValueEncoder(value, String? type) => throw ParseException(
    'Template contains a parameter, but no values were passed.');

_ValueEncoder _createListValueEncoder(List list, EncodeValue encodeValue) =>
    (String identifier, String? type) {
      int i = int.tryParse(identifier) ??
          (throw ParseException('Expected integer parameter.'));

      if (i < 0 || i >= list.length) {
        throw ParseException('Substitution token out of range.');
      }

      return encodeValue(list[i], type);
    };

_ValueEncoder _createMapValueEncoder(Map map, EncodeValue encodeValue) =>
    (String identifier, String? type) {
      final val = map[identifier];
      if (val == null && !map.containsKey(identifier)) {
        throw ParseException("Substitution token not passed: $identifier.");
      }

      return encodeValue(val, type);
    };

class Scanner {
  Scanner(String source) : _r = _CharReader(source) {
    if (_r.hasMore()) _t = _read();
  }

  final _CharReader _r;
  Token? _t;

  bool hasMore() => _t != null;

  Token? peek() => _t;

  Token? read() {
    var t = _t;
    _t = _r.hasMore() ? _read() : null;
    return t;
  }

  Token _read() {
    assert(_r.hasMore());

    if (_r.peek() == $at) {
      _r.read();

      if (!_r.hasMore()) throw ParseException('Unexpected end of input.');

      if (!isIdentifier(_r.peek())) {
        final s = String.fromCharCode(_r.read());
        return Token(tokenText, '@$s');
      }

      var ident = _r.readWhile(isIdentifier);

      String? type;
      if (_r.peek() == $colon) {
        _r.read();
        type = _r.readWhile(isIdentifier);
      }
      return Token(tokenIdent, ident, type);
    }

    var text = _readText();
    return Token(tokenText, text);
  }

  String _readText() {
    int? esc;
    bool backslash = false;
    late int ndollar;
    return _r.readWhile((int c) {
      if (backslash) {
        backslash = false;
      } else if (c == $backslash) {
        backslash = true;
      } else if (esc == null) {
        switch (c) {
          case $at:
            return false;
          case $single_quote:
          case $quot:
          case $dollar:
            esc = c;
            if (c == $dollar) ndollar = 3;
            break;
        }
      } else if (c == esc) {
        if (c != $dollar || --ndollar == 0) esc = null;
      }
      return true;
    });
  }
}

class _CharReader {
  _CharReader(String source)
      : _source = source,
        _codes = source.codeUnits;

  final String _source;
  final List<int> _codes;
  int _i = 0;

  bool hasMore() => _i < _codes.length;

  int read() => hasMore() ? _codes[_i++] : 0;
  int peek() => hasMore() ? _codes[_i] : 0;

  String readWhile(bool Function(int charCode) test) {
    if (!hasMore()) {
      throw ParseException('Unexpected end of input.', _source, _i);
    }
    int start = _i;
    while (hasMore() && test(peek())) {
      read();
    }
    return String.fromCharCodes(_codes.sublist(start, _i));
  }
}

class Pair<F, S> {
  final F first;
  final S second;

  const Pair(this.first, this.second);
  Pair.fromJson(List json) : this(json[0] as F, json[1] as S);

  S get last => second;

  List toJson() => [first, second];

  @override
  int get hashCode => Object.hash(first, second);
  @override
  bool operator ==(Object o) =>
      o is Pair && first == o.first && second == o.second;
  @override
  String toString() => toJson().toString();
}
