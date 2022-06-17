import 'dart:async';
import 'dart:collection';

import 'package:fennec_pg/src/constants.dart';

import 'core/fennec_pg.dart';

class Query {
  int state = queued;
  final String sql;
  final StreamController<Row> controller = StreamController<Row>();
  int commandIndex = 0;
  int? columnCount;
  List<Column>? columns;
  List<dynamic>? rowData;
  int? rowsAffected;

  List<String>? _columnNames;
  Map<Symbol, int>? _columnIndex;

  Query(this.sql);

  Stream<dynamic> get stream => controller.stream;

  void addRowDescription() {
    if (state == queued) state = streaming;

    final columnNames = _columnNames = columns!.map((c) => c.name).toList(),
        columnIndex = _columnIndex = <Symbol, int>{};
    for (var i = 0; i < columnNames.length; i++) {
      var name = columnNames[i];
      if (_reIdent.hasMatch(name)) columnIndex[Symbol(name)] = i;
    }
  }

  static final _reIdent = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

  void addRow() {
    var row = Row(_columnNames!, rowData!, _columnIndex!, columns!);
    rowData = null;
    controller.add(row);
  }

  void addError(Object err) {
    controller.addError(err);
  }

  void close() {
    controller.close();
    state = done;
  }
}

class Column implements IColumn {
  @override
  final int index;
  @override
  final String name;

  @override
  final int fieldId;
  @override
  final int tableColNo;
  @override
  final int fieldType;
  @override
  final int dataSize;
  @override
  final int typeModifier;
  @override
  final int formatCode;

  @override
  bool get isBinary => formatCode == 1;

  Column(this.index, this.name, this.fieldId, this.tableColNo, this.fieldType,
      this.dataSize, this.typeModifier, this.formatCode);

  @override
  String toString() =>
      'Column: index: $index, name: $name, fieldId: $fieldId, tableColNo: $tableColNo, fieldType: $fieldType, dataSize: $dataSize, typeModifier: $typeModifier, formatCode: $formatCode.';
}

typedef RowFunction = void Function(String columnName, dynamic columnValue);

class Row implements IRow {
  Row(this.columnNames, this.columnValues, this.index, this.columns) {
    assert(columnNames.length == columnValues.length);
  }

  final Map<Symbol, int> index;
  final List<String> columnNames;
  final List columnValues;
  final List<IColumn> columns;

  @override
  operator [](int i) => columnValues[i];

  void forEach(RowFunction rowFunction) {
    assert(columnValues.length == columnNames.length);
    for (int i = 0; i < columnValues.length; i++) {
      rowFunction(columnNames[i], columnValues[i]);
    }
  }

  @override
  noSuchMethod(Invocation invocation) {
    var name = invocation.memberName;
    if (invocation.isGetter) {
      var i = index[name];
      if (i != null) return columnValues[i];
    }
    super.noSuchMethod(invocation);
  }

  @override
  String toString() => columnValues.toString();

  @override
  List toList() => UnmodifiableListView(columnValues);

  @override
  Map<String, dynamic> toMap() =>
      Map<String, dynamic>.fromIterables(columnNames, columnValues);

  @override
  List<IColumn> getColumns() => UnmodifiableListView<IColumn>(columns);
}
