class ConditionLogic {
  static const String and = 'AND';
  static const String or = 'OR';
  static const String IN = 'IN';
}

class FilterBuilder {
  dynamic firstVar;
  dynamic secondVar;
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
      query += '${cond.firstVar}  ${cond.condition}  ${cond.secondVar}';
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
  Equals(var firstVar, var secondVar, [String? logic])
      : super(firstVar, '=', secondVar, logic);
}

class In extends FilterBuilder {
  In(var firstVar, var secondVar, [String? logic])
      : super(firstVar, 'IN', secondVar, logic);
}

class NotIn extends FilterBuilder {
  NotIn(var firstVar, var secondVar, [String? logic])
      : super(firstVar, 'NOT IN', secondVar, logic);
}

class NotEquals extends FilterBuilder {
  NotEquals(var firstVar, var secondVar, [String? logic])
      : super(firstVar, '<>', secondVar, logic);
}

class LowerThan extends FilterBuilder {
  LowerThan(var firstVar, var secondVar, [String? logic])
      : super(firstVar, '<', secondVar, logic);
}

class BiggerThan extends FilterBuilder {
  BiggerThan(var firstVar, var secondVar, [String? logic])
      : super(firstVar, '>', secondVar, logic);
}
