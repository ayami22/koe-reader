import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class ZipArchive {
  static const int _eocdSig = 0x06054b50;
  static const int _cdSig = 0x02014b50;
  static const int _localSig = 0x04034b50;
  static const int _descriptorSig = 0x08074b50;

  static Map<String, Uint8List> extract(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Empty file');
    }
    var data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    data = stripLeadingJunk(data);

    try {
      return _fromArchive(ZipDecoder().decodeBytes(data));
    } catch (_) {}

    final repaired = repair(data);
    if (repaired != null) {
      try {
        return _fromArchive(ZipDecoder().decodeBytes(repaired));
      } catch (_) {}
      final fromCd = extractViaCentralDirectory(repaired);
      if (fromCd.isNotEmpty) return fromCd;
      final fromLocal = extractViaLocalHeaders(repaired);
      if (fromLocal.isNotEmpty) return fromLocal;
    }

    final fromCd = extractViaCentralDirectory(data);
    if (fromCd.isNotEmpty) return fromCd;
    final fromLocal = extractViaLocalHeaders(data);
    if (fromLocal.isNotEmpty) return fromLocal;

    throw const FormatException(
      'Could not find the end of central directory record',
    );
  }

  static Uint8List stripLeadingJunk(Uint8List data) {
    final start = findLocalHeader(data);
    if (start == null || start == 0) return data;
    return Uint8List.sublistView(data, start);
  }

  static int? findLocalHeader(Uint8List data) {
    final limit = min(data.length - 4, 8192);
    for (var i = 0; i <= limit; i++) {
      if (_u32(data, i) == _localSig) return i;
    }
    return null;
  }

  static Uint8List? repair(Uint8List data) {
    final eocd = findEocd(data);
    if (eocd == null) return null;
    final commentLen = _u16(data, eocd + 20);
    final end = eocd + 22 + commentLen;
    if (end <= 0 || end > data.length) return null;
    if (end == data.length) return data;
    return Uint8List.sublistView(data, 0, end);
  }

  static int? findEocd(Uint8List data) {
    if (data.length < 22) return null;
    final start = max(0, data.length - 65535 - 22);
    for (var i = data.length - 22; i >= start; i--) {
      if (_u32(data, i) != _eocdSig) continue;
      final commentLen = _u16(data, i + 20);
      if (i + 22 + commentLen > data.length) continue;
      final cdSize = _u32(data, i + 12);
      final cdOffset = _u32(data, i + 16);
      if (cdOffset == 0xffffffff) return i;
      if (cdOffset + cdSize <= i) return i;
    }
    return null;
  }

  static Map<String, Uint8List> extractViaCentralDirectory(Uint8List data) {
    final eocd = findEocd(data);
    if (eocd == null) return {};
    var cdSize = _u32(data, eocd + 12);
    var cdOffset = _u32(data, eocd + 16);
    if (cdOffset == 0xffffffff || cdSize == 0xffffffff) return {};
    if (cdOffset + cdSize > data.length) return {};

    final out = <String, Uint8List>{};
    var cursor = cdOffset;
    final cdEnd = cdOffset + cdSize;
    while (cursor + 46 <= cdEnd) {
      if (_u32(data, cursor) != _cdSig) break;
      final flags = _u16(data, cursor + 8);
      final method = _u16(data, cursor + 10);
      final compSize = _u32(data, cursor + 20);
      final nameLen = _u16(data, cursor + 28);
      final extraLen = _u16(data, cursor + 30);
      final commentLen = _u16(data, cursor + 32);
      final localOffset = _u32(data, cursor + 42);
      final nameStart = cursor + 46;
      if (nameStart + nameLen > data.length) break;
      final name = _decodeName(
        data.sublist(nameStart, nameStart + nameLen),
        utf8Flag: (flags & (1 << 11)) != 0,
      );
      final extracted = _readLocalFile(
        data,
        localOffset,
        method: method,
        compSize: compSize,
        flags: flags,
      );
      if (extracted != null && name.isNotEmpty && !name.endsWith('/')) {
        out[_norm(name)] = extracted;
      }
      cursor = nameStart + nameLen + extraLen + commentLen;
    }
    return out;
  }

  static Map<String, Uint8List> extractViaLocalHeaders(Uint8List data) {
    final out = <String, Uint8List>{};
    var offset = 0;
    while (offset + 30 <= data.length) {
      if (_u32(data, offset) != _localSig) {
        offset++;
        continue;
      }
      final flags = _u16(data, offset + 6);
      final method = _u16(data, offset + 8);
      var compSize = _u32(data, offset + 18);
      final nameLen = _u16(data, offset + 26);
      final extraLen = _u16(data, offset + 28);
      final nameStart = offset + 30;
      if (nameStart + nameLen + extraLen > data.length) break;
      final name = _decodeName(
        data.sublist(nameStart, nameStart + nameLen),
        utf8Flag: (flags & (1 << 11)) != 0,
      );
      var dataStart = nameStart + nameLen + extraLen;
      final hasDescriptor = (flags & 8) != 0 && compSize == 0;
      if (hasDescriptor) {
        final scanned = _scanCompressedPayload(data, dataStart);
        if (scanned == null) break;
        compSize = scanned.length;
        final raw = _inflate(scanned, method);
        if (raw != null && name.isNotEmpty && !name.endsWith('/')) {
          out[_norm(name)] = raw;
        }
        offset = dataStart + scanned.length;
        offset = _skipDescriptor(data, offset);
        continue;
      }
      if (dataStart + compSize > data.length) {
        compSize = data.length - dataStart;
      }
      final comp = data.sublist(dataStart, dataStart + compSize);
      final raw = _inflate(comp, method);
      if (raw != null && name.isNotEmpty && !name.endsWith('/')) {
        out[_norm(name)] = raw;
      }
      offset = dataStart + compSize;
    }
    return out;
  }

  static Map<String, Uint8List> _fromArchive(Archive archive) {
    final out = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.content;
      if (content is List<int>) {
        out[_norm(file.name)] = content is Uint8List
            ? content
            : Uint8List.fromList(content);
      }
    }
    return out;
  }

  static Uint8List? _readLocalFile(
    Uint8List data,
    int localOffset, {
    required int method,
    required int compSize,
    required int flags,
  }) {
    if (localOffset + 30 > data.length) return null;
    if (_u32(data, localOffset) != _localSig) return null;
    final nameLen = _u16(data, localOffset + 26);
    final extraLen = _u16(data, localOffset + 28);
    final dataStart = localOffset + 30 + nameLen + extraLen;
    var size = compSize;
    if ((flags & 8) != 0 && size == 0) {
      size = _u32(data, localOffset + 18);
    }
    if (dataStart + size > data.length) {
      if (dataStart >= data.length) return null;
      size = data.length - dataStart;
    }
    return _inflate(data.sublist(dataStart, dataStart + size), method);
  }

  static Uint8List? _scanCompressedPayload(Uint8List data, int start) {
    for (var i = start; i + 4 <= data.length; i++) {
      final sig = _u32(data, i);
      if (sig == _localSig || sig == _cdSig || sig == _descriptorSig) {
        if (i == start) continue;
        return data.sublist(start, i);
      }
    }
    if (start < data.length) return data.sublist(start);
    return null;
  }

  static int _skipDescriptor(Uint8List data, int offset) {
    if (offset + 4 <= data.length && _u32(data, offset) == _descriptorSig) {
      return offset + 16;
    }
    return min(data.length, offset + 12);
  }

  static Uint8List? _inflate(List<int> compressed, int method) {
    if (compressed.isEmpty) return Uint8List(0);
    try {
      if (method == 0) {
        return compressed is Uint8List
            ? compressed
            : Uint8List.fromList(compressed);
      }
      if (method == 8) {
        return Uint8List.fromList(Inflate(compressed).getBytes());
      }
    } catch (_) {}
    return null;
  }

  static String _decodeName(List<int> bytes, {required bool utf8Flag}) {
    try {
      if (utf8Flag) return utf8.decode(bytes);
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static String _norm(String name) =>
      name.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');

  static int _u16(Uint8List d, int i) => d[i] | (d[i + 1] << 8);

  static int _u32(Uint8List d, int i) =>
      d[i] | (d[i + 1] << 8) | (d[i + 2] << 16) | (d[i + 3] << 24);
}
