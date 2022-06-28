enum JoinType { inner, left, right, full, self }
enum FetchType { include, exclude }
enum CascadeType { delete, update }

abstract class RelationshipType {
  static const int hasMany = 0;
  static const int hasOne = 1;
  static const int belongsTo = 2;
  static const int manyToMany = 3;
}

class Relationship {
  final int type;
  final String? localKey;
  final String? foreignKey;

  final CascadeType? cascadeType;
  final JoinType? joinType;
  final FetchType? fetchType;

  const Relationship(this.type,
      {this.localKey,
      this.foreignKey,
      this.cascadeType,
      this.joinType,
      this.fetchType});
}

class HasMany extends Relationship {
  const HasMany(
      {String? localKey,
      String? foreignKey,
      CascadeType? cascadeOnDelete,
      FetchType fetchType = FetchType.exclude,
      JoinType? joinType})
      : super(RelationshipType.hasMany,
            localKey: localKey,
            foreignKey: foreignKey,
            cascadeType: cascadeOnDelete,
            joinType: joinType,
            fetchType: fetchType);
}

const HasMany hasMany = HasMany();

class HasOne extends Relationship {
  const HasOne({
    String? localKey,
    String? foreignKey,
    CascadeType? cascadeType,
    JoinType? joinType,
    FetchType fetchType = FetchType.exclude,
  }) : super(RelationshipType.hasOne,
            localKey: localKey,
            foreignKey: foreignKey,
            cascadeType: cascadeType,
            joinType: joinType,
            fetchType: fetchType);
}

const HasOne hasOne = HasOne();

class BelongsTo extends Relationship {
  const BelongsTo({
    String? localKey,
    String? foreignKey,
    JoinType? joinType,
    FetchType fetchType = FetchType.exclude,
  }) : super(RelationshipType.belongsTo,
            localKey: localKey,
            foreignKey: foreignKey,
            joinType: joinType,
            fetchType: fetchType);
}

const BelongsTo belongsTo = BelongsTo();
