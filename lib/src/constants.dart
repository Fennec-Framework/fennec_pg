const int queued = 1;
const int busy = 6;
const int streaming = 7;
const int done = 8;

const int I = 73;
const int T = 84;
const int E = 69;

const int S = 83;

const int protocolVersion = 196608;

const int authTypeMd5 = 5;
const int authTypeOk = 0;

const int msgPassword = 112;
const int msgQuery = 81;
const int msgTerminate = 88;

const int msgAuthRequest = 82;
const int msgErrorResponse = 69;
const int msgBackendKeyData = 75;
const int msgParameterStatus = 83;
const int msgNoticeResponse = 78;
const int msgNotificationResponse = 65;

const int msgCommandComplete = 67;
const int msgCopyData = 100;

const int msgDataRow = 68;
const int msgEmptyQueryResponse = 73;
const int msgFunctionCallResponse = 86;

const int msgReadyForQuery = 90;
const int msgRowDescription = 84;

String itoa(int c) {
  try {
    return String.fromCharCodes([c]);
  } catch (ex) {
    return 'Invalid';
  }
}

String authTypeAsString(int authType) {
  const unknown = 'Unknown';
  const names = <String>[
    'Authentication OK',
    unknown,
    'Kerberos v5',
    'cleartext password',
    unknown,
    'MD5 password',
    'SCM credentials',
    'GSSAPI',
    'GSSAPI or SSPI authentication data',
    'SSPI'
  ];
  var type = unknown;
  if (authType > 0 && authType < names.length) type = names[authType];
  return type;
}

const peConnectionTimeout = 4001,
    pePoolStopped = 4002,
    peConnectionClosed = 4003,
    peConnectionFailed = 40004;

const int bit = 1560,
    bitArray = 1561,
    boolPg = 16,
    boolArray = 1000,
//  _BOX = 603,
    bpChar = 1042,
    bpCharArray = 1014,
    bytea = 17,
    byteaArray = 1001,
    char = 18,
    charArray = 1002,
    date = 1082,
    dateArray = 1182,
    float4 = 700,
    float4Array = 1021,
    float8 = 701,
    float8Array = 1022,
    int2 = 21,
    int2Array = 1005,
    int4 = 23,
    int4Array = 1007,
    int8 = 20,
    int8Array = 1016,
    interval = 1186,
    intervalArray = 1187,
    json = 114,
    jsonArray = 199,
    jsonb = 3802,
    jsonbArray = 3807,
    money = 790,
    moneyArray = 791,
    name = 19,
    nameArray = 1003,
    numeric = 1700,
    numericArray = 1231,
    oid = 26,
    oidArray = 1028,
    //_POINT = 600,
    text = 25,
    textArray = 1009,
    time = 1083,
    timeArray = 1183,
    timestamp = 1114,
    timestampArray = 1115,
    timestampz = 1184,
    timestampzArray = 1185,
    timetz = 1266,
    timetzArray = 1270,
    //_UNSPECIFIED = 0,
    uuid = 2950,
    uuidArray = 2951,
    varbit = 1562,
    varbitArray = 1563,
    varchar = 1043,
    varcharArray = 1015,
    //_VOID = 2278,
    xml = 142,
    xmlArray = 143;
