class Table {
  final String name;

  const Table(this.name);
}

class Id {
  final bool autoIncrement;
  const Id({this.autoIncrement = true});
}

const id = Id();

class ForeignId {
  const ForeignId();
}

const foreignId = ForeignId();

class NotNull {
  const NotNull();
}

const notNull = NotNull();

class ForeignTable {
  final String name;

  const ForeignTable(this.name);
}

class Converter {
  const Converter();
}

const converter = Converter();

class ForeignKey {
  String value;
  Type type;
  ForeignKey(this.value, this.type);
}

class Variable {
  String value;
  Type type;
  Variable(this.value, this.type);
}
