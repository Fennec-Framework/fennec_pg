import '../client_message_impl.dart';
import '../connection.dart';
import '../settings_impl.dart';
import '../type_converter.dart';

Future<Connection> connect(String uri,
        {Duration? connectionTimeout,
        String? applicationName,
        String? timeZone,
        TypeConverter? typeConverter,
        String? debugName}) =>
    ConnectionImpl.connect(uri,
        connectionTimeout: connectionTimeout,
        applicationName: applicationName,
        timeZone: timeZone,
        typeConverter: typeConverter,
        debugName: debugName);

abstract class Connection {
  Stream<ARow> query(String sql, [values]);
  Future<int> execute(String sql, [values]);
  Future<T> runInTransaction<T>(Future<T> Function() operation,
      [Isolation isolation]);
  void close();
  Stream<Message> get messages;
  Map<String, String> get parameters;
  int? get backendPid;
  ConnectionState get state;
  TransactionState get transactionState;
}

abstract class ARow {
  operator [](int i);
  List toList();
  Map toMap();
  List<AColumn> getColumns();
}

abstract class AColumn {
  int get index;
  String get name;
  int get fieldId;
  int get tableColNo;
  int get fieldType;
  int get dataSize;
  int get typeModifier;
  int get formatCode;
  bool get isBinary;
}

abstract class Message {
  bool get isError;
  String? get severity;
  String? get message;
  String? get connectionName;
}

abstract class ClientMessage implements Message {
  factory ClientMessage(
      {bool isError,
      required String severity,
      required String message,
      String? connectionName,
      Object? exception,
      StackTrace? stackTrace}) = ClientMessageImpl;

  Object? get exception;

  StackTrace? get stackTrace;
}

abstract class ServerMessage implements Message {
  @override
  bool get isError;
  Map<String, String> get fields;
  @override
  String? get connectionName;
  @override
  String? get severity;
  String? get code;
  @override
  String? get message;
  String? get detail;
  String? get hint;
  String? get position;
  String? get internalPosition;
  String? get internalQuery;
  String? get where;
  String? get schema;
  String? get table;
  String? get column;
  String? get dataType;
  String? get constraint;
  String? get file;
  String? get line;
  String? get routine;
}

abstract class TypeConverter {
  factory TypeConverter() = DefaultTypeConverter;
  factory TypeConverter.raw() = RawTypeConverter;
  String encode(value, String? type, {String? connectionName});
  Object decode(String value, int pgType, {String? connectionName});
}

class ConnectionState {
  final String _name;
  const ConnectionState(this._name);
  @override
  String toString() => _name;
  static const ConnectionState notConnected = ConnectionState('notConnected');
  static const ConnectionState socketConnected =
      ConnectionState('socketConnected');
  static const ConnectionState authenticating =
      ConnectionState('authenticating');
  static const ConnectionState authenticated = ConnectionState('authenticated');
  static const ConnectionState idle = ConnectionState('idle');
  static const ConnectionState busy = ConnectionState('busy');
  static const ConnectionState streaming = ConnectionState('streaming');
  static const ConnectionState closed = ConnectionState('closed');
}

class TransactionState {
  final String _name;

  const TransactionState(this._name);

  @override
  String toString() => _name;
  static const TransactionState unknown = TransactionState('unknown');
  static const TransactionState none = TransactionState('none');
  static const TransactionState begun = TransactionState('begun');
  static const TransactionState error = TransactionState('error');
}

class Isolation {
  final String _name;
  const Isolation(this._name);

  @override
  String toString() => _name;

  static const Isolation readCommitted = Isolation('readCommitted');
  static const Isolation repeatableRead = Isolation('repeatableRead');
  static const Isolation serializable = Isolation('serializable');
}

class PostgresqlException implements Exception {
  PostgresqlException(this.message, this.connectionName,
      {this.serverMessage, this.exception});
  final String message;
  final String? connectionName;
  final ServerMessage? serverMessage;
  final Object? exception;
  @override
  String toString() {
    if (serverMessage != null) return serverMessage.toString();

    final buf = StringBuffer(message);
    if (exception != null) {
      buf
        ..write(' (')
        ..write(exception)
        ..write(')');
    }
    if (connectionName != null) {
      buf
        ..write(' #')
        ..write(connectionName);
    }
    return buf.toString();
  }
}

abstract class Settings {
  static const int defaultPort = 5432;
  factory Settings(
      String host, int port, String user, String password, String database,
      {bool requireSsl}) = SettingsImpl;

  factory Settings.fromUri(String uri) = SettingsImpl.fromUri;
  String get host;
  int get port;
  String get user;
  String get password;
  String get database;
  bool get requireSsl;
  String toUri();
}
