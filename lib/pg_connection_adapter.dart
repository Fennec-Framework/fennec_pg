import 'package:fennec_pg/src/core/fennec_pg.dart';

import 'src/core/pool.dart';

class PGConnectionAdapter {
  PGConnectionAdapter();
  static late Connection connection;
  static Future<void> init(final String uri) async {
    connection = await connect(uri);
  }

  static Future<void> initPool(final String uri,
      {int minConnections = 1, int maxConnections = 5}) async {
    var pool = Pool(uri,
        minConnections: maxConnections, maxConnections: maxConnections);
    pool.messages.listen(print);
    await pool.start();
    connection = await pool.connect();
  }
}
