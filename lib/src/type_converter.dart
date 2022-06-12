import 'dart:convert';

import 'package:fennec_pg/src/constants.dart';

import 'ascii.dart';
import 'core/fennec_pg.dart';

const escapes = {
  "'": r"\'",
  "\r": r"\r",
  "\n": r"\n",
  r"\": r"\\",
  "\t": r"\t",
  "\b": r"\b",
  "\f": r"\f",
  "\u0000": "",
};

/// Characters that will be escapes.
const escapePattern = r"'\r\n\\\t\b\f\u0000"; //detect unsupported null
final _escapeRegExp = RegExp("[$escapePattern]");

class RawTypeConverter extends DefaultTypeConverter {
  @override
  String encode(value, String? type, {String? connectionName}) =>
      encodeValue(value, type);

  @override
  decode(String value, int pgType, {String? connectionName}) => value;
}

/// Encodes the given string ([s]) into the format: ` E'xxx'`
///
/// > Note: the null character (`\u0000`) will be removed, since
/// > PostgreSql won't accept it.
String encodeString(String? s) {
  if (s == null) return ' null ';

  var escaped = s.replaceAllMapped(_escapeRegExp, _escape);
  return " E'$escaped' ";
}

String _escape(Match m) => escapes[m[0]]!;

class DefaultTypeConverter implements TypeConverter {
  @override
  String encode(value, String? type, {String? connectionName}) =>
      encodeValue(value, type, connectionName: connectionName);

  @override
  decode(String value, int pgType, {String? connectionName}) =>
      decodeValue(value, pgType, connectionName: connectionName);

  PostgresqlException _error(String msg, String? connectionName) {
    return PostgresqlException(msg, connectionName);
  }

  String encodeValue(value, String? type, {String? connectionName}) {
    if (type == null) {
      return encodeValueDefault(value, connectionName: connectionName);
    }
    if (value == null) return 'null';

    switch (type) {
      case 'text':
      case 'string':
        return encodeString(value.toString());

      case 'integer':
      case 'smallint':
      case 'bigint':
      case 'serial':
      case 'bigserial':
      case 'int':
        if (value is int || value is BigInt) return encodeNumber(value);
        break;

      case 'real':
      case 'double':
      case 'num':
      case 'number':
      case 'numeric':
      case 'decimal': //Work only for smaller precision
        if (value is num || value is BigInt) return encodeNumber(value);
        break;

      case 'boolean':
      case 'bool':
        if (value is bool) return value.toString();
        break;

      case 'timestamp':
      case 'timestamptz':
      case 'datetime':
        if (value is DateTime) return encodeDateTime(value, isDateOnly: false);
        break;

      case 'date':
        if (value is DateTime) return encodeDateTime(value, isDateOnly: true);
        break;

      case 'json':
      case 'jsonb':
        return encodeJson(value);

      case 'array':
        if (value is Iterable) return encodeArray(value);
        break;

      case 'bytea':
        if (value is Iterable<int>) return encodeBytea(value);
        break;

      default:
        if (type.endsWith('_array')) {
          return encodeArray(value, pgType: type.substring(0, type.length - 6));
        }

        final t = type.toLowerCase(); //backward compatible
        if (t != type) {
          return encodeValue(value, t, connectionName: connectionName);
        }

        throw _error('Unknown type name: $type.', connectionName);
    }

    throw _error(
        'Invalid runtime type and type modifier: '
        '${value.runtimeType} to $type.',
        connectionName);
  }

  // Unspecified type name. Use default type mapping.
  String encodeValueDefault(value, {String? connectionName}) {
    if (value == null) return 'null';
    if (value is num) return encodeNumber(value);
    if (value is String) return encodeString(value);
    if (value is DateTime) return encodeDateTime(value, isDateOnly: false);
    if (value is bool || value is BigInt) return value.toString();
    if (value is Iterable) return encodeArray(value);
    return encodeJson(value);
  }

  String encodeNumber(num n) {
    if (n.isNaN) return "'nan'";
    if (n == double.infinity) return "'infinity'";
    if (n == double.negativeInfinity) return "'-infinity'";
    return n.toString();
  }

  String encodeArray(Iterable value, {String? pgType}) {
    final buf = StringBuffer('array[');
    for (final v in value) {
      if (buf.length > 6) buf.write(',');
      buf.write(encodeValueDefault(v));
    }
    buf.write(']');
    if (pgType != null) {
      buf
        ..write('::')
        ..write(pgType)
        ..write('[]');
    }
    return buf.toString();
  }

  String encodeDateTime(DateTime? datetime, {bool isDateOnly = false}) {
    if (datetime == null) return 'null';

    var string = datetime.toIso8601String();

    if (isDateOnly) {
      string = string.split("T").first;
    } else {
      // ISO8601 UTC times already carry Z, but local times carry no timezone info
      // so this code will append it.
      if (!datetime.isUtc) {
        var timezoneHourOffset = datetime.timeZoneOffset.inHours;
        var timezoneMinuteOffset = datetime.timeZoneOffset.inMinutes % 60;

        // Note that the sign is stripped via abs() and appended later.
        var hourComponent = timezoneHourOffset.abs().toString().padLeft(2, "0");
        var minuteComponent =
            timezoneMinuteOffset.abs().toString().padLeft(2, "0");

        if (timezoneHourOffset >= 0) {
          hourComponent = "+$hourComponent";
        } else {
          hourComponent = "-$hourComponent";
        }

        var timezoneString = [hourComponent, minuteComponent].join(":");
        string = [string, timezoneString].join("");
      }
    }

    if (string.substring(0, 1) == "-") {
      // Postgresql uses a BC suffix for dates rather than the negative prefix returned by
      // dart's ISO8601 date string.
      string = string.substring(1) + " BC";
    } else if (string.substring(0, 1) == "+") {
      // Postgresql doesn't allow leading + signs for 6 digit dates. Strip it out.
      string = string.substring(1);
    }

    return "'$string'";
  }

  String encodeJson(value) => encodeString(jsonEncode(value));

  // See http://www.postgresql.org/docs/9.0/static/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
  String encodeBytea(Iterable<int> value) {
    //var b64String = ...;
    //return " decode('$b64String', 'base64') ";

    throw _error(
        'bytea encoding not implemented. Pull requests welcome ;)', null);
  }

  decodeValue(String value, int pgType, {String? connectionName}) {
    switch (pgType) {
      case boolPg:
        return value == 't';

      case int2: // smallint
      case int4: // integer
      case int8: // bigint
        return int.parse(value);

      case float4: // real
      case float8: // double precision
      case numeric: //Work only for smaller precision
        return double.parse(value);

      case timestamp:
      case timestampz:
      case date:
        return decodeDateTime(value, pgType, connectionName: connectionName);

      case json:
      case jsonb:
        return jsonDecode(value);

      //TODO binary bytea

      // Not implemented yet - return a string.
      //case _MONEY:
      //case _TIMETZ:
      //case _TIME:
      //case _INTERVAL:

      default:
        final scalarType = _arrayTypes[pgType];
        if (scalarType != null) {
          return decodeArray(value, scalarType, connectionName: connectionName);
        }

        // Return a string for unknown types. The end user can parse this.
        return value;
    }
  }

  static const _arrayTypes = {
    bitArray: bit,
    boolArray: boolPg,
    bpCharArray: bpChar,
    byteaArray: bytea,
    charArray: char,
    dateArray: date,
    float4Array: float4,
    float8Array: float8,
    int2Array: int2,
    int4Array: int4,
    int8Array: int8,
    intervalArray: interval,
    jsonArray: json,
    jsonbArray: jsonb,
    moneyArray: money,
    nameArray: name,
    numericArray: numeric,
    oidArray: oid,
    textArray: text,
    timeArray: time,
    timestampArray: timestamp,
    timestampzArray: timestamp,
    timetzArray: timetz,
    uuidArray: uuid,
    varbitArray: varbit,
    varcharArray: varchar,
    xmlArray: xml,
  };

  /// Decodes [value] into a [DateTime] instance.
  ///
  /// Note: it will convert it to local time (via [DateTime.toLocal])
  DateTime decodeDateTime(String value, int pgType, {String? connectionName}) {
    // Built in Dart dates can either be local time or utc. Which means that the
    // the postgresql timezone parameter for the connection must be either set
    // to UTC, or the local time of the server on which the client is running.
    // This restriction could be relaxed by using a more advanced date library
    // capable of creating DateTimes for a non-local time zone.

    if (value == 'infinity' || value == '-infinity') {
      throw _error(
          'A timestamp value "$value", cannot be represented '
          'as a Dart object.',
          connectionName);
    }
    //if infinity values are required, rewrite the sql query to cast
    //the value to a string, i.e. your_column::text.

    var formattedValue = value;

    // Postgresql uses a BC suffix rather than a negative prefix as in ISO8601.
    if (value.endsWith(' BC')) {
      formattedValue = '-' + value.substring(0, value.length - 3);
    }

    if (pgType == timestamp) {
      formattedValue += 'Z';
    } else if (pgType == timestampz) {
      // PG will return the timestamp in the connection's timezone. The resulting DateTime.parse will handle accordingly.
    } else if (pgType == date) {
      formattedValue = formattedValue + 'T00:00:00Z';
    }

    return DateTime.parse(formattedValue).toLocal();
  }

  /// Decodes an array value, [value]. Each item of it is [pgType].
  decodeArray(String value, int pgType, {String? connectionName}) {
    final len = value.length - 2;
    assert(
        value.codeUnitAt(0) == $lbrace && value.codeUnitAt(len + 1) == $rbrace);
    if (len <= 0) return [];
    value = value.substring(1, len + 1);

    if (const {text, char, varchar, name}.contains(pgType)) {
      final result = [];
      for (int i = 0; i < len; ++i) {
        if (value.codeUnitAt(i) == $quot) {
          final buf = <int>[];
          for (;;) {
            final cc = value.codeUnitAt(++i);
            if (cc == $quot) {
              result.add(String.fromCharCodes(buf));
              ++i;
              assert(i >= len || value.codeUnitAt(i) == $comma);
              break;
            }
            if (cc == $backslash) {
              buf.add(value.codeUnitAt(++i));
            } else {
              buf.add(cc);
            }
          }
        } else {
          //not quoted
          for (int j = i;; ++j) {
            if (j >= len || value.codeUnitAt(j) == $comma) {
              final v = value.substring(i, j);
              result.add(v == 'NULL' ? null : v);
              i = j;
              break;
            }
          }
        }
      }
      return result;
    }

    if (const {json, jsonb}.contains(pgType)) return jsonDecode('[$value]');

    final result = [];
    for (final v in value.split(',')) {
      result.add(v == 'NULL'
          ? null
          : decodeValue(v, pgType, connectionName: connectionName));
    }
    return result;
  }
}
