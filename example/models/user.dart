import 'package:fennec_pg/fennec_pg.dart';

@Table('users')
class User extends Serializable {
  @PrimaryKey(autoIncrement: true, columnType: ColumnType.bigInt)
  int? id;
  @Column(isNullable: false, indexType: IndexType.unique, alias: 'user_name')
  late String userName;
  @Column(isNullable: false, indexType: IndexType.unique)
  late String email;
  @Column(isNullable: false, indexType: IndexType.unique)
  late String password;

  User();
  User.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    userName = map['user_name'];
    email = map['email'];
  }
}

@Table('tests')
class Test extends Serializable {
  @PrimaryKey(columnType: ColumnType.varChar, autoIncrement: false)
  late String test;
  @Column(type: ColumnType.json)
  Map<String, dynamic> x = {};
  Test(this.test);
  Test.fromJson(Map<String, dynamic> map) {
    test = map['test'];
    x = map['x'];
  }
}

@Table('accounts')
class Account extends Serializable {
  Account();
  @PrimaryKey(autoIncrement: true, columnType: ColumnType.bigInt)
  int? id;
  @BelongsTo(
      localKey: 'id', foreignKey: 'user_id', fetchType: FetchType.include)
  User? user;

  Account.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    if (map['user'] != null) {
      user = User.fromJson(map['user']);
    }
  }
}
