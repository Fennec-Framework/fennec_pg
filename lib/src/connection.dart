import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fennec_pg/src/prodecure_parameters.dart';
import 'package:fennec_pg/src/substitute.dart';

import 'buffer.dart';
import 'client_message_impl.dart';
import 'constants.dart';
import 'core/fennec_pg.dart';
import 'package:crypto/crypto.dart';

import 'query.dart';

abstract class ConnectionOwner {
  void destroy();
}

class ConnectionImpl implements Connection {
  ConnectionImpl._private(
      this._socket,
      Settings settings,
      this._applicationName,
      this._timeZone,
      TypeConverter? typeConverter,
      String? debugName)
      : _userName = settings.user,
        _password = settings.password,
        _databaseName = settings.database,
        _typeConverter = typeConverter ?? TypeConverter(),
        _debugName = debugName ?? 'pg',
        _buffer = Buffer((msg) => PostgresqlException(msg, debugName));

  @override
  ConnectionState get state => _state;
  ConnectionState _state = ConnectionState.notConnected;

  TransactionState _transactionState = TransactionState.unknown;
  @override
  TransactionState get transactionState => _transactionState;

  final String _databaseName;
  final String _userName;
  final String _password;
  final String? _applicationName;
  final String? _timeZone;
  final TypeConverter _typeConverter;

  ConnectionOwner? owner;
  final Socket _socket;
  final Buffer _buffer;
  bool _hasConnected = false;
  final _connected = Completer<ConnectionImpl>();
  final Queue<Query> _sendQueryQueue = Queue<Query>();
  Query? _query;
  int? _msgType;
  int? _msgLength;

  int _transactionLevel = 0;

  int? _backendPid;
  final String _debugName;

  @override
  int? get backendPid => _backendPid;

  String get debugName => _debugName;

  @override
  String toString() => '$debugName:$_backendPid';

  final Map<String, String> _parameters = {};

  Map<String, String>? parametersView;

  @override
  Map<String, String> get parameters =>
      parametersView ?? (parametersView = UnmodifiableMapView(_parameters));

  @override
  Stream<Message> get messages => _messages.stream;

  final _messages = StreamController<Message>.broadcast();

  static Future<ConnectionImpl> connect(String uri,
      {Duration? connectionTimeout,
      String? applicationName,
      String? timeZone,
      TypeConverter? typeConverter,
      String? debugName,
      Future<Socket> Function(String host, int port)?
          mockSocketConnect}) async {
    var settings = Settings.fromUri(uri);

    connectionTimeout ??= Duration(seconds: 180);

    FutureOr<Socket> onTimeout() {
      throw PostgresqlException(
          'Postgresql connection timed out. Timeout: $connectionTimeout.',
          debugName ?? 'pg',
          exception: peConnectionTimeout);
    }

    var connectFunc = mockSocketConnect ?? Socket.connect;

    Future<Socket> future = connectFunc(settings.host, settings.port)
        .timeout(connectionTimeout, onTimeout: onTimeout);

    if (settings.requireSsl) future = _connectSsl(future);

    final socket =
        await future.timeout(connectionTimeout, onTimeout: onTimeout);

    var conn = ConnectionImpl._private(
        socket, settings, applicationName, timeZone, typeConverter, debugName);

    socket.listen(conn._readData,
        onError: conn._handleSocketError, onDone: conn._handleSocketClosed);

    conn
      .._state = ConnectionState.socketConnected
      .._sendStartupMessage();
    return conn._connected.future;
  }

  static String _md5s(String s) {
    var digest = md5.convert(s.codeUnits.toList());

    return utf8.decode(digest.bytes);
  }

  static Future<SecureSocket> _connectSsl(Future<Socket> future) {
    var completer = Completer<SecureSocket>();

    future.then((socket) {
      socket.listen((data) {
        if (data[0] != S) {
          socket.destroy();
          completer.completeError(PostgresqlException(
              'This postgresql server is not configured to support SSL '
              'connections.',
              null,
              exception: peConnectionFailed));
        } else {
          SecureSocket.secure(socket, onBadCertificate: (cert) => true)
              .then(completer.complete)
              .catchError(completer.completeError);
        }
      });

      // Write header, and SSL magic number.
      socket.add(const [0, 0, 0, 8, 4, 210, 22, 47]);
    }).catchError((ex, st) {
      completer.completeError(ex, st);
    });

    return completer.future;
  }

  void _sendStartupMessage() {
    if (_state != ConnectionState.socketConnected) {
      throw PostgresqlException('Invalid state during startup.', _debugName,
          exception: peConnectionFailed);
    }

    var msg = MessageBuffer();
    msg.addInt32(0); // Length padding.
    msg.addInt32(protocolVersion);
    msg.addUtf8String('user');
    msg.addUtf8String(_userName);
    msg.addUtf8String('database');
    msg.addUtf8String(_databaseName);
    msg.addUtf8String('client_encoding');
    msg.addUtf8String('UTF8');
    final tz = _timeZone;
    if (tz != null) {
      msg.addUtf8String('TimeZone');
      msg.addUtf8String(tz);
    }
    final app = _applicationName;
    if (app != null) {
      msg.addUtf8String('application_name');
      msg.addUtf8String(app);
    }
    msg.addByte(0);
    msg.setLength(startup: true);

    _socket.add(msg.buffer);

    _state = ConnectionState.authenticating;
  }

  void _readAuthenticationRequest(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    if (_state != ConnectionState.authenticating) {
      throw PostgresqlException(
          'Invalid connection state while authenticating.', _debugName,
          exception: peConnectionFailed);
    }

    int authType = _buffer.readInt32();

    if (authType == authTypeOk) {
      _state = ConnectionState.authenticated;
      return;
    }

    // Only MD5 authentication is supported.
    if (authType != authTypeMd5) {
      throw PostgresqlException(
          'Unsupported or unknown authentication '
          'type: ${authTypeAsString(authType)}, only MD5 authentication is '
          'supported.',
          _debugName,
          exception: peConnectionFailed);
    }

    var bytes = _buffer.readBytes(4);
    var salt = String.fromCharCodes(bytes);
    var md5 = 'md5' + _md5s(_md5s(_password + _userName) + salt);

    // Build message.
    var msg = MessageBuffer();
    msg.addByte(msgPassword);
    msg.addInt32(0);
    msg.addUtf8String(md5);
    msg.setLength();

    _socket.add(msg.buffer);
  }

  void _readReadyForQuery(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    int c = _buffer.readByte();

    if (c == I || c == T || c == E) {
      if (c == I) {
        _transactionState = TransactionState.none;
      } else if (c == T) {
        _transactionState = TransactionState.begun;
      } else if (c == E) {
        _transactionState = TransactionState.error;
      }

      var was = _state;

      _state = ConnectionState.idle;

      _query?.close();
      _query = null;

      if (was == ConnectionState.authenticated) {
        _hasConnected = true;
        _connected.complete(this);
      }

      Timer.run(_processSendQueryQueue);
    } else {
      _destroy();
      throw PostgresqlException(
          'Unknown ReadyForQuery transaction status: '
          '${itoa(c)}.',
          _debugName);
    }
  }

  void _handleSocketError(error, {bool closed = false}) {
    if (_state == ConnectionState.closed) {
      _messages.add(ClientMessageImpl(
          isError: false,
          severity: 'WARNING',
          message: 'Socket error after socket closed.',
          connectionName: _debugName,
          exception: error));
      _destroy();
      return;
    }

    _destroy();

    var msg = closed ? 'Socket closed unexpectedly.' : 'Socket error.';

    if (!_hasConnected) {
      _connected
          .completeError(PostgresqlException(msg, debugName, exception: error));
    } else {
      final query = _query;
      if (query != null) {
        query.addError(PostgresqlException(msg, debugName, exception: error));
      } else {
        _messages.add(ClientMessage(
            isError: true,
            connectionName: debugName,
            severity: 'ERROR',
            message: msg,
            exception: error));
      }
    }
  }

  void _handleSocketClosed() {
    if (_state != ConnectionState.closed) {
      _handleSocketError(null, closed: true);
    }
  }

  void _readData(List<int> data) {
    try {
      if (_state == ConnectionState.closed) return;

      _buffer.append(data);

      final msgType = _msgType;
      if (msgType != null) {
        final msgLength = _msgLength!;
        if (msgLength > _buffer.bytesAvailable) {
          return;
        }

        _readMessage(msgType, msgLength);

        _msgType = null;
        _msgLength = null;
      }

      while (_state != ConnectionState.closed) {
        if (_buffer.bytesAvailable < 5) return;
        int msgType = _buffer.readByte();
        int length = _buffer.readInt32() - 4;

        if (!_checkMessageLength(msgType, length + 4)) {
          throw PostgresqlException('Lost message sync.', debugName);
        }

        if (length > _buffer.bytesAvailable) {
          _msgType = msgType;
          _msgLength = length;
          return;
        }

        _readMessage(msgType, length);
      }
    } catch (_) {
      _destroy();
      rethrow;
    }
  }

  bool _checkMessageLength(int msgType, int msgLength) {
    if (_state == ConnectionState.authenticating) {
      if (msgLength < 8) return false;
      if (msgType == msgAuthRequest && msgLength > 2000) return false;
      if (msgType == msgErrorResponse && msgLength > 30000) return false;
    } else {
      if (msgLength < 4) return false;
      if (msgLength > 30000 &&
          (msgType != msgNoticeResponse &&
              msgType != msgErrorResponse &&
              msgType != msgCopyData &&
              msgType != msgRowDescription &&
              msgType != msgDataRow &&
              msgType != msgFunctionCallResponse &&
              msgType != msgNotificationResponse)) {
        return false;
      }
    }
    return true;
  }

  void _readMessage(int msgType, int length) {
    int pos = _buffer.bytesRead;

    switch (msgType) {
      case msgAuthRequest:
        _readAuthenticationRequest(msgType, length);
        break;
      case msgReadyForQuery:
        _readReadyForQuery(msgType, length);
        break;

      case msgErrorResponse:
      case msgNoticeResponse:
        _readErrorOrNoticeResponse(msgType, length);
        break;

      case msgBackendKeyData:
        _readBackendKeyData(msgType, length);
        break;
      case msgParameterStatus:
        _readParameterStatus(msgType, length);
        break;

      case msgRowDescription:
        _readRowDescription(msgType, length);
        break;
      case msgDataRow:
        _readDataRow(msgType, length);
        break;
      case msgEmptyQueryResponse:
        assert(length == 0);
        break;
      case msgCommandComplete:
        _readCommandComplete(msgType, length);
        break;

      default:
        throw PostgresqlException(
            'Unknown, or unimplemented message: '
            '${utf8.decode([msgType])}.',
            debugName);
    }

    if (pos + length != _buffer.bytesRead) {
      throw PostgresqlException('Lost message sync.', debugName);
    }
  }

  void _readErrorOrNoticeResponse(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    var map = <String, String>{};
    int errorCode = _buffer.readByte();
    while (errorCode != 0) {
      var msg = _buffer.readUtf8String(length);
      map[String.fromCharCode(errorCode)] = msg;
      errorCode = _buffer.readByte();
    }

    var msg = ServerMessageImpl(msgType == msgErrorResponse, map, debugName);

    var ex = PostgresqlException(msg.message, debugName,
        serverMessage: msg, exception: msg.code);

    if (msgType == msgErrorResponse) {
      if (!_hasConnected) {
        _state = ConnectionState.closed;
        _socket.destroy();
        _connected.completeError(ex);
      } else {
        final query = _query;
        if (query != null) {
          query.addError(ex);
        } else {
          _messages.add(msg);
        }

        if (msg.code?.startsWith('57P') ?? false) {
          //PG stop/restart
          final ow = owner;
          if (ow != null) {
            ow.destroy();
          } else {
            _state = ConnectionState.closed;
            _socket.destroy();
          }
        }
      }
    } else {
      _messages.add(msg);
    }
  }

  void _readBackendKeyData(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    _backendPid = _buffer.readInt32();
    /*_secretKey =*/ _buffer.readInt32();
  }

  void _readParameterStatus(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    var name = _buffer.readUtf8String(10000);
    var value = _buffer.readUtf8String(10000);

    warn(msg) {
      _messages.add(ClientMessageImpl(
          severity: 'WARNING', message: msg, connectionName: debugName));
    }

    _parameters[name] = value;
    if (name == 'client_encoding' && value != 'UTF8') {
      warn('client_encoding parameter must remain as UTF8 for correct string '
          'handling. client_encoding is: "$value".');
    }
  }

  @override
  Stream<Row> query(String sql, [values]) {
    try {
      if (values != null) sql = substitute(sql, values, _typeConverter.encode);
      var query = _enqueueQuery(sql);
      return query.stream as Stream<Row>;
    } catch (ex, st) {
      return Stream.fromFuture(Future.error(ex, st));
    }
  }

  @override
  Stream<IRow> callProcedure(
      {required String procedureName,
      required List<ProcedureCallParameters> parameters}) {
    String sql = 'call $procedureName(';
    for (int i = 0; i < parameters.length; i++) {
      if (i < parameters.length - 1) {
        sql +=
            '${parameters[i].name} => ${parameters[i].value}::${parameters[i].columnType.name}, ';
      } else {
        sql +=
            '${parameters[i].name} => ${parameters[i].value}::${parameters[i].columnType.name}) ';
      }
    }
    print(sql);
    return query(sql);
  }

  @override
  Stream<IRow> createProcedure(
      {required String procedureName,
      required List<ProcedureParameters> parameters,
      required ProcedureParameters out,
      required String body}) {
    String sql = '';
    sql += ' create or replace procedure ' + procedureName + '(\n';

    if (parameters.isEmpty) {
      sql += out.name + ' ' + 'OUT' + out.columnType.name + ')\n';
    } else {
      sql += out.name + ' ' + 'OUT' + out.columnType.name + ',\n';
    }
    for (int i = 0; i < parameters.length; i++) {
      if (i < parameters.length - 1) {
        sql += parameters[i].name +
            ' ' +
            'IN' +
            parameters[i].columnType.name +
            ',\n';
      } else {
        sql += parameters[i].name +
            ' ' +
            'IN' +
            parameters[i].columnType.name +
            ')\n';
      }
    }
    sql += 'language plpgsql \n';
    sql += 'as \$\$ \n';
    sql += 'begin \n';
    sql += '$body \n';

    sql += 'end;\$\$ \n';
    print(sql);
    return query(sql);
  }

  @override
  Future<int> execute(String sql, [values]) async {
    if (values != null) sql = substitute(sql, values, _typeConverter.encode);

    var query = _enqueueQuery(sql);
    await query.stream.isEmpty;
    return query.rowsAffected ?? 0;
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation,
      [Isolation isolation = Isolation.readCommitted]) async {
    String begin;
    String commit;
    String rollback;
    if (_transactionLevel > 0) {
      final name = 'sp$_transactionLevel';
      begin = 'savepoint $name';
      commit = 'release savepoint $name';
      rollback = 'rollback to savepoint $name';
    } else {
      if (isolation == Isolation.repeatableRead) {
        begin = 'begin; set transaction isolation level repeatable read;';
      } else if (isolation == Isolation.serializable) {
        begin = 'begin; set transaction isolation level serializable;';
      } else {
        begin = 'begin';
      }
      commit = 'commit';
      rollback = 'rollback';
    }
    try {
      ++_transactionLevel;
      await execute(begin);
      final result = await operation();
      await execute(commit);
      return result;
    } catch (_) {
      await execute(rollback);
      rethrow;
    } finally {
      assert(_transactionLevel > 0);
      --_transactionLevel;
    }
  }

  Query _enqueueQuery(String sql) {
    if (sql == '') {
      throw PostgresqlException('SQL query is null or empty.', debugName);
    }

    if (sql.contains('\u0000')) {
      throw PostgresqlException(
          'Sql query contains a null character.', debugName);
    }

    if (_state == ConnectionState.closed) {
      throw PostgresqlException(
          'Connection is closed, cannot execute query.', debugName,
          exception: peConnectionClosed);
    }

    var query = Query(sql);
    _sendQueryQueue.addLast(query);

    Timer.run(_processSendQueryQueue);

    return query;
  }

  void _processSendQueryQueue() {
    if (_sendQueryQueue.isEmpty) return;

    if (_query != null) return;

    if (_state == ConnectionState.closed) return;

    assert(_state == ConnectionState.idle);

    final query = _query = _sendQueryQueue.removeFirst();

    var msg = MessageBuffer();
    msg.addByte(msgQuery);
    msg.addInt32(0); // Length padding.
    msg.addUtf8String(query.sql);
    msg.setLength();

    _socket.add(msg.buffer);

    _state = ConnectionState.busy;
    query.state = busy;
    _transactionState = TransactionState.unknown;
  }

  void _readRowDescription(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    _state = ConnectionState.streaming;

    int count = _buffer.readInt16();
    var list = <Column>[];

    for (int i = 0; i < count; i++) {
      var name = _buffer.readUtf8String(length);
      int fieldId = _buffer.readInt32();
      int tableColNo = _buffer.readInt16();
      int fieldType = _buffer.readInt32();
      int dataSize = _buffer.readInt16();
      int typeModifier = _buffer.readInt32();
      int formatCode = _buffer.readInt16();

      list.add(Column(i, name, fieldId, tableColNo, fieldType, dataSize,
          typeModifier, formatCode));
    }

    final query = _query!;
    query.columnCount = count;
    query.columns = UnmodifiableListView(list);
    query.commandIndex++;

    query.addRowDescription();
  }

  void _readDataRow(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    int columns = _buffer.readInt16();
    for (var i = 0; i < columns; i++) {
      int size = _buffer.readInt32();
      _readColumnData(i, size);
    }
  }

  void _readColumnData(int index, int colSize) {
    assert(_buffer.bytesAvailable >= colSize);

    final query = _query!;
    if (index == 0) {
      query.rowData = List<dynamic>.filled(query.columns!.length, null);
    }
    final rowData = query.rowData!;

    if (colSize == -1) {
      rowData[index] = null;
    } else {
      var col = query.columns![index];
      if (col.isBinary) {
        throw PostgresqlException(
            'Binary result set parsing is not implemented.', debugName);
      }

      var str = _buffer.readUtf8StringN(colSize),
          value = _typeConverter.decode(str, col.fieldType,
              connectionName: _debugName);

      rowData[index] = value;
    }

    if (index == query.columnCount! - 1) query.addRow();
  }

  void _readCommandComplete(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    var commandString = _buffer.readUtf8String(length);
    int rowsAffected = int.tryParse(commandString.split(' ').last) ?? 0;

    final query = _query!;
    query.commandIndex++;
    query.rowsAffected = rowsAffected;
  }

  @override
  void close() {
    if (_state == ConnectionState.closed) return;
    _state = ConnectionState.closed;

    final query = _query;
    if (query != null) {
      var c = query.controller;
      if (!c.isClosed) {
        c.addError(PostgresqlException(
            'Connection closed before query could complete', debugName,
            exception: peConnectionClosed));
        c.close();
        _query = null;
      }
    }

    try {
      var msg = MessageBuffer();
      msg.addByte(msgTerminate);
      msg.addInt32(0);
      msg.setLength();
      _socket.add(msg.buffer);
      _socket.flush().whenComplete(_destroy);
    } catch (e, st) {
      _messages.add(ClientMessageImpl(
          severity: 'WARNING',
          message: 'Exception while closing connection. Closed without sending '
              'terminate message.',
          connectionName: debugName,
          exception: e,
          stackTrace: st));
    }
  }

  void _destroy() {
    _state = ConnectionState.closed;
    _socket.destroy();
    Timer.run(_messages.close);
  }
}
