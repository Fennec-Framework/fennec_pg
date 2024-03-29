import 'package:fennec_pg/fennec_pg.dart';

class Join {
  JoinType joinType;
  String tableName;
  String tableAlias;
  FilterBuilder joinCondition;

  Join(this.joinType, this.tableName, this.tableAlias, this.joinCondition);
}

class SelectBuilder {
  final Map<String, OrderBy> sorts = {};
  final List<Join> joins = [];
  List<String> columnsToSelect = [];
  String? table;
  FilterBuilder? condition;
  int? limit;
  int? offset;

  SelectBuilder(this.columnsToSelect, {String? table}) {
    table = table;
  }

  void setLimit(int limit) {
    this.limit = limit;
  }

  void setOffset(int offset) {
    this.offset = offset;
  }

  void join(JoinType joinType, String tableName, String tableAlias,
      FilterBuilder joinCondition) {
    joins.add(Join(joinType, tableName, tableAlias, joinCondition));
  }

  void leftJoin(
      String tableName, String tableAlias, FilterBuilder joinCondition) {
    joins.add(Join(JoinType.left, tableName, tableAlias, joinCondition));
  }

  void rightJoin(
      String tableName, String tableAlias, FilterBuilder joinCondition) {
    joins.add(Join(JoinType.right, tableName, tableAlias, joinCondition));
  }

  void where(FilterBuilder cond) {
    condition = cond;
  }

  void orderBy(fieldName, OrderBy order) {
    sorts[fieldName] = order;
  }

  @override
  String toString() {
    if (table == null) {
      throw Exception(' you should give tablename');
    }
    if (columnsToSelect.length == 1 && columnsToSelect.first == '*') {
      return 'SELECT *  FROM ' '"$table"';
    }
    return 'SELECT ' + columnsToSelect.join(',') + ' FROM ' + '"$table"';
  }

  String makeQuery() {
    String query = toString();

    for (var join in joins) {
      query += ' ' +
          join.joinType.name.toUpperCase() +
          ' JOIN '
              ' ' +
          join.tableAlias +
          ' ' +
          'ON' +
          ' ' +
          join.joinCondition.makeFilterQuery();
    }
    if (condition != null) {
      query += ' where ' + condition!.makeFilterQuery();
    }
    if (sorts.isNotEmpty) {
      query += ' ORDER BY';
      sorts.forEach((key, value) {
        query += key + ' ' + value.name;
      });
    }
    if (limit != null) {
      query += ' limit' ' ' + limit!.toString();
    }
    if (offset != null) {
      query += ' offset' ' ' + offset!.toString();
    }

    return query;
  }
}
