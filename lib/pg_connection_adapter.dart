import 'package:fennec_pg/src/core/fennec_pg.dart';

class PGConnectionAdapter {
  PGConnectionAdapter();
  static late Connection connection;
  static Future init(final String uri) async {
    connection = await connect(uri);
  }
}
