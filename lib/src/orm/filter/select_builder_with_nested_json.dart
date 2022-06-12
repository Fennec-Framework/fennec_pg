import '../../../fennec_pg.dart';

class SelectBuilderWithNestedJsonOutPut extends SelectBuilder {
  final List<JoinOutPut> joinPutputs = [];

  SelectBuilderWithNestedJsonOutPut(String table, List<String> columnsToSelect)
      : super(table, columnsToSelect);

  void joinOutPut(JoinType joinType, String tableName, String tableAlias,
      FilterBuilder joinCondition, String tableAliasOutput, String groupBy,
      {bool resultAsArray = false}) {
    joinPutputs.add(JoinOutPut(joinType, tableName, tableAlias,
        tableAliasOutput, joinCondition, groupBy,
        resultAsArray: resultAsArray));
  }

  @override
  String toString() {
    return 'SELECT ' + columnsToSelect.join(',') + ' FROM ' + table;
  }

  @override
  String makeQuery() {
    String query = '';
    if (columnsToSelect.length == 1 && columnsToSelect.first == '*') {
      query = 'with cte as ( select  "$table".*';
    } else {
      query = 'with cte as ( select ' "$table" + columnsToSelect.join(',');
    }
    if (joinPutputs.isEmpty) {
      query += ' from "$table"';
    } else {
      for (var join in joinPutputs) {
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
        query += key + ' ' + value;
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
