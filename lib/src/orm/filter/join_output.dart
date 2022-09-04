

import '../../../fennec_pg.dart';

class JoinOutput extends Join {
  final String tableAliasOutPut;
  final bool resultAsArray;
  final String groupBy;
  JoinOutput(JoinType joinType, String tableName, String tableAlias,
      this.tableAliasOutPut, FilterBuilder joinCondition, this.groupBy,
      {this.resultAsArray = false})
      : super(joinType, tableName, tableAlias, joinCondition);
}
