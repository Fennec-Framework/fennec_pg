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
  @HasMany(localKey: 'ac1', foreignKey: 'id', fetchType: FetchType.include)
  List<Account> account1 = [];
  @HasMany(localKey: 'ac2', foreignKey: 'id', fetchType: FetchType.include)
  List<Account> account2 = [];

  User();

  User.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    userName = map['user_name'];
    email = map['email'];
    password = map['password'];
  }
}

@Table('tests')
class Test extends Serializable {
  @PrimaryKey(columnType: ColumnType.varChar, autoIncrement: false)
  late String test;
  @Column(type: ColumnType.json)
  Map<String, dynamic> x = {};
  @HasMany(
      fetchType: FetchType.include, localKey: 'test_id', foreignKey: 'test')
  List<Child> childs = [];

  Test(this.test);

  Test.fromJson(Map<String, dynamic> map) {
    test = map['test'];
    x = map['x'];

    if (map['childs'] != null) {
      childs = List.from(map['childs'].map((e) => Child.fromJson(e)));
    }
  }
}

@Table('child')
class Child extends Serializable {
  @PrimaryKey(autoIncrement: true)
  late int? id;

  Child();

  Child.fromJson(Map<String, dynamic> map) {
    id = map['id'];
  }
}

@Table('accounts')
class Account extends Serializable {
  Account();

  @PrimaryKey(autoIncrement: true, columnType: ColumnType.bigInt)
  int? id;
  @BelongsTo(localKey: 'id', foreignKey: 'ac1', fetchType: FetchType.include)
  User? user1;
  @BelongsTo(localKey: 'id', foreignKey: 'ac2', fetchType: FetchType.include)
  User? user2;

  Account.fromJson(Map<String, dynamic> map) {
    id = map['id'];

    if (map['user1'] != null) {
      user1 = User.fromJson(map['user1']);
    }
    if (map['user2'] != null) {
      user2 = User.fromJson(map['user2']);
    }
  }
}
