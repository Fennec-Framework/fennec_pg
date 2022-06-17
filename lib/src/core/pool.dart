import '../pool_impl.dart';
import '../pool_settings_impl.dart';
import 'fennec_pg.dart';

abstract class Pool {
  factory Pool(String databaseUri,
          {String? poolName,
          int? minConnections,
          int? maxConnections,
          int? limitConnections,
          void Function(int count)? onMaxConnection,
          void Function(String sql, dynamic values)? onExecute,
          void Function(String sql, dynamic values)? onQuery,
          Duration? startTimeout,
          Duration? stopTimeout,
          Duration? establishTimeout,
          Duration? connectionTimeout,
          Duration? idleTimeout,
          Duration? limitTimeout,
          Duration? maxLifetime,
          Duration? leakDetectionThreshold,
          bool? testConnections,
          bool? restartIfAllConnectionsLeaked,
          String? applicationName,
          String? timeZone,
          TypeConverter? typeConverter}) =>
      PoolImpl(
          PoolSettingsImpl.copyWith(
              databaseUri: databaseUri,
              poolName: poolName,
              minConnections: minConnections,
              maxConnections: maxConnections,
              limitConnections: limitConnections,
              onMaxConnection: onMaxConnection,
              onExecute: onExecute,
              onQuery: onQuery,
              startTimeout: startTimeout,
              stopTimeout: stopTimeout,
              establishTimeout: establishTimeout,
              connectionTimeout: connectionTimeout,
              idleTimeout: idleTimeout,
              limitTimeout: limitTimeout,
              maxLifetime: maxLifetime,
              leakDetectionThreshold: leakDetectionThreshold,
              testConnections: testConnections,
              restartIfAllConnectionsLeaked: restartIfAllConnectionsLeaked,
              applicationName: applicationName,
              timeZone: timeZone),
          typeConverter);

  factory Pool.fromSettings(PoolSettings settings,
          {TypeConverter? typeConverter}) =>
      PoolImpl(settings, typeConverter);

  Future start();
  Future stop();
  Future<Connection> connect();
  PoolState get state;
  Stream<Message> get messages;
  List<PooledConnection> get connections;
  int get waitQueueLength;
  int get pooledConnectionCount;

  int get busyConnectionCount;

  int get maxConnectionCount;
}

abstract class PoolSettings {
  factory PoolSettings(
      {required String databaseUri,
      String poolName,
      int minConnections,
      int maxConnections,
      int limitConnections,
      void Function(int count)? onMaxConnection,
      void Function(String sql, dynamic values)? onExecute,
      void Function(String sql, dynamic values)? onQuery,
      Duration startTimeout,
      Duration stopTimeout,
      Duration establishTimeout,
      Duration connectionTimeout,
      Duration idleTimeout,
      Duration limitTimeout,
      Duration maxLifetime,
      Duration? leakDetectionThreshold,
      bool testConnections,
      bool restartIfAllConnectionsLeaked,
      String? applicationName,
      String? timeZone}) = PoolSettingsImpl;

  String get databaseUri;
  String get poolName;
  int get minConnections;
  int get maxConnections;
  int get limitConnections;
  void Function(int count)? get onMaxConnection;
  void Function(String sql, dynamic values)? get onExecute;
  void Function(String sql, dynamic values)? get onQuery;

  Duration get startTimeout;

  Duration get stopTimeout;

  Duration get establishTimeout;

  Duration get connectionTimeout;

  Duration get idleTimeout;

  Duration get limitTimeout;

  Duration get maxLifetime;

  Duration? get leakDetectionThreshold;

  bool get testConnections;

  bool get restartIfAllConnectionsLeaked;

  String? get applicationName;

  String? get timeZone;
}

enum PoolState { initial, starting, startFailed, running, stopping, stopped }

abstract class PooledConnection {
  PooledConnectionState? get state;

  DateTime? get established;

  DateTime? get obtained;

  DateTime? get released;

  int? get backendPid;

  int? get useId;

  bool get isLeaked;

  StackTrace? get stackTrace;

  ConnectionState? get connectionState;

  String get name;
}

enum PooledConnectionState {
  connecting,
  available,
  reserved,
  testing,
  inUse,
  closed
}
