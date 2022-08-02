import '../fennec_pg.dart';

class ProcedureParameters {
  String name;
  ColumnType columnType;
  ProcedureParameters({required this.name, required this.columnType});
}

class ProcedureCallParameters {
  String name;
  ColumnType columnType;
  dynamic value;
  ProcedureCallParameters(
      {required this.name, required this.columnType, required this.value});
}
