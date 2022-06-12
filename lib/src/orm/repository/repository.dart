// ignore_for_file: unnecessary_string_escapes

import 'dart:convert';
import 'dart:math';
import 'dart:mirrors';

import 'package:fennec_pg/fennec_pg.dart';
import 'package:fennec_pg/src/orm/filter/filter_builder.dart';
import 'package:fennec_pg/src/orm/filter/select_builder.dart';
import 'package:fennec_pg/src/orm/repository/repository_util.dart';

import 'irepository.dart';

abstract class Repository<T, S> implements IRepository<T, S> {
  Repository() {
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    bool existConverter = false;
    Iterable<MapEntry<Symbol, DeclarationMirror>> methods =
        cm.declarations.entries;

    for (var element in methods) {
      if (element.value is MethodMirror &&
          element.key.toString() == 'Symbol("$tablename.fromJson")') {
        existConverter = true;
        break;
      }
    }
    if (!existConverter) {
      throw Exception(
          "you need implement constructor $tablename.fromJson(Map<String,dynamic>)");
    }

    PGConnectionAdapter.connection
        .query(RepositoryUtils.createTableFromObject(T));
  }

  @override
  Future<List<T>> findAll({FilterBuilder? filterBuilder}) async {
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    String join = 'with cte as ( select ' "$tablename" '.*';
    for (var variableMirror in cm.declarations.values) {
      if (variableMirror is VariableMirror) {
        String joinTableName = variableMirror.type.reflectedType.toString();
        String columnName = MirrorSystem.getName(variableMirror.simpleName);
        for (var element in variableMirror.metadata) {
          if (element.reflectee is HasOne) {
            InstanceMirror cm = reflect(element.reflectee);
            String localKey =
                cm.getField(#localKey).reflectee ?? "${tablename}_id";

            String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.left;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp =
                    splitBefore.first + ', $randomName as "$columnName"';
                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $tablename."$foreignKey" = $randomName."$localKey"';
                join = temp;
              } else {
                join +=
                    ', $randomName as "$columnName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $tablename."$foreignKey" = $randomName."$localKey"';
              }
            }
          } else if (element.reflectee is HasMany) {
            ClassMirror classMirror = reflectClass(
                variableMirror.type.typeArguments.first.reflectedType);
            joinTableName = RepositoryUtils.getTableName(classMirror);

            InstanceMirror cm = reflect(element.reflectee);
            String localKey =
                cm.getField(#localKey).reflectee ?? "${tablename}_id";

            String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.left;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp = splitBefore.first +
                    ', array_remove(array_agg($randomName),NULL) as "$columnName"';
                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $tablename."$foreignKey" = $randomName."$localKey" GROUP BY $tablename."$foreignKey" , ${splitBefore.first.split(',').sublist(1).join(',').split('as').first}';
                join = temp;
              } else {
                join +=
                    ',  array_remove(array_agg($randomName),NULL) as "$columnName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $tablename."$foreignKey" = $randomName."$localKey" GROUP BY $tablename."$foreignKey"';
              }
            }
          } else if (element.reflectee is BelongsTo) {
            InstanceMirror cm = reflect(element.reflectee);
            String localKey = cm.getField(#localKey).reflectee ?? "id";

            String foreignKey =
                cm.getField(#foreignKey).reflectee ?? "${tablename}_id";

            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.left;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp =
                    splitBefore.first + ', $tablename as "$columnName"';
                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $randomName."$localKey" = $tablename."$foreignKey"';
                join = temp;
              } else {
                join +=
                    ', $randomName as "$columnName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $randomName."$localKey" = $tablename."$foreignKey"';
              }
            }
          }
        }
      }
    }
    if (!join.contains('from')) {
      join += 'from "$tablename" $tablename';
    }
    if (filterBuilder != null) {
      join += ' where ' + filterBuilder.makeFilterQuery();
    }
    join += ')select row_to_json(c) from cte c;';

    var data = await PGConnectionAdapter.connection.query(join).toList();
    List<T> result = <T>[];
    for (var element in data) {
      InstanceMirror res = cm.newInstance(#fromJson,
          [Map<String, dynamic>.from(element.toMap()['row_to_json'])]);

      result.add(res.reflectee);
    }
    return result;
  }

  @override
  Future<T?> findOneById(S value) async {
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    String primaryKey = RepositoryUtils.getPrimaryKey(cm);
    String join = "with cte as ( select $tablename.*";
    for (var varaiableMirror in cm.declarations.values) {
      String columnName = MirrorSystem.getName(varaiableMirror.simpleName);
      if (varaiableMirror is VariableMirror) {
        String joinTableName = varaiableMirror.type.reflectedType.toString();
        for (var element in varaiableMirror.metadata) {
          if (element.reflectee is HasOne) {
            InstanceMirror cm = reflect(element.reflectee);
            String localKey =
                cm.getField(#localKey).reflectee ?? "${tablename}_id";
            String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.full;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp =
                    splitBefore.first + ', $randomName as "$joinTableName"';

                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $tablename."$foreignKey" = $randomName."$localKey"';
                join = temp;
              } else {
                join +=
                    ', $randomName as "$joinTableName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $tablename."$foreignKey" = $randomName."$localKey"';
              }
            }
          } else if (element.reflectee is HasMany) {
            ClassMirror classMirror = reflectClass(
                varaiableMirror.type.typeArguments.first.reflectedType);
            joinTableName = RepositoryUtils.getTableName(classMirror);

            InstanceMirror cm = reflect(element.reflectee);
            String localKey =
                cm.getField(#localKey).reflectee ?? "${tablename}_id";

            String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.left;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp = splitBefore.first +
                    ', array_remove(array_agg($randomName),NULL) as "$columnName"';
                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $tablename."$foreignKey" = $randomName."$localKey" GROUP BY $tablename."$foreignKey" , ${splitBefore.first.split(',').sublist(1).join(',').split('as').first}';
                join = temp;
              } else {
                join +=
                    ',  array_remove(array_agg($randomName),NULL) as "$columnName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $tablename."$foreignKey" = $randomName."$localKey" GROUP BY $tablename."$foreignKey"';
              }
            }
          } else if (element.reflectee is BelongsTo) {
            InstanceMirror cm = reflect(element.reflectee);
            String localKey = cm.getField(#localKey).reflectee ?? "id";
            String foreignKey =
                cm.getField(#foreignKey).reflectee ?? "${tablename}_id";
            JoinType joinType =
                cm.getField(#joinType).reflectee ?? JoinType.left;
            LoadType loadType =
                cm.getField(#loadType).reflectee ?? LoadType.exclude;
            if (loadType == LoadType.include) {
              String randomName = '"${RepositoryUtils.getRandString(5)}"';
              if (join.contains('JOIN') && join.contains('from')) {
                List<String> splitBefore = join.split('from');
                String temp =
                    splitBefore.first + ', $randomName as "$columnName"';
                temp +=
                    ' from ${splitBefore[1]} ${joinType.name.toUpperCase()} JOIN'
                    '"$joinTableName" $randomName'
                    ' on $randomName."$localKey" = $tablename."$foreignKey"';
                join = temp;
              } else {
                join +=
                    ', $randomName as "$columnName" from "$tablename" $tablename ${joinType.name.toUpperCase()} JOIN "$joinTableName" $randomName on $randomName."$localKey" = $tablename."$foreignKey"';
              }
            }
          }
        }
      }
    }

    if (!join.contains('from')) {
      join += 'from "$tablename" $tablename';
    }
    List<String> splittedQuery = join.split('GROUP');
    if (splittedQuery.length == 2) {
      join = '';
      join += splittedQuery.first +
          ' where $tablename.$primaryKey = $value' +
          ' ' +
          'GROUP ${splittedQuery[1]}';
      join += ')select row_to_json(c) from cte c;';
    } else {
      join += ' where $tablename.$primaryKey = $value';
      join += ')select row_to_json(c) from cte c;';
    }
    var data = await PGConnectionAdapter.connection.query(join).toList();
    T? result;
    if (data.isNotEmpty) {
      var element = data.first;
      InstanceMirror res = cm.newInstance(#fromJson,
          [Map<String, dynamic>.from(element.toMap()['row_to_json'])]);
      result = res.reflectee;
    }

    return result;
  }

  @override
  Future<List<T?>> deleteAll(List<S> s, {bool returning = true}) async {
    List<T?> result = [];
    for (var id in s) {
      result.add(await deleteOneById(id));
    }
    return result;
  }

  @override
  Future<T?> deleteOneById(S s, {bool returning = true}) async {
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    String primaryKey = RepositoryUtils.getPrimaryKey(cm);
    T? result = await findOneById(s);

    if (result != null) {
      await PGConnectionAdapter.connection
          .query('DELETE FROM "$tablename" WHERE $primaryKey = $s')
          .toList();
      return result;
    }
    return null;
  }

  /// [insert] is for saving entity in the database, if the entity contains children , they will be saved automaticly also in the database
  ///
  ///
  ///
  @override
  Future<T?> insert(T value) async {
    InstanceMirror res = reflect(value);
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    String primaryKey = RepositoryUtils.getPrimaryKey(cm).replaceAll('"', '');
    String parentPrimaryKey = '';
    dynamic parentId;
    Map<String, dynamic> parentMap = {};
    Map<String, dynamic> map = res.invoke(#serializeModel, []).reflectee;
    List<Map<String, dynamic>> children = [];
    var decls = cm.declarations.values.whereType<VariableMirror>();
    for (var dm in decls) {
      if (dm.metadata.isNotEmpty) {
        for (var meta in dm.metadata) {
          if (meta.reflectee is BelongsTo) {
            InstanceMirror instanceMirror = res.getField(dm.simpleName);
            if (instanceMirror.reflectee != null) {
              String tablename =
                  RepositoryUtils.getTableName(instanceMirror.type);
              parentPrimaryKey =
                  RepositoryUtils.getPrimaryKey(instanceMirror.type)
                      .replaceAll('"', '');
              Map<String, dynamic> tempMap =
                  instanceMirror.invoke(#toJson, []).reflectee;
              String foreignKey =
                  meta.getField(#foreignKey).reflectee ?? "{$tablename}_id";
              parentId = tempMap[parentPrimaryKey];

              if (map.containsValue(instanceMirror.reflectee)) {
                map.removeWhere(
                    (key, value) => value == instanceMirror.reflectee);
                map.addAll({foreignKey: parentId});
                parentMap.addAll({
                  MirrorSystem.getName(dm.simpleName):
                      instanceMirror.reflectee.toJson()
                });
              }
            }
          }
          if (meta.reflectee is HasOne || meta.reflectee is HasMany) {
            InstanceMirror instanceMirror = res.getField(dm.simpleName);
            if (instanceMirror.reflectee != null) {
              Map<String, dynamic> tempMap =
                  instanceMirror.invoke(#serializeModel, []).reflectee;
              children.add(
                  {RepositoryUtils.getTableName(instanceMirror.type): tempMap});
              if (map.containsValue(instanceMirror.reflectee)) {
                map.removeWhere(
                    (key, value) => value == instanceMirror.reflectee);
              }
            }
          }
        }
      }
    }
    List<String> keys = map.keys.toList();
    map.forEach((key, value) {
      if (value == null) keys.remove(key);
    });
    for (int i = 0; i < keys.length; i++) {
      keys[i] = '"${keys[i]}"';
    }
    List<dynamic> values = [];
    map.forEach((key, value) {
      if (value is String) {
        values.add('\'$value\'');
      } else if (value is List) {
        List<String> arrayValues = [];
        for (var temp in value) {
          arrayValues.add("'$temp'");
        }
        values.add('ARRAY$arrayValues');
      } else {
        values.add('$value');
      }
    });
    String sqlQuery =
        'INSERT INTO "$tablename"(${keys.join(",")}) VALUES (${values.join(",")}) RETURNING *';
    final result =
        await PGConnectionAdapter.connection.query(sqlQuery).toList();
    if (result.isNotEmpty) {
      var element = Map<String, dynamic>.from(result.first.toMap());
      if (parentMap.isNotEmpty) {
        element.addAll(parentMap);
      }
      InstanceMirror newInstanceMirror = cm.newInstance(#fromJson, [element]);
      for (var dm in decls) {
        if (dm.metadata.isNotEmpty) {
          for (var meta in dm.metadata) {
            if (meta.reflectee is HasOne || meta.reflectee is HasMany) {
              InstanceMirror instanceMirror = res.getField(dm.simpleName);
              if (instanceMirror.reflectee != null) {
                String tablename =
                    RepositoryUtils.getTableName(instanceMirror.type);

                String foreignKey =
                    meta.getField(#localKey).reflectee ?? "${tablename}_id";
                int index = children
                    .indexWhere((element) => element.containsKey(tablename));
                if (index != -1) {
                  Map<String, dynamic> child = children[index][tablename];
                  child.addAll({foreignKey: element[primaryKey]});
                  List<String> keys = child.keys.toList();
                  child.forEach((key, value) {
                    if (value == null) keys.remove(key);
                  });
                  List<dynamic> values = [];
                  child.forEach((key, value) {
                    if (value != null) {
                      if (value is String) {
                        values.add('\'$value\'');
                      } else if (value is List) {
                        List<String> arrayValues = [];
                        for (var temp in value) {
                          arrayValues.add("'$temp'");
                        }
                        values.add('ARRAY$arrayValues');
                      } else {
                        values.add('$value');
                      }
                    }
                  });
                  for (int i = 0; i < keys.length; i++) {
                    keys[i] = '"${keys[i]}"';
                  }
                  sqlQuery =
                      'INSERT INTO "$tablename"(${keys.join(",")}) VALUES (${values.join(",")}) RETURNING *';
                  var rowResult = await PGConnectionAdapter.connection
                      .query(sqlQuery)
                      .toList();
                  Map<String, dynamic> rowResultAsMap = {};
                  if (rowResult.isNotEmpty) {
                    rowResultAsMap =
                        Map<String, dynamic>.from(rowResult.first.toMap());
                    ClassMirror classMirror = instanceMirror.type;
                    var decls = instanceMirror.type.declarations.values
                        .whereType<VariableMirror>();
                    for (var decl in decls) {
                      for (var meta in decl.metadata) {
                        if (meta.reflectee is BelongsTo) {
                          Type tableType = cm.reflectedType;
                          if (decl.type.reflectedType.toString() ==
                              tableType.toString()) {
                            Map<String, dynamic> temp = {
                              MirrorSystem.getName(decl.simpleName):
                                  Map<String, dynamic>.from(element)
                            };

                            rowResultAsMap.addAll(temp);
                          }
                        }
                      }
                    }
                    newInstanceMirror.setField(
                        dm.simpleName,
                        classMirror.newInstance(
                            #fromJson, [rowResultAsMap]).reflectee);
                  }
                }
              }
            } else if (meta.reflectee is BelongsTo) {
              InstanceMirror instanceMirror = res.getField(dm.simpleName);
              if (instanceMirror.reflectee != null) {
                newInstanceMirror.setField(
                    dm.simpleName, instanceMirror.reflectee);
              }
            }
          }
        }
      }

      return newInstanceMirror.reflectee;
    }
    return null;
  }

  ///[insertAll] is implemented for inserting many objects at same time
  ///
  ///
  ///
  ///@ove
  @override
  Future<List<T?>> insertAll(List<T> objects) async {
    List<T?> result = [];
    for (var object in objects) {
      result.add(await insert(object));
    }
    return result;
  }

  @override
  Future<List<T?>> select(SelectBuilder selectBuilder) async {
    List<T?> result = [];
    ClassMirror cm = reflectClass(T);
    print(selectBuilder.makeQuery());
    final pgResult = await PGConnectionAdapter.connection
        .query(selectBuilder.makeQuery())
        .toList();
    for (var item in pgResult) {
      Map<String, dynamic> map = {};
      if (selectBuilder is SelectBuilderWithNestedJsonOutPut) {
        map = Map<String, dynamic>.from(item.toMap()['row_to_json']);
      } else {
        map = Map<String, dynamic>.from(item.toMap());
      }

      InstanceMirror res = cm.newInstance(#fromJson, [map]);
      result.add(res.reflectee);
    }
    return result;
  }

  @override
  Future<List<T?>> updateAll(List<Map<S, T>> objects) async {
    List<T?> result = [];
    for (var map in objects) {
      result.add(await updateOneById(map.keys.first, map.values.first));
    }
    return result;
  }

  @override
  Future<T?> updateOneById(S id, T object,
      {bool withNull = true, bool returning = true}) async {
    ClassMirror cm = reflectClass(T);
    String tablename = RepositoryUtils.getTableName(cm);
    String primaryKey = RepositoryUtils.getPrimaryKey(cm);
    InstanceMirror instanceMirror = reflect(object);
    Map<String, dynamic> map =
        instanceMirror.invoke(#serializeModel, []).reflectee;
    List<String> query = [];
    map.forEach((key, value) {
      if (value != null) {
        if (value is String) {
          value = "'$value'";
          query.add('"$key" = $value');
        } else if (value is List) {
          List<String> arrayValues = [];
          for (var temp in value) {
            arrayValues.add("'$temp'");
          }
          query.add('"$key" = ARRAY$arrayValues');
        } else {
          if (withNull) {
            query.add('"$key" = $value');
          } else if (value != null) {
            query.add('"$key"= $value');
          }
        }
      }
    });

    String temp =
        'UPDATE "$tablename" SET ${query.join(',')} WHERE $primaryKey = $id';
    if (returning) {
      temp += 'RETURNING *';
    }
    var data = await PGConnectionAdapter.connection.query(temp).toList();
    List<T> result = <T>[];
    if (data.isNotEmpty) {
      var element = Map<String, dynamic>.from(data.first.toMap());
      var decls = cm.declarations.values.whereType<VariableMirror>();
      for (var decl in decls) {
        for (var meta in decl.metadata) {
          if (meta.reflectee is Relationship) {
            var relatedObject = instanceMirror.getField(decl.simpleName);
            if (relatedObject.reflectee != null) {
              Map<dynamic, dynamic> map =
                  relatedObject.invoke(#serializeModel, []).reflectee;
              element.addAll({MirrorSystem.getName(decl.simpleName): map});
            }
          }
        }
      }
      InstanceMirror res =
          cm.newInstance(#fromJson, [Map<String, dynamic>.from(element)]);
      result.add(res.reflectee);
    }
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}