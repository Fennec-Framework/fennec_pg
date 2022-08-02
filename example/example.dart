import 'package:fennec_pg/fennec_pg.dart';
import 'package:fennec_pg/src/orm/filter/field.dart';
import 'package:fennec_pg/src/prodecure_parameters.dart';

import 'models/user.dart';
import 'repositories/repository.dart';

void main(List<String> arguments) async {
  var uri = 'postgres://postgres:StartAppPassword@localhost:5432/test_flutter';

  await PGConnectionAdapter.initPool(uri);
  UserRepository userRepository = UserRepository();
  TestRepository testRepository = TestRepository();
  PGConnectionAdapter.connection.createProcedure(
      procedureName: 'test',
      parameters: [
        ProcedureParameters(name: 'a', columnType: ColumnType.smallInt)
      ],
      out: ProcedureParameters(name: 'b', columnType: ColumnType.smallInt),
      body: 'select (*) from users into b;');

  final v = PGConnectionAdapter.connection
      .callProcedure(procedureName: 'test', parameters: [
    ProcedureCallParameters(
        name: 'a', value: 1002, columnType: ColumnType.smallInt),
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
  final result = await testRepository.insert(test);

  final x = await testRepository.findOneById('1659308470161');

  if (x != null) {
    x.x = {'1': 3322};

    final y = await testRepository.updateOneById(x.test, x);
    print(y!.toJson());
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
