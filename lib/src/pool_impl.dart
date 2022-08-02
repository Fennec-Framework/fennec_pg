import 'dart:async';
import 'dart:collection';

import 'dart:math';

import 'package:fennec_pg/src/prodecure_parameters.dart';

import 'connection.dart';
import 'constants.dart';
import 'core/fennec_pg.dart';
import 'core/pool.dart';

const connecting = PooledConnectionState.connecting,
    available = PooledConnectionState.available,
    reserved = PooledConnectionState.reserved,
    testing = PooledConnectionState.testing,
    inUse = PooledConnectionState.inUse,
    connClosed = PooledConnectionState.closed;

typedef ConnectionFactory = Future<Connection> Function(String uri,
    {Duration? connectionTimeout,
    String? applicationName,
    String? timeZone,
    TypeConverter? typeConverter,
    String? debugName});

class ConnectionDecorator implements Connection, ConnectionOwner {
  ConnectionDecorator(this._pool, PooledConnectionImpl pconn, Connection conn)
      : _pconn = pconn,
        _conn = conn {
    if (conn is ConnectionImpl) conn.owner = this;
  }

  _error(fnName) => PostgresqlException(
      '$fnName() called on closed connection.', _pconn.name);

  bool _isReleased = false;
  final Connection _conn;
  final PoolImpl _pool;
  final PooledConnectionImpl _pconn;

  @override
  void close() {
    if (_release()) _pool._releaseConnection(_pconn);
  }

  @override
  void destroy() {
    if (_release()) _pool._destroyConnection(_pconn);
  }

  ///Returns false if it was released before.
  bool _release() {
    if (_isReleased) return false;

    final conn = _conn;
    if (conn is ConnectionImpl) conn.owner = _pconn; //restore it
    return _isReleased = true;
  }

  @override
  Stream<IRow> query(String sql, [values]) {
    if (_isReleased) throw _error('query');
    _pool.settings.onQuery?.call(sql, values);
    return _conn.query(sql, values);
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
      sql += out.name + ' ' + ' OUT ' + out.columnType.name + ')\n';
    } else {
      sql += out.name + ' ' + ' OUT ' + out.columnType.name + ',\n';
    }
    for (int i = 0; i < parameters.length; i++) {
      if (i < parameters.length - 1) {
        sql += parameters[i].name +
            ' ' +
            ' IN ' +
            parameters[i].columnType.name +
            ',\n';
      } else {
        sql += parameters[i].name +
            ' ' +
            ' IN ' +
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
  Future<int> execute(String sql, [values]) {
    if (_isReleased) throw _error('execute');
    _pool.settings.onExecute?.call(sql, values);
    return _conn.execute(sql, values);
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation,
          [Isolation isolation = Isolation.readCommitted]) =>
      _isReleased
          ? throw throw _error('runInTransaction')
          : _conn.runInTransaction(operation, isolation);

  @override
  ConnectionState get state =>
      _isReleased ? ConnectionState.closed : _conn.state;

  @override
  TransactionState get transactionState =>
      _isReleased ? TransactionState.unknown : _conn.transactionState;

  @override
  Stream<Message> get messages =>
      _isReleased ? Stream.fromIterable([]) : _conn.messages;

  @override
  Map<String, String> get parameters => _isReleased ? {} : _conn.parameters;

  @override
  int? get backendPid => _conn.backendPid;

  @override
  String toString() => "$_pconn";
}

class PooledConnectionImpl implements PooledConnection, ConnectionOwner {
  PooledConnectionImpl(this._pool);

  final PoolImpl _pool;
  Connection? _connection;
  PooledConnectionState? _state;
  DateTime? _established;
  DateTime? _obtained;
  DateTime? _released;
  int? _useId;
  bool _isLeaked = false;
  StackTrace? _stackTrace;

  final _extraLifetime = Duration(milliseconds: _random.nextInt(20 * 1000));

  @override
  PooledConnectionState? get state => _state;

  @override
  DateTime? get established => _established;

  @override
  DateTime? get obtained => _obtained;

  @override
  DateTime? get released => _released;

  @override
  int? get backendPid => _connection?.backendPid;

  @override
  int? get useId => _useId;

  @override
  bool get isLeaked => _isLeaked;

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  ConnectionState? get connectionState => _connection?.state;

  @override
  String get name =>
      '${_pool.settings.poolName}:$backendPid' +
      (_useId == null ? '' : ':$_useId');

  @override
  void destroy() {
    _pool._destroyConnection(this);
  }

  @override
  String toString() => '$name:$_state:$connectionState';
}

class PoolImpl implements Pool {
  PoolImpl(this.settings, this._typeConverter,
      [this._connectionFactory = ConnectionImpl.connect]);

  PoolState _state = PoolState.initial;
  @override
  PoolState get state => _state;

  final PoolSettings settings;
  final TypeConverter? _typeConverter;
  final ConnectionFactory _connectionFactory;

  final _waitQueue = <Waiting>[];

  Timer? _heartbeatTimer;
  late Duration _heartbeatDuration;
  Future? _stopFuture;

  final _messages = StreamController<Message>.broadcast();
  final _connections = <PooledConnectionImpl>[];

  List<PooledConnectionImpl>? _connectionsView;

  @override
  List<PooledConnectionImpl> get connections =>
      _connectionsView ??
      (_connectionsView = UnmodifiableListView(_connections));

  @override
  int get pooledConnectionCount => _connections.length;
  @override
  int get busyConnectionCount {
    int count = 0;
    for (final conn in _connections) {
      if (conn._state == inUse) ++count;
    }
    return count;
  }

  @override
  int get maxConnectionCount => _maxConnCnt;
  int _maxConnCnt = 0;

  @override
  int get waitQueueLength => _waitQueue.length;

  @override
  Stream<Message> get messages => _messages.stream;

  @override
  Future start() async {
    if (_state != PoolState.initial) {
      throw PostgresqlException(
          'Cannot start connection pool while in state: $_state.', null);
    }

    var stopwatch = Stopwatch()..start();

    FutureOr<List<dynamic>> onTimeout() {
      _state = PoolState.startFailed;
      throw PostgresqlException(
          'Connection pool start timed out with: '
          '${settings.startTimeout}).',
          null);
    }

    _state = PoolState.starting;

    // Start connections in parallel.
    var futures = Iterable.generate(
        settings.minConnections, (i) => _establishConnection());
    //don't call ...Safely so exception will be sent to caller

    await Future.wait(futures)
        .timeout(settings.startTimeout, onTimeout: onTimeout);

    // If something bad happened and there are not enough connecitons.
    while (_connections.length < settings.minConnections) {
      await _establishConnection().timeout(
          settings.startTimeout - stopwatch.elapsed,
          onTimeout: onTimeout);
    }

    _state = PoolState.running;

    //heartbeat is used to detect leak and destroy idle connection
    final leakDetectionThreshold = settings.leakDetectionThreshold,
        leakMilliseconds = leakDetectionThreshold != null
            ? max(1000, leakDetectionThreshold.inMilliseconds ~/ 3)
            : 500 * 60 * 1000; //bigger than possible [idleTimeout]
    var hbMilliseconds = min(
        leakMilliseconds, max(60000, settings.idleTimeout.inMilliseconds ~/ 3));
    if (settings.limitConnections > 0) {
      hbMilliseconds = min(60000, hbMilliseconds);
    }
    _heartbeatDuration = Duration(milliseconds: hbMilliseconds);
    _heartbeat();
  }

  Future _establishConnection() async {
    if (!(_state == PoolState.running || _state == PoolState.starting)) return;

    if (_connections.length >= settings.maxConnections) return;

    var pconn = PooledConnectionImpl(this);
    pconn._state = connecting;
    _connections.add(pconn);
    if (_connections.length > _maxConnCnt) {
      _maxConnCnt = _connections.length;
      settings.onMaxConnection?.call(_maxConnCnt);
    }

    try {
      var conn = await _connectionFactory(settings.databaseUri,
          connectionTimeout: settings.establishTimeout,
          applicationName: settings.applicationName,
          timeZone: settings.timeZone,
          typeConverter: _typeConverter,
          debugName: pconn.name);
      if (conn is ConnectionImpl) conn.owner = pconn;
      conn.messages.listen((msg) => _messages.add(msg),
          onError: (msg) => _messages.addError(msg));

      pconn._connection = conn;
      pconn._established = DateTime.now();
      pconn._state = available;
    } catch (_) {
      _connections.remove(pconn);
      rethrow;
    }
  }

  Future _establishConnectionSafely() async {
    for (DateTime? since;;) {
      try {
        return _establishConnection();
      } catch (ex) {
        final now = DateTime.now();
        if (since == null) {
          since = now;
          _messages.add(ClientMessage(
              severity: 'WARNING',
              message: "Failed to establish connection",
              exception: ex));
        } else if (now.difference(since) >= settings.connectionTimeout) {
          return ex;
        }

        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void _heartbeat() {
    if (_state != PoolState.running) return;

    try {
      if (settings.leakDetectionThreshold != null) {
        _forEachConnection(_checkIfLeaked);
      }

      for (int i = _connections.length;
          _connections.length > settings.minConnections && --i >= 0;) {
        _checkIdleTimeout(_connections[i], i);
      }
      _processWaitQueue();

      _checkIfAllConnectionsLeaked();
    } finally {
      _heartbeatTimer = Timer(_heartbeatDuration, _heartbeat);
    }
  }

  void _checkIdleTimeout(PooledConnectionImpl pconn, int i) {
    if (pconn._state == available &&
        (_isExpired(
                pconn._released ?? pconn._established!, settings.idleTimeout) ||
            (settings.limitConnections > 0 &&
                _connections.length > settings.limitConnections))) {
      _destroyConnection(pconn, i);
    }
  }

  void _checkIfLeaked(PooledConnectionImpl pconn, int i) {
    if (!pconn._isLeaked &&
        pconn._state != available &&
        pconn._obtained != null &&
        _isExpired(pconn._obtained!, settings.leakDetectionThreshold!)) {
      pconn._isLeaked = true;
      _messages.add(ClientMessage(
          severity: 'WARNING',
          connectionName: pconn.name,
          message: 'Leak detected. '
              'state: ${pconn._connection?.state} '
              'transactionState: ${pconn._connection?.transactionState} '
              'stacktrace: ${pconn._stackTrace}'));
    }
  }

  int get _leakedConnections => _connections.where((c) => c._isLeaked).length;

  void _checkIfAllConnectionsLeaked() {
    if (settings.restartIfAllConnectionsLeaked &&
        _leakedConnections >= settings.maxConnections) {
      _messages.add(ClientMessage(
          severity: 'WARNING',
          message: '${settings.poolName} is full of leaked connections. '
              'These will be closed and new connections started.'));

      _forEachConnection(_destroyConnection);

      for (int i = 0; i < settings.minConnections; i++) {
        _establishConnectionSafely();
      }
    }
  }

  static int _sequence = 1;

  @override
  Future<Connection> connect() async {
    if (_state != PoolState.running) {
      throw PostgresqlException(
          'Connect called while pool is not running.', null,
          exception: pePoolStopped);
    }

    StackTrace? stackTrace;
    if (settings.leakDetectionThreshold != null) {
      stackTrace = StackTrace.current;
    }

    var pconn = await _connect(settings.connectionTimeout);

    assert((settings.testConnections && pconn._state == testing) ||
        (!settings.testConnections && pconn._state == reserved));
    assert(pconn._connection!.state == ConnectionState.idle);
    assert(pconn._connection!.transactionState == TransactionState.none);

    pconn
      .._state = inUse
      .._obtained = DateTime.now()
      .._useId = _sequence++
      .._stackTrace = stackTrace;

    return ConnectionDecorator(this, pconn, pconn._connection!);
  }

  Future<PooledConnectionImpl> _connect(Duration timeout) async {
    if (state == PoolState.stopping || state == PoolState.stopped) {
      throw PostgresqlException('Connect failed as pool is stopping.', null,
          exception: pePoolStopped);
    }

    var stopwatch = Stopwatch()..start();

    var pconn = _getNextAvailable();

    timeoutException() => PostgresqlException(
        'Obtaining connection from pool exceeded timeout: '
        '${settings.connectionTimeout}.\nAlive connections: ${_connections.length}',
        pconn?.name,
        exception: peConnectionTimeout);
    if (pconn == null) {
      final waiting = Waiting(settings.limitConnections > 0 &&
          settings.limitConnections <= _waitQueue.length + connections.length);

      _waitQueue.add(waiting);
      try {
        _processWaitQueue();
        pconn = await waiting.c.future
            .timeout(timeout, onTimeout: () => throw timeoutException());
      } finally {
        _waitQueue.remove(waiting);
      }
      assert(pconn.state == reserved);
    }

    if (!settings.testConnections) {
      pconn._state = reserved;
      return pconn;
    }

    pconn._state = testing;

    if (await _testConnection(
        pconn, timeout - stopwatch.elapsed, () => throw timeoutException())) {
      return pconn;
    }

    if (timeout > stopwatch.elapsed) {
      throw timeoutException();
    } else {
      _destroyConnection(pconn);

      return _connect(timeout - stopwatch.elapsed);
    }
  }

  PooledConnectionImpl? _getNextAvailable() {
    for (final pconn in _connections) {
      if (pconn._state == available) return pconn;
    }
    return null;
  }

  void _processWaitQueue([_]) {
    if (_state != PoolState.running || _waitQueue.isEmpty) return;
    for (int i = 0; _waitQueue.isNotEmpty && i < _connections.length; ++i) {
      var pconn = _connections[i];
      if (pconn._state == available) {
        final waiting = _waitQueue.removeAt(0);
        pconn._state = reserved;
        waiting.c.complete(pconn);
      }
    }

    if (_establishing) return; //once at a time

    final count = _countToEstablish();
    if (count <= 0) return;

    _establishing = true;
    _establishForWaitQueue(count).whenComplete(() {
      _establishing = false;
      _processWaitQueue();
    });
  }

  Future _establishForWaitQueue(int count) async {
    assert(count > 0);
    assert(_establishing);

    final ops = <Future>[];
    while (--count >= 0) {
      ops.add(_establishConnectionSafely());
    }

    final results = await Future.wait(ops);
    for (final r in results) {
      if (r != null) {
        _processWaitQueue();

        final ex = PostgresqlException('Failed to establish connection', null,
            exception: peConnectionFailed);
        while (_waitQueue.isNotEmpty) {
          _waitQueue.removeAt(0).c.completeError(ex);
        }
        break; //done
      }
    }
  }

  bool _establishing = false;

  /// Returns the number of connections to establish
  int _countToEstablish() {
    final maxc = settings.maxConnections - _connections.length;
    var count = min(_waitQueue.length, maxc);
    if (count > 0 && settings.limitConnections > 0) {
      count = min(count, settings.limitConnections - connections.length);
      if (count <= 0) {
        final ref = DateTime.now().subtract(settings.limitTimeout);
        Duration? duration;
        count = 0;
        for (final waiting in _waitQueue) {
          final at = waiting.at;
          if (at != null) {
            duration = at.difference(ref);
            if (duration > Duration.zero) break;
          }
          if (++count >= maxc) break;
        }

        if (count == 0 && _tmProcessAgain == null) {
          _tmProcessAgain = Timer(duration!, () {
            _tmProcessAgain = null;
            _processWaitQueue();
          });
        }
      }
    }
    return count;
  }

  Timer? _tmProcessAgain;
  Future<bool> _testConnection(
      PooledConnectionImpl pconn, Duration timeout, Function onTimeout) async {
    bool ok;
    try {
      var row =
          await pconn._connection!.query('select true').single.timeout(timeout);
      ok = row[0];
    } catch (ex) {
      ok = false;

      if (state != PoolState.stopping && state != PoolState.stopped) {
        var msg = ex is TimeoutException
            ? 'Connection test timed out.'
            : 'Connection test failed.';
        _messages.add(ClientMessage(
            severity: 'WARNING',
            connectionName: pconn.name,
            message: msg,
            exception: ex));
      }
    }
    return ok;
  }

  void _releaseConnection(PooledConnectionImpl pconn) {
    if (state == PoolState.stopping || state == PoolState.stopped) {
      _destroyConnection(pconn);
      return;
    }

    assert(pconn._pool == this);
    assert(_connections.contains(pconn));
    assert(pconn.state == inUse);

    final conn = pconn._connection!;
    if (conn.state != ConnectionState.idle ||
        conn.transactionState != TransactionState.none) {
      _messages.add(ClientMessage(
          severity: 'WARNING',
          connectionName: pconn.name,
          message: 'Connection returned in bad state. Removing from pool. '
              'state: ${conn.state} '
              'transactionState: ${conn.transactionState}.'));

      _destroyConnection(pconn);
      _establishConnectionSafely().then(_processWaitQueue);
    } else if (_isExpired(
        pconn._established!, settings.maxLifetime + pconn._extraLifetime)) {
      _destroyConnection(pconn);
      _establishConnectionSafely().then(_processWaitQueue);
    } else {
      pconn._released = DateTime.now();
      pconn._state = available;
      _processWaitQueue();
    }
  }

  bool _isExpired(DateTime time, Duration timeout) =>
      DateTime.now().difference(time) > timeout;

  void _destroyConnection(PooledConnectionImpl pconn, [int? i]) {
    pconn._connection?.close();
    pconn._state = connClosed;

    if (i != null && pconn == _connections[i]) {
      _connections.removeAt(i);
    } else {
      for (int i = _connections.length; --i >= 0;) {
        if (pconn == _connections[i]) {
          _connections.removeAt(i);
          break;
        }
      }
    }
  }

  @override
  Future stop() {
    if (state == PoolState.stopped || state == PoolState.initial) {
      return Future.value();
    }

    assert(_stopFuture == null || state == PoolState.stopping);
    return _stopFuture ?? (_stopFuture = _stop());
  }

  Future _stop() async {
    _state = PoolState.stopping;

    _heartbeatTimer?.cancel();

    final ex = PostgresqlException('Connection pool is stopping.', null,
        exception: pePoolStopped);
    while (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).c.completeError(ex);
    }

    var stopwatch = Stopwatch()..start();
    while (_connections.isNotEmpty) {
      _forEachConnection((pconn, i) {
        if (pconn._state == available) _destroyConnection(pconn, i);
      });

      await Future.delayed(Duration(milliseconds: 100), () => null);

      if (stopwatch.elapsed > settings.stopTimeout) {
        _messages.add(ClientMessage(
            severity: 'WARNING',
            message: 'Exceeded timeout while stopping pool, '
                'closing in use connections.'));
        // _destroyConnection modifies this list, so need to make a copy.
        _forEachConnection(_destroyConnection);
      }
    }
    _state = PoolState.stopped;
  }

  void _forEachConnection(Function(PooledConnectionImpl pconn, int i) f) {
    for (int i = _connections.length; --i >= 0;) {
      f(_connections[i], i);
    }
  }
}

class Waiting {
  final Completer<PooledConnectionImpl> c;
  DateTime? at;
  Waiting(bool runOut) : c = Completer<PooledConnectionImpl>() {
    if (runOut) at = DateTime.now();
  }

  @override
  int get hashCode => c.hashCode;
  @override
  bool operator ==(other) => other is Waiting && other.c == c;
}

final _random = Random();
