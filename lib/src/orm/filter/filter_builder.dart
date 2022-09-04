import 'package:fennec_pg/src/orm/filter/sql_parser.dart';

import '../../../fennec_pg.dart';

class ConditionLogic {
  static const String and = 'AND';
  static const String or = 'OR';
  static const String iN = 'IN';
}

enum OrderBy { ASC, DESC }

class FilterBuilder {
  Field firstVar;
  Field secondVar;
  String condition;
  String? logic;
  List<FilterBuilder> conditionQueue = [];

  FilterBuilder(this.firstVar, this.condition, this.secondVar, [this.logic]) {
    conditionQueue.add(this);
  }

  String makeFilterQuery() {
    String query = '';
    for (var cond in conditionQueue) {
      if (cond.logic != null) {
        query += '  ' + cond.logic! + '  ';
      }
      query +=
          '${SqlParser.toSql(cond.firstVar)}  ${cond.condition}  ${SqlParser.toSql(cond.secondVar)}';
    }

    return query;
  }

  FilterBuilder and(FilterBuilder cond) {
    cond.logic = ConditionLogic.and;
    conditionQueue.add(cond);

    return this;
  }

  FilterBuilder or(FilterBuilder cond) {
    cond.logic = ConditionLogic.or;
    conditionQueue.add(cond);
    return this;
  }
}

class Equals extends FilterBuilder {
  Equals(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, '=', secondVar, logic);
}

class In extends FilterBuilder {
  In(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, 'IN', secondVar, logic);
}

class NotIn extends FilterBuilder {
  NotIn(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, 'NOT IN', secondVar, logic);
}

class NotEquals extends FilterBuilder {
  NotEquals(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, '<>', secondVar, logic);
}

class LowerThan extends FilterBuilder {
  LowerThan(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, '<', secondVar, logic);
}

class BiggerThan extends FilterBuilder {
  BiggerThan(Field firstVar, Field secondVar, [String? logic])
      : super(firstVar, '>', secondVar, logic);
}
