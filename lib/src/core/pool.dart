import '../pool_impl.dart';
import '../pool_settings_impl.dart';
import 'fennec_pg.dart';

abstract class Pool {
  /// See [PoolSettings] for a description of settings.
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

  /// Number of the pooled connections.
  int get pooledConnectionCount;

  /// Number of busy connections.
  int get busyConnectionCount;

  /// The maximal number of concurrent connections that are ever made
  /// since started.
  int get maxConnectionCount;
}

/// Store settings for a PostgreSQL connection pool.
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

  /// Pool name is used in log messages. It is helpful if there are multiple
  /// connection pools. Defaults to pgpoolX.
  String get poolName;

  /// Minimum number of connections. When the pool is started
  /// this is the number of connections that will initially be started. The pool
  /// will ensure that this number of connections is always running. In typical
  /// production settings, this should be set to be the same size as
  /// maxConnections. Defaults to 5.
  int get minConnections;

  /// Maximum number of connections. The pool will not exceed
  /// this number of database connections. Defaults to 10.
  int get maxConnections;

  /// A soft limit to keep the number of connections below it.
  /// If number of connections exceeds [limitConnections],
  /// they'll be removed from the pool as soon as possible
  /// (about a minute after released).
  ///
  /// In additions, we'll slow down the estbalishing of new connections.
  /// by waiting up to [limitTimeout], if there are more than
  /// [limitConnections] connections.
  ///
  /// It helps to reduce number of connections if there are a lot of
  /// short-lived connections.
  ///
  /// It can still run up to [maxConnections] if no connections are
  /// released before the timeout
  ///
  /// Ignored if not a positive number. Defaults to 0.
  int get limitConnections;

  /// Callback when detecting the number of DB connections is larger
  /// then the previous maximal number.
  void Function(int count)? get onMaxConnection;

  /// Callback when [Connection.execute] is called.
  /// It is useful for detecting unexpected pattern.
  /// For example, `update A set f=null where k=k` is usually an error
  /// that `@k` shall be used instead. And, it can cause a disaster.
  void Function(String sql, dynamic values)? get onExecute;

  /// Callback when [Connection.query] is called.
  /// It is useful for detecting unexpected pattern, such as a SQL pattern
  /// that can perform badly.
  void Function(String sql, dynamic values)? get onQuery;

  /// If the pool cannot start within this time then return an
  /// error. Defaults to 30 seconds.
  Duration get startTimeout;

  /// If when stopping connections are not returned to the pool
  /// within this time, then they will be forefully closed. Defaults to 30
  /// seconds.
  Duration get stopTimeout;

  /// When the pool wants to establish a new database
  /// connection and it is not possible to complete within this time then a
  /// warning will be logged. Defaults to 30 seconds.
  Duration get establishTimeout;

  /// When client code calls Pool.connect(), and a
  /// connection does not become available within this time, an error is
  /// returned. Defaults to 30 seconds.
  Duration get connectionTimeout;

  /// If a connection has not been used for this ammount of time
  /// and there are more than the minimum number of connections in the pool,
  /// then this connection will be closed. Defaults to 10 minutes.
  Duration get idleTimeout;

  /// If the number of connections is more than [limitConnections],
  /// the establishing of new connections will be slowed down by
  /// waiting the duration specified in [limitTimeout]. Default: 700ms.
  ///
  /// > Note: it is ignored if [limitConnections] is zero or negative.
  Duration get limitTimeout;

  /// At the time that a connection is released, if it is older
  /// than this time it will be closed. Defaults to 30 minutes.
  Duration get maxLifetime;

  /// If a connection is not returned to the pool
  /// within this time after being obtained by pool.connect(), the a warning
  /// message will be logged. Defaults to null, off by default. This setting is
  /// useful for tracking down code which leaks connections by forgetting to
  /// call Connection.close() on them.
  Duration? get leakDetectionThreshold;

  /// Perform a simple query to check if a connection is
  /// still valid before returning a connection from pool.connect(). Default is
  /// false.
  bool get testConnections;

  /// Once the entire pool is full of leaked
  /// connections, close them all and restart the minimum number of connections.
  /// Defaults to false. This must be used in combination with the leak
  /// detection threshold setting.
  bool get restartIfAllConnectionsLeaked;

  /// The application name is displayed in the pg_stat_activity view.
  String? get applicationName;

  /// Care is required when setting the time zone, this is generally not required,
  /// the default, if omitted, is to use the server provided default which will
  /// typically be localtime or sometimes UTC. Setting the time zone to UTC will
  /// override the server provided default and all [DateTime] objects will be
  /// returned in UTC. In the case where the application server is on a different
  /// host than the database, and the host's [DateTime]s should be in the host's
  /// localtime, then set this to the host's local time zone name. On linux
  /// systems this can be obtained using:
  ///
  ///     new File('/etc/timezone').readAsStringSync().trim()
  ///
  String? get timeZone;
}

//TODO change to enum once implemented.
class PoolState {
  const PoolState(this.name);
  final String name;

  @override
  String toString() => name;

  static const PoolState initial = const PoolState('inital');
  static const PoolState starting = const PoolState('starting');
  static const PoolState startFailed = const PoolState('startFailed');
  static const PoolState running = const PoolState('running');
  static const PoolState stopping = const PoolState('stopping');
  static const PoolState stopped = const PoolState('stopped');
}

abstract class PooledConnection {
  /// The state of connection in the pool: available, closed, etc.
  PooledConnectionState? get state;

  /// Time at which the physical connection to the database was established.
  DateTime? get established;

  /// Time at which the connection was last obtained by a client.
  DateTime? get obtained;

  /// Time at which the connection was last released by a client.
  DateTime? get released;

  /// The pid of the postgresql handler.
  int? get backendPid;

  /// A unique id that updated whenever the connection is obtained.
  int? get useId;

  /// If a leak detection threshold is set, then this flag will be set on leaked
  /// connections.
  bool get isLeaked;

  /// The stacktrace at the time pool.connect() was last called.
  StackTrace? get stackTrace;

  ConnectionState? get connectionState;

  String get name;
}

//TODO change to enum once implemented.
class PooledConnectionState {
  const PooledConnectionState(this.name);
  final String name;

  @override
  String toString() => name;

  static const PooledConnectionState connecting =
      PooledConnectionState('connecting');
  static const PooledConnectionState available =
      PooledConnectionState('available');
  static const PooledConnectionState reserved =
      PooledConnectionState('reserved');
  static const PooledConnectionState testing =
      const PooledConnectionState('testing');
  static const PooledConnectionState inUse =
      const PooledConnectionState('inUse');
  static const PooledConnectionState closed =
      const PooledConnectionState('closed');
}
