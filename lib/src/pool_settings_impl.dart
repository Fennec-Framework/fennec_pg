import 'core/fennec_pg.dart';
import 'core/pool.dart';

final PoolSettingsImpl _default = PoolSettingsImpl(databaseUri: '');

class PoolSettingsImpl implements PoolSettings {
  PoolSettingsImpl(
      {required this.databaseUri,
      String? poolName,
      this.minConnections = 1,
      this.maxConnections = 10,
      this.limitConnections = 0,
      this.onMaxConnection,
      this.onExecute,
      this.onQuery,
      this.startTimeout = const Duration(seconds: 30),
      this.stopTimeout = const Duration(seconds: 30),
      this.establishTimeout = const Duration(seconds: 30),
      this.connectionTimeout = const Duration(seconds: 30),
      this.idleTimeout = const Duration(minutes: 10),
      this.limitTimeout = const Duration(milliseconds: 700),
      this.maxLifetime = const Duration(minutes: 30),
      this.leakDetectionThreshold, // Disabled by default.
      this.testConnections = false,
      this.restartIfAllConnectionsLeaked = false,
      this.applicationName,
      this.timeZone})
      : poolName = poolName ?? 'pgpool${_sequence++}';

  factory PoolSettingsImpl.copyWith(
      {required String databaseUri,
      String? poolName,
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
      String? timeZone}) {
    return PoolSettingsImpl(
        databaseUri: databaseUri,
        poolName: poolName,
        minConnections: minConnections ?? _default.minConnections,
        maxConnections: maxConnections ?? _default.maxConnections,
        limitConnections: limitConnections ?? _default.limitConnections,
        onMaxConnection: onMaxConnection,
        onExecute: onExecute,
        onQuery: onQuery,
        startTimeout: startTimeout ?? _default.startTimeout,
        stopTimeout: stopTimeout ?? _default.stopTimeout,
        establishTimeout: establishTimeout ?? _default.establishTimeout,
        connectionTimeout: connectionTimeout ?? _default.connectionTimeout,
        idleTimeout: idleTimeout ?? _default.idleTimeout,
        limitTimeout: limitTimeout ?? _default.limitTimeout,
        maxLifetime: maxLifetime ?? _default.maxLifetime,
        leakDetectionThreshold:
            leakDetectionThreshold ?? _default.leakDetectionThreshold,
        testConnections: testConnections ?? _default.testConnections,
        restartIfAllConnectionsLeaked: restartIfAllConnectionsLeaked ??
            _default.restartIfAllConnectionsLeaked,
        applicationName: applicationName,
        timeZone: timeZone);
  }

  // Ids will be unique for this isolate.
  static int _sequence = 0;

  @override
  final String databaseUri;
  @override
  final String poolName;
  @override
  final int minConnections;
  @override
  final int maxConnections;
  @override
  final int limitConnections;
  @override
  final void Function(int count)? onMaxConnection;
  @override
  final void Function(String sql, dynamic values)? onExecute;
  @override
  final void Function(String sql, dynamic values)? onQuery;
  @override
  final Duration startTimeout;
  @override
  final Duration stopTimeout;
  @override
  final Duration establishTimeout;
  @override
  final Duration connectionTimeout;
  @override
  final Duration idleTimeout;
  @override
  final Duration limitTimeout;
  @override
  final Duration maxLifetime;
  @override
  final Duration? leakDetectionThreshold;
  @override
  final bool testConnections;
  @override
  final bool restartIfAllConnectionsLeaked;
  @override
  final String? applicationName;
  @override
  final String? timeZone;

  @override
  String toString() => 'PoolSettings ${Settings.fromUri(databaseUri)}';
}
