import 'package:fennec_pg/fennec_pg.dart';

@Table('users')
class User extends Serializable {
  @PrimaryKey(autoIncrement: true, columnType: ColumnType.bigInt)
  int? id;
  @Column(isNullable: false, indexType: IndexType.unique)
  late String name;
  @Column(isNullable: false, indexType: IndexType.unique)
  late String email;
  @HasOne(
      localKey: 'user_id',
      foreignKey: 'id',
      fetchType: FetchType.include,
      cascadeType: CascadeType.delete)
  Account? account;
  User();
  User.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    email = map['email'];
    if (map['account'] != null) {
      account = Account.fromJson(map['account']);
    }
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
