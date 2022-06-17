**fennec_pg** is dart plugin for connecting to postgresql with orm. it belongs to fennec framework [pub.dev](https://pub.dev/packages/fennec) but it can be used 
separately.


# Installation
install the plugin from [pub.dev](https://pub.dev/packages/fennec_pg)



# supported Feautures

- connect to postgres
- **SelectBuilder** for select operation with where clause etc.
- **FilterBuilder** for filtering searched Data.
- **SelectBuilderWithNestedJsonOutPut** for joins especially if you want related objects as nested json
- **Serializable** for seriable your model dynamically.
- **Repository** an Interface that can be used for create your own repository
- **relations** one to one, one to many , belongs to.


# create models

``` dart
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

```



# create repository

``` dart
class UserRepository extends Repository<User, int> {}
class AccountRepository extends Repository<Account, int> {}

```


# user repository example

  ``` dart
  AccountRepository accountRepository = AccountRepository();
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
  }
  
 
```



# use SelectBuilder with FilterBuilder 

   ``` dart
   
  SelectBuilder selectBuilder = SelectBuilder('Model', ['*']);
  FilterBuilder filterBuilder = FilterBuilder('id', '=', 2);
  filterBuilder.or(FilterBuilder('id', '=', 4));
  selectBuilder.where(filterBuilder);
  final result = await PGConnectionAdapter.connection
      .query(selectBuilder.makeQuery())
      .toList();

  for (var row in result) {
    print(row.toMap());
  }
  
 ```
 
 
 # custom own query
  ``` dart
 
   final result = await PGConnectionAdapter.connection
      .query('select * from users')
      .toList();

  for (var row in result) {
    print(row.toMap());
  }
  
 ```
 
 
 # start the connection with postgres
 
   ``` dart
   
    var uri = 'postgres://user:password@localhost:5432/db-name';
  await PGConnectionAdapter.init(uri);

 ```
 
 # LICENSE

[MIT](https://github.com/Fennec-Framework/fennec_pg/blob/master/LICENSE)
 
 
 
 
