import 'package:fennec_pg/fennec_pg.dart';

import 'package:fennec_pg/src/prodecure_parameters.dart';

import 'models/user.dart';
import 'repositories/repository.dart';

void main(List<String> arguments) async {
  var uri = 'postgres://postgres:StartAppPassword@localhost:5432/test-db';

  await PGConnectionAdapter.initPool(uri);

  TestRepository testRepository = TestRepository();
  /* PGConnectionAdapter.connection.createFunction(
      functionName: 'test3',
      parameters: [
        ProcedureParameters(name: 'a', columnType: ColumnType.json),
        ProcedureParameters(name: 'b', columnType: ColumnType.smallInt)
      ],
      body: 'return query( select * from users);',
      returned: 'setof users');

  final v = PGConnectionAdapter.connection
      .callFunction(functionName: 'test3', parameters: [
    ProcedureCallParameters(
        name: 'a', value: {'aa': 122}, columnType: ColumnType.json),
    ProcedureCallParameters(
        name: 'b', value: 1002, columnType: ColumnType.smallInt)
  ]);
  var s = await v.toList();
  print(s.length);
  for (int i = 0; i < s.length; i++) {
    print(s[i].toMap());
  }
  s.map((e) {
    print(e.toMap());
  });
  /*User user = User();
  user.email = '131@web.de';
  user.userName = 'ak1';
  user.password = '123456';

  var userResult = await userRepository.selectAll(SelectBuilder(['*'])
    ..where(Equals(Field.tableColumn('email'), Field.string('12@web.de'))
        .or(Equals(Field.tableColumn('id'), Field.int(1)))
        .and(In(Field.tableColumn('id'), Field.list([1, 2])))));
  print(userResult);*/
  Test test = Test(DateTime.now().millisecondsSinceEpoch.toString());
  Child child = Child();
  test.x = {'Akran': true, 'Chorfi': 'aaa'};
  test.childs.add(child);
  test.childs.add(Child());

  final x = await testRepository.findOneById('1659308470161');

  if (x != null) {
    x.x = {'1': 3322};

    final y = await testRepository.updateOneById(x.test, x);
    print(y!.toJson());
  }*/

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
  UserRepository userRepository = UserRepository();
  User user2 = User();
  user2.id = 4;
  user2.password = '111';
  user2.email = '1234';
  user2.userName = '123456';
  User user1 = User();
  user1.id = 1;
  user1.password = '11';
  user1.email = '123';
  user1.userName = '12345';
  User user = User();
  user.email = '111';
  user.password = 'awdsd';
  user.userName = 'aadsD';
  user.account1 = [Account()];
  print(await userRepository.insert(user));
  AccountRepository accountRepository = AccountRepository();
  Account account = Account();
  account.user1 = user1;
  account.user2 = user2;
  //print(await accountRepository.insert(account));
  final x = await accountRepository.findOneById(3);

  final result = await accountRepository
      .findAll(limit: 10, offset: 0, sorts: {'id': OrderBy.ASC});
  for (var row in result) {
    // await accountRepository.updateOneById(row.id!, row);
  }
  await accountRepository.updateAll(result);
}
