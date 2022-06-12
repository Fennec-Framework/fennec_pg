import 'dart:collection';
import 'dart:convert';

class Buffer {
  Buffer(this._createException);

  final Function _createException;

  int _position = 0;
  final _queue = Queue<List<int>>();

  int _bytesRead = 0;
  int get bytesRead => _bytesRead;

  int get bytesAvailable =>
      _queue.fold<int>(0, (len, buffer) => len + buffer.length) - _position;

  int readByte() {
    if (_queue.isEmpty) {
      throw _createException("Attempted to read from an empty buffer.");
    }

    int byte = _queue.first[_position];

    _position++;
    if (_position >= _queue.first.length) {
      _queue.removeFirst();
      _position = 0;
    }

    _bytesRead++;

    return byte;
  }

  int readInt16() {
    int a = readByte();
    int b = readByte();

    assert(a < 256 && b < 256 && a >= 0 && b >= 0);
    int i = (a << 8) | b;

    if (i >= 0x8000) i = -0x10000 + i;

    return i;
  }

  int readInt32() {
    int a = readByte();
    int b = readByte();
    int c = readByte();
    int d = readByte();

    assert(a < 256 &&
        b < 256 &&
        c < 256 &&
        d < 256 &&
        a >= 0 &&
        b >= 0 &&
        c >= 0 &&
        d >= 0);
    int i = (a << 24) | (b << 16) | (c << 8) | d;

    if (i >= 0x80000000) i = -0x100000000 + i;

    return i;
  }

  List<int> readBytes(int bytes) {
    final list = <int>[];
    while (--bytes >= 0) {
      list.add(readByte());
    }
    return list;
  }

  String readUtf8StringN(int size) => utf8.decode(readBytes(size));

  String readUtf8String(int maxSize) {
    final bytes = <int>[];
    int c, i = 0;
    while ((c = readByte()) != 0) {
      if (i > maxSize) {
        throw _createException(
            'Max size exceeded while reading string: $maxSize.');
      }
      bytes.add(c);
    }
    return utf8.decode(bytes);
  }

  void append(List<int> data) {
    if (data.isEmpty) throw Exception("Attempted to append empty list.");

    _queue.addLast(data);
  }
}

class MessageBuffer {
  final _buffer = <int>[];
  List<int> get buffer => _buffer;

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _buffer.add(byte);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0) i = 0x10000 + i;

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _buffer.add(a);
    _buffer.add(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0) i = 0x100000000 + i;

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _buffer.add(a);
    _buffer.add(b);
    _buffer.add(c);
    _buffer.add(d);
  }

  void addUtf8String(String s) {
    _buffer.addAll(utf8.encode(s));
    addByte(0);
  }

  void setLength({bool startup: false}) {
    int offset = 0;
    int i = _buffer.length;

    if (!startup) {
      offset = 1;
      i -= 1;
    }

    _buffer[offset] = (i >> 24) & 0x000000FF;
    _buffer[offset + 1] = (i >> 16) & 0x000000FF;
    _buffer[offset + 2] = (i >> 8) & 0x000000FF;
    _buffer[offset + 3] = i & 0x000000FF;
  }
}
