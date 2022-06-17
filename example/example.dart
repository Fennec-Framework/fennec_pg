import 'package:fennec_pg/fennec_pg.dart';

import 'models/user.dart';
import 'repositories/repository.dart';

void main(List<String> arguments) async {
  var uri = 'postgres://user:password@localhost:5432/db-name';
  await PGConnectionAdapter.init(uri);
  final result = await PGConnectionAdapter.connection
      .query('select * from users')
      .toList();

  for (var row in result) {
    print(row.toMap());
  }
  /* AccountRepository accountRepository = AccountRepository();
  UserRepository userRepository = UserRepository();
  User user = User();
  user.email = '131@web.de';
  user.name = 'ak1';
  user.account = Account();
  User? userResult = await userRepository.insert(user);
  if (userResult != null) {
    print(userResult.toJson());
  }
  final result = await accountRepository.findAll();
  for (var row in result) {
    print(row.toJson());
  }*/
}
