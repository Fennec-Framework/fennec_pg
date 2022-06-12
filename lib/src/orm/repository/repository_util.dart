import 'dart:convert';
import 'dart:math';
import 'dart:mirrors';

import 'package:fennec_pg/src/orm/repository/repository.dart';

import '../annotations/annotations.dart';
import '../migrations.dart';

import '../relations.dart';

class RepositoryUtils {
  RepositoryUtils._();

  static String getTableName(ClassMirror cm) {
    late String tablename;

    if (cm.typeArguments.isNotEmpty) {
    } else {
      for (var meta in cm.metadata) {
        if (meta.reflectee is Table) {
          tablename =
              meta.reflectee.name ?? MirrorSystem.getName(cm.simpleName);
        }
      }
    }
    return tablename;
  }

  static String getColumnName(DeclarationMirror vm) {
    String columnName = MirrorSystem.getName(vm.simpleName);
    return '"$columnName"';
  }

  static String createTableFromObject(Type classe) {
    String query = '';
    ClassMirror cm = reflectClass(classe);
    String tablename = getTableName(cm);

    Variable primaryKeyAndType = getPrimaryKeyAndType(cm);
    String query1 = "";
    for (var meta in cm.metadata) {
      if (meta.reflectee is Table) {
        query += 'CREATE TABLE IF NOT EXISTS "$tablename" (';
        cm.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              VariableMirror vm = value;
              final columnTable = processColunm(vm);

              if (columnTable.isNotEmpty) {
                if (query.endsWith('(')) {
                  query += '\n $columnTable';
                } else {
                  query += ',\n $columnTable';
                }
              }
            }
          }
        });

        cm.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              VariableMirror vm = value;
              final columnTable =
                  processColumnRelations(vm, tablename, primaryKeyAndType);

              query1 += columnTable;
            }
          }
        });
      }

      query += '\n);';
      query += query1;
      // print(query);
    }
    return query;
  }

  static String processColunm(VariableMirror vm) {
    String type = getSqlType(vm.type.reflectedType.toString());
    if (type.isEmpty) {
      return "";
    }
    String column = '';

    String columnName = getColumnName(vm);

    column += ' ';
    if (vm.metadata.isNotEmpty) {
      for (var meta in vm.metadata) {
        if (meta.reflectee is PrimaryKey) {
          column = columnName + ' ';
          InstanceMirror cm = reflect(meta.reflectee);
          ColumnType? columnType = cm.getField(#type).reflectee;
          bool autoIncrement = cm.getField(#autoIncrement).reflectee;
          if (autoIncrement) {
            column += ' SERIAL PRIMARY KEY  NOT NULL';
          } else {
            if (columnType != null) {
              column += columnType.name + 'PRIMARY KEY  NOT NULL';
            } else {
              column += type + 'PRIMARY KEY  NOT NULL';
            }
          }
        } else if (meta.reflectee is Column) {
          InstanceMirror cm = reflect(meta.reflectee);
          bool isNullable = cm.getField(#isNullable).reflectee;
          int? length = cm.getField(#length).reflectee;
          ColumnType? columnType = cm.getField(#type).reflectee;
          IndexType indexType = cm.getField(#indexType).reflectee;
          String? alias = cm.getField(#alias).reflectee;

          if (columnType != null) {
            if (length != null) {
              column += columnType.name + '(${length.toString()})';
            } else {
              column += columnType.name;
            }
          } else {
            column += type;
          }

          if (indexType == IndexType.primaryKey) {
            column += ' PRIMARY KEY NOT NULL';
          } else if (indexType == IndexType.unique) {
            if (!isNullable) {
              column += ' NOT NULL ';
            }
            column += ' UNIQUE ';
          } else {
            if (!isNullable) {
              column += ' NOT NULL ';
            }
          }

          if (alias != null) {
            String temp = column;
            column = '"$alias"' ' ' + temp;
          } else {
            String temp = column;
            column = columnName + ' ' + temp;
          }
        }
      }
    } else {
      String temp = column;
      column = columnName + ' ' + temp;
      column += type;
    }

    return column;
  }

  static String processColumnRelations(VariableMirror variableMirror,
      String referenceeTableName, Variable variable) {
    String columnRelations = "";
    String primaryKeyType = getSqlType(variable.type.toString());

    for (var meta in variableMirror.metadata) {
      if (meta.reflectee is HasOne) {
        ClassMirror classMirror =
            reflectClass(variableMirror.type.reflectedType);
        String tablename = getTableName(classMirror);
        columnRelations += 'CREATE TABLE IF NOT EXISTS "$tablename" (';
        classMirror.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              final columnTable = processColunm(value);
              if (columnTable.trim().isNotEmpty) {
                if (columnRelations.endsWith('(')) {
                  columnRelations += '\n $columnTable';
                } else {
                  columnRelations += ',\n $columnTable';
                }
              }
            }
          }
        });

        InstanceMirror cm = reflect(meta.reflectee);
        String localKey = cm.getField(#localKey).reflectee ?? "${tablename}_id";
        String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
        columnRelations += ',\n';
        columnRelations += '"$localKey"' ' ' +
            primaryKeyType +
            ' UNIQUE REFERENCES  "$referenceeTableName" ("$foreignKey")';
        columnRelations += '\n);';
        columnRelations +=
            'ALTER TABLE "$tablename" ADD COLUMN IF NOT EXISTS "$localKey" $primaryKeyType UNIQUE REFERENCES "$referenceeTableName" ("$foreignKey");';
      } else if (meta.reflectee is HasMany) {
        ClassMirror classMirror =
            reflectClass(variableMirror.type.typeArguments.first.reflectedType);
        String tablename = getTableName(classMirror);

        columnRelations += 'CREATE TABLE IF NOT EXISTS "$tablename" (';
        classMirror.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              final columnTable = processColunm(value);
              if (columnTable.trim().isNotEmpty) {
                if (columnRelations.endsWith('(')) {
                  columnRelations += '\n $columnTable';
                } else {
                  columnRelations += ',\n $columnTable';
                }
              }
            }
          }
        });
        InstanceMirror cm = reflect(meta.reflectee);
        String localKey = cm.getField(#localKey).reflectee ?? "${tablename}_id";
        String foreignKey = cm.getField(#foreignKey).reflectee ?? "id";
        columnRelations += ',\n';
        columnRelations += '"$localKey"'
                ' ' +
            primaryKeyType +
            ' ' +
            'REFERENCES  "$referenceeTableName" ("$foreignKey")';
        columnRelations += '\n);';
        columnRelations +=
            'ALTER TABLE "$tablename" ADD COLUMN IF NOT EXISTS "$localKey" $primaryKeyType REFERENCES "$referenceeTableName" ("$foreignKey");';
      }
    }
    columnRelations = columnRelations.trim();

    return columnRelations;
  }

  static String getSqlType(String dartType) {
    if (dartType == 'String') {
      return 'VARCHAR(255)';
    } else if (dartType == 'int') {
      return 'INT';
    } else if (dartType == 'bool') {
      return 'BOOLEAN';
    } else if (dartType == 'List<String>') {
      return 'Text ARRAY';
    } else if (dartType == 'List<int>') {
      return 'INT ARRAY';
    } else {
      return '';
    }
  }

  static Variable getPrimaryKeyAndType(ClassMirror cm) {
    late Variable variable;
    int primarykeys = 0;
    for (var meta in cm.metadata) {
      if (meta.reflectee is Table) {
        cm.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              VariableMirror vm = value;

              for (var meta in vm.metadata) {
                if (meta.reflectee is PrimaryKey) {
                  final primarykey = getColumnName(vm);
                  variable = Variable(primarykey, vm.type.reflectedType);

                  primarykeys++;
                }
              }
            }
          }
        });
      }
    }

    if (primarykeys > 1) {
      throw Exception('More than one @id was entered in the ${cm.location} ');
    }

    return variable;
  }

  static String getPrimaryKey(ClassMirror cm) {
    late String primarykey;
    int primarykeys = 0;

    for (var meta in cm.metadata) {
      if (meta.reflectee is Table) {
        cm.declarations.forEach((key, value) {
          if (!value.isPrivate) {
            if (value is VariableMirror) {
              VariableMirror vm = value;

              for (var meta in vm.metadata) {
                if (meta.reflectee is PrimaryKey) {
                  primarykey = getColumnName(vm);
                  primarykeys++;
                }
              }
            }
          }
        });
      }
    }

    if (primarykeys > 1) {
      throw Exception('More than one @id was entered in the ${cm.location} ');
    }

    return primarykey;
  }

  static String getRandString(int len) {
    var random = Random.secure();
    var values = List<int>.generate(len, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }
}
