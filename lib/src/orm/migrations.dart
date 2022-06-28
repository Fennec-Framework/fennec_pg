const List<String> sqlReservedWords = [
  'SELECT',
  'UPDATE',
  'INSERT',
  'DELETE',
  'FROM',
  'ASC',
  'DESC',
  'VALUES',
  'RETURNING',
  'ORDER',
  'BY',
];

/// Maps to SQL index types.
enum IndexType { none, standardIndex, primaryKey, unique }

class ColumnType {
  final String name;

  const ColumnType(this.name);

  static const ColumnType boolean = ColumnType('boolean');

  static const ColumnType smallSerial = ColumnType('smallserial');
  static const ColumnType serial = ColumnType('serial');
  static const ColumnType bigSerial = ColumnType('bigserial');

  static const ColumnType bigInt = ColumnType('bigint');
  static const ColumnType int = ColumnType('int');
  static const ColumnType smallInt = ColumnType('smallint');
  static const ColumnType tinyInt = ColumnType('tinyint');
  static const ColumnType bit = ColumnType('bit');
  static const ColumnType decimal = ColumnType('decimal');
  static const ColumnType numeric = ColumnType('numeric');
  static const ColumnType money = ColumnType('money');
  static const ColumnType smallMoney = ColumnType('smallmoney');
  static const ColumnType float = ColumnType('float');
  static const ColumnType real = ColumnType('real');

  static const ColumnType dateTime = ColumnType('datetime');
  static const ColumnType smallDateTime = ColumnType('smalldatetime');
  static const ColumnType date = ColumnType('date');
  static const ColumnType time = ColumnType('time');
  static const ColumnType timeStamp = ColumnType('timestamp');
  static const ColumnType timeStampWithTimeZone =
      ColumnType('timestamp with time zone');

  static const ColumnType char = ColumnType('char');
  static const ColumnType varChar = ColumnType('varchar');
  static const ColumnType varCharMax = ColumnType('varchar(max)');
  static const ColumnType text = ColumnType('text');

  static const ColumnType nChar = ColumnType('nchar');
  static const ColumnType nVarChar = ColumnType('nvarchar');
  static const ColumnType nVarCharMax = ColumnType('nvarchar(max)');
  static const ColumnType nText = ColumnType('ntext');

  static const ColumnType binary = ColumnType('binary');
  static const ColumnType varBinary = ColumnType('varbinary');
  static const ColumnType varBinaryMax = ColumnType('varbinary(max)');
  static const ColumnType image = ColumnType('image');

  static const ColumnType json = ColumnType('json');
  static const ColumnType jsonb = ColumnType('jsonb');

  static const ColumnType sqlVariant = ColumnType('sql_variant');
  static const ColumnType uniqueIdentifier = ColumnType('uniqueidentifier');
  static const ColumnType xml = ColumnType('xml');
  static const ColumnType cursor = ColumnType('cursor');
  static const ColumnType table = ColumnType('table');
}
