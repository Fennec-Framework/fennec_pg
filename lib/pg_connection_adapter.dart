import 'package:fennec_pg/src/core/fennec_pg.dart';

class PGConnectionAdapter {
  final String uri;
  PGConnectionAdapter(this.uri);
  static late Connection connection;
  Future init() async {
    connection = await connect(uri);
  }
}
