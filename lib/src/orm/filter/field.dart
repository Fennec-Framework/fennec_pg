import '../../../fennec_pg.dart';

class Field {
  final Type fieldType;
  final dynamic value;
  Field({required this.fieldType, required this.value});
  Field.tableColumn(dynamic value) : this(fieldType: Column, value: value);
  Field.string(dynamic value) : this(fieldType: String, value: value);
  Field.int(dynamic value) : this(fieldType: int, value: value);
  Field.list(dynamic value) : this(fieldType: List, value: value);
  Field.dateTime(dynamic value) : this(fieldType: DateTime, value: value);
  Field.dynamic(dynamic value) : this(fieldType: dynamic, value: value);
}
