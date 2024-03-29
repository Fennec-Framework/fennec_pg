import '../../../fennec_pg.dart';

class SelectBuilderWithNestedJsonOutput extends SelectBuilder {
  final List<JoinOutput> joinOutputs = [];

  SelectBuilderWithNestedJsonOutput(List<String> columnsToSelect,
      {String? table})
      : super(columnsToSelect, table: table);

  void joinOutPut(JoinType joinType, String tableName, String tableAlias,
      FilterBuilder joinCondition, String tableAliasOutput, String groupBy,
      {bool resultAsArray = false}) {
    joinOutputs.add(JoinOutput(joinType, tableName, tableAlias,
        tableAliasOutput, joinCondition, groupBy,
        resultAsArray: resultAsArray));
  }

  @override
  String toString() {
    if (table == null) {
      throw Exception(' you should give tablename');
    }

    return 'SELECT ' + columnsToSelect.join(',') + ' FROM ' + '"$table"';
  }

  @override
  String makeQuery() {
    String query = '';
    if (columnsToSelect.length == 1 && columnsToSelect.first == '*') {
      query = 'with cte as ( select  "$table".*';
    } else {
      query = 'with cte as ( select ' "$table" + columnsToSelect.join(',');
    }
    if (joinOutputs.isEmpty) {
      query += ' from "$table"';
    } else {
      for (var join in joinOutputs) {
        if (join.resultAsArray) {
          if (query.contains('from')) {
            List<String> splitedQuery = query.split('from');
            query = splitedQuery.first +
                ' , ' +
                'array_remove(array_agg("${join.tableAlias}"),NULL)' +
                ' as ' +
                join.tableAliasOutPut;
            query += ' from  ${splitedQuery[1]} ' +
                join.joinType.name.toUpperCase() +
                ' JOIN ' +
                ' ' +
                '"${join.tableAlias}"' +
                ' ' +
                'ON' +
                ' ' +
                join.joinCondition.makeFilterQuery() +
                ' Group By "$table"."${join.groupBy}" ,  "${join.tableName}"';
          } else {
            query += ', '
                    'array_remove(array_agg("${join.tableAlias}"),NULL)'
                    ' as ' +
                join.tableAliasOutPut +
                ' from   "$table" ' +
                join.joinType.name.toUpperCase() +
                ' JOIN ' +
                ' ' +
                '"${join.tableAlias}"' +
                ' ' +
                'ON' +
                '' +
                join.joinCondition.makeFilterQuery() +
                ' Group By "$table"."${join.groupBy}"';
          }
        } else {
          if (query.contains('from')) {
            List<String> splitedQuery = query.split('from');
            query = splitedQuery.first +
                ' , ' +
                '"${join.tableAlias}"' +
                ' as ' +
                join.tableAliasOutPut;
            query += ' ' 'from "${splitedQuery[1]}" ' +
                join.joinType.name.toUpperCase() +
                ' JOIN '
                    ' ' +
                '"${join.tableAlias}"' +
                ' ' +
                'ON' +
                ' ' +
                join.joinCondition.makeFilterQuery();
          } else {
            query += ', '
                    '"${join.tableAlias}"'
                    ' as ' +
                join.tableAliasOutPut +
                ' from  "$table" ' +
                join.joinType.name.toUpperCase() +
                ' JOIN '
                    ' ' +
                '"${join.tableAlias}"' +
                ' ' +
                'ON' +
                ' ' +
                join.joinCondition.makeFilterQuery();
          }
        }
      }
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
    query += ')select row_to_json(c) from cte c;';

    return query;
  }
}
