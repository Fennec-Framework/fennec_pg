import 'package:fennec_pg/src/orm/filter/field.dart';

import '../annotations/annotations.dart';

class SqlParser {
  static dynamic toSql(Field field) {
    if (field.fieldType == Column) {
      return field.value;
    } else if (field.fieldType == String) {
      return "'${field.value}'";
    } else if (field.fieldType == int) {
      return field.value;
    } else if (field.fieldType == List) {
      return '(${field.value.join(',')})';
    } else if (field.fieldType == DateTime) {
      "'${field.value.toIso8601String()}'";
    }
    return field.value;
  }
}
