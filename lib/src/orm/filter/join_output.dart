import 'package:fennec_pg/src/orm/filter/filter_builder.dart';
import 'package:fennec_pg/src/orm/filter/select_builder.dart';
import 'package:fennec_pg/src/orm/relations.dart';

class JoinOutPut extends Join {
  final String tableAliasOutPut;
  final bool resultAsArray;
  final String groupBy;
  JoinOutPut(JoinType joinType, String tableName, String tableAlias,
      this.tableAliasOutPut, FilterBuilder joinCondition, this.groupBy,
      {this.resultAsArray = false})
      : super(joinType, tableName, tableAlias, joinCondition);
}
