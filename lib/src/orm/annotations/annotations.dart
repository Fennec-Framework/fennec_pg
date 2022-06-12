import '../../../fennec_pg.dart';

class Table {
  final String name;

  const Table(this.name);
}

class Column {
  final bool isNullable;
  final int? length;

  final ColumnType? type;
  final IndexType indexType;
  final String? alias;
  final Type? serializableTo;
  final bool serializable;

  const Column(
      {this.isNullable = true,
      this.length,
      this.type,
      this.indexType = IndexType.none,
      this.alias,
      this.serializableTo,
      this.serializable = true});

  /// Returns `true` if [expression] is not `null`.
  bool get hasAlias => alias != null;
}

class PrimaryKey extends Column {
  final ColumnType? columnType;
  final bool autoIncrement;
  const PrimaryKey({this.columnType, this.autoIncrement = true})
      : super(
          type: columnType,
          indexType: IndexType.primaryKey,
        );
}

const Column primaryKey = PrimaryKey();

class Variable {
  String value;
  Type type;
  Variable(this.value, this.type);
}
