import 'dart:collection';
import 'dart:convert';

import 'dart:typed_data';

abstract class ProtocolMessage {
  int get messageCode;
  List<int> encode();
}

class Startup implements ProtocolMessage {
  Startup(this.user, this.database, [this.parameters = const {}]);
  @override
  final int messageCode = 0;
  final int protocolVersion = 196608;
  final String user;
  final String database;
  final Map<String, String> parameters;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)
      ..addInt32(protocolVersion)
      ..addUtf8('user')
      ..addUtf8(user)
      ..addUtf8('database')
      ..addUtf8(database)
      ..addUtf8('client_encoding')
      ..addUtf8('utf8');
    parameters.forEach((k, v) {
      mb.addUtf8(k);
      mb.addUtf8(v);
    });
    mb.addByte(0);

    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'protocolVersion': protocolVersion,
        'user': user,
        'database': database
      });
}

class SslRequest implements ProtocolMessage {
  @override
  final int messageCode = 0;
  @override
  List<int> encode() => <int>[0, 0, 0, 8, 4, 210, 22, 47];

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
      });
}

class Terminate implements ProtocolMessage {
  @override
  final int messageCode = 'X'.codeUnitAt(0);
  @override
  List<int> encode() => _MessageBuilder(messageCode).build();

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
      });
}

const int authTypeOk = 0;
const int authTypeMd5 = 5;

class AuthenticationRequest implements ProtocolMessage {
  AuthenticationRequest.ok()
      : authType = authTypeOk,
        salt = null;

  AuthenticationRequest.md5(this.salt) : authType = authTypeMd5 {
    if (salt?.length != 4) throw ArgumentError();
  }

  @override
  final int messageCode = 'R'.codeUnitAt(0);
  final int authType;
  final List<int>? salt;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode);
    mb.addInt32(authType);
    if (authType == authTypeMd5) mb.addBytes(salt!);
    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'authType': {0: "ok", 5: "md5"}[authType],
        'salt': salt
      });
}

class BackendKeyData implements ProtocolMessage {
  BackendKeyData(this.backendPid, this.secretKey);

  @override
  final int messageCode = 'K'.codeUnitAt(0);
  final int backendPid;
  final int secretKey;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)
      ..addInt32(backendPid)
      ..addInt32(secretKey);
    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'backendPid': backendPid,
        'secretKey': secretKey
      });
}

class ParameterStatus implements ProtocolMessage {
  ParameterStatus(this.name, this.value);

  @override
  final int messageCode = 'S'.codeUnitAt(0);
  final String name;
  final String value;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)
      ..addUtf8(name)
      ..addUtf8(value);
    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'name': name,
        'value': value
      });
}

class Query implements ProtocolMessage {
  Query(this.query);

  @override
  final int messageCode = 'Q'.codeUnitAt(0);
  final String query;

  @override
  List<int> encode() => (_MessageBuilder(messageCode)..addUtf8(query)).build();

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'query': query
      });
}

class Field {
  Field(this.name, this.fieldType);
  final String name;
  final int fieldId = 0;
  final int tableColNo = 0;
  final int fieldType;
  final int dataSize = -1;
  final int typeModifier = 0;
  final int formatCode = 0;
  bool get isBinary => formatCode == 1;

  @override
  String toString() => json.encode({
        'name': name,
        'fieldId': fieldId,
        'tableColNo': tableColNo,
        'fieldType': fieldType,
        'dataSize': dataSize,
        'typeModifier': typeModifier,
        'formatCode': formatCode
      });
}

class RowDescription implements ProtocolMessage {
  RowDescription(this.fields);

  @override
  final int messageCode = 'T'.codeUnitAt(0);
  final List<Field> fields;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)..addInt16(fields.length);

    for (var f in fields) {
      mb
        ..addUtf8(f.name)
        ..addInt32(f.fieldId)
        ..addInt16(f.tableColNo)
        ..addInt32(f.fieldType)
        ..addInt16(f.dataSize)
        ..addInt32(f.typeModifier)
        ..addInt16(f.formatCode);
    }

    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'fields': fields
      });
}

class DataRow implements ProtocolMessage {
  DataRow.fromBytes(this.values);

  DataRow.fromStrings(List<String> strings)
      : values = strings.map(utf8.encode).toList(growable: false);

  @override
  final int messageCode = 'D'.codeUnitAt(0);
  final List<List<int>> values;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)..addInt16(values.length);

    for (var bytes in values) {
      mb
        ..addInt32(bytes.length)
        ..addBytes(bytes);
    }

    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'values': values.map(utf8.decode)
      });
}

class CommandComplete implements ProtocolMessage {
  CommandComplete(this.tag);

  CommandComplete.insert(int oid, int rows) : this('INSERT $oid $rows');
  CommandComplete.delete(int rows) : this('DELETE $rows');
  CommandComplete.update(int rows) : this('UPDATE $rows');
  CommandComplete.select(int rows) : this('SELECT $rows');
  CommandComplete.move(int rows) : this('MOVE $rows');
  CommandComplete.fetch(int rows) : this('FETCH $rows');
  CommandComplete.copy(int rows) : this('COPY $rows');

  @override
  final int messageCode = 'C'.codeUnitAt(0);
  final String tag;

  @override
  List<int> encode() => (_MessageBuilder(messageCode)..addUtf8(tag)).build();

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'tag': tag
      });
}

enum TransactionStatus { none, transaction, failed }

class ReadyForQuery implements ProtocolMessage {
  ReadyForQuery(this.transactionStatus);

  @override
  final int messageCode = 'Z'.codeUnitAt(0);
  final TransactionStatus transactionStatus;

  static final Map _txStatus = {
    TransactionStatus.none: 'I'.codeUnitAt(0),
    TransactionStatus.transaction: 'T'.codeUnitAt(0),
    TransactionStatus.failed: 'E'.codeUnitAt(0)
  };

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode)
      ..addByte(_txStatus[transactionStatus]);
    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'transactionStatus': _txStatus[transactionStatus]
      });
}

abstract class BaseResponse implements ProtocolMessage {
  BaseResponse(Map<String, String> fields)
      : fields = UnmodifiableMapView<String, String>(fields) {
    assert(fields.keys.every((k) => k.length == 1));
  }

  String? get severity => fields['S'];
  String? get code => fields['C'];
  String? get message => fields['M'];
  String? get detail => fields['D'];
  String? get hint => fields['H'];
  String? get position => fields['P'];
  String? get internalPosition => fields['p'];
  String? get internalQuery => fields['q'];
  String? get where => fields['W'];
  String? get schema => fields['s'];
  String? get table => fields['t'];
  String? get column => fields['c'];
  String? get dataType => fields['d'];
  String? get constraint => fields['n'];
  String? get file => fields['F'];
  String? get line => fields['L'];
  String? get routine => fields['R'];

  final Map<String, String> fields;

  @override
  List<int> encode() {
    var mb = _MessageBuilder(messageCode);
    fields.forEach((k, v) => mb
      ..addUtf8(k)
      ..addUtf8(v));
    mb.addByte(0);
    return mb.build();
  }

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode),
        'fields': fields
      });
}

class ErrorResponse extends BaseResponse implements ProtocolMessage {
  ErrorResponse(Map<String, String> fields) : super(fields);
  @override
  final int messageCode = 'E'.codeUnitAt(0);
}

class NoticeResponse extends BaseResponse implements ProtocolMessage {
  NoticeResponse(Map<String, String> fields) : super(fields);
  @override
  final int messageCode = 'N'.codeUnitAt(0);
}

class EmptyQueryResponse implements ProtocolMessage {
  @override
  final int messageCode = 'I'.codeUnitAt(0);

  @override
  List<int> encode() => _MessageBuilder(messageCode).build();

  @override
  String toString() => json.encode({
        'msg': runtimeType.toString(),
        'code': String.fromCharCode(messageCode)
      });
}

class _MessageBuilder {
  _MessageBuilder(this._messageCode) {
    if (_messageCode != 0) _builder.addByte(_messageCode);

    _builder.add(const [0, 0, 0, 0]);
  }

  final int _messageCode;
  final BytesBuilder _builder = BytesBuilder(copy: true);

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _builder.addByte(byte);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0) i = 0x10000 + i;

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _builder.addByte(a);
    _builder.addByte(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0) i = 0x100000000 + i;

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _builder.addByte(a);
    _builder.addByte(b);
    _builder.addByte(c);
    _builder.addByte(d);
  }

  void addUtf8(String s) {
    _builder.add(utf8.encode(s));
    addByte(0);
  }

  void addBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  List<int> build() {
    var bytes = _builder.toBytes();

    int offset = 0;
    int i = bytes.length;

    if (_messageCode != 0) {
      offset = 1;
      i -= 1;
    }

    bytes[offset] = (i >> 24) & 0x000000FF;
    bytes[offset + 1] = (i >> 16) & 0x000000FF;
    bytes[offset + 2] = (i >> 8) & 0x000000FF;
    bytes[offset + 3] = i & 0x000000FF;

    return bytes;
  }
}
