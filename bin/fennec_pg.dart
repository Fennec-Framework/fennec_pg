import 'package:fennec_pg/fennec_pg.dart';

import '../example/repositories/repository.dart';

void main(List<String> arguments) async {
  await PGConnectionAdapter.init(
      'postgres://postgres:StartAppPassword@localhost:5432/test_db');
  AccountRepository accountRepository = AccountRepository();
  await accountRepository.findAll();
}
