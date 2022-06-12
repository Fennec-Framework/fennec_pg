enum JoinType { inner, left, right, full, self }
enum LoadType { include, exclude }

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
  final String? foreignTable;
  final bool? cascadeOnDelete;
  final JoinType? joinType;
  final LoadType? loadType;

  const Relationship(this.type,
      {this.localKey,
      this.foreignKey,
      this.foreignTable,
      this.cascadeOnDelete,
      this.joinType,
      this.loadType});
}

class HasMany extends Relationship {
  const HasMany(
      {String? localKey,
      String? foreignKey,
      String? foreignTable,
      bool cascadeOnDelete = false,
      LoadType loadType = LoadType.exclude,
      JoinType? joinType})
      : super(RelationshipType.hasMany,
            localKey: localKey,
            foreignKey: foreignKey,
            foreignTable: foreignTable,
            cascadeOnDelete: cascadeOnDelete == true,
            joinType: joinType,
            loadType: loadType);
}

const HasMany hasMany = HasMany();

class HasOne extends Relationship {
  const HasOne({
    String? localKey,
    String? foreignKey,
    String? foreignTable,
    bool cascadeOnDelete = false,
    JoinType? joinType,
    LoadType loadType = LoadType.exclude,
  }) : super(RelationshipType.hasOne,
            localKey: localKey,
            foreignKey: foreignKey,
            foreignTable: foreignTable,
            cascadeOnDelete: cascadeOnDelete == true,
            joinType: joinType,
            loadType: loadType);
}

const HasOne hasOne = HasOne();

class BelongsTo extends Relationship {
  const BelongsTo({
    String? localKey,
    String? foreignKey,
    String? foreignTable,
    JoinType? joinType,
    LoadType loadType = LoadType.exclude,
  }) : super(RelationshipType.belongsTo,
            localKey: localKey,
            foreignKey: foreignKey,
            foreignTable: foreignTable,
            joinType: joinType,
            loadType: loadType);
}

const BelongsTo belongsTo = BelongsTo();

class ManyToMany extends Relationship {
  final Type through;
  const ManyToMany(
    this.through, {
    String? localKey,
    String? foreignKey,
    String? foreignTable,
    bool cascadeOnDelete = false,
    JoinType? joinType,
    LoadType loadType = LoadType.exclude,
  }) : super(
            RelationshipType.hasMany, // Many-to-Many is actually just a hasMany
            localKey: localKey,
            foreignKey: foreignKey,
            foreignTable: foreignTable,
            cascadeOnDelete: cascadeOnDelete == true,
            joinType: joinType,
            loadType: loadType);
}
