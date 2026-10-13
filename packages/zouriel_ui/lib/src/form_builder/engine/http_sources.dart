import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'js.dart';
import 'option_sources.dart';

/// A list admins set up in the app's settings: where to ask, how it searches and pages, and how
/// to read the reply. It holds no secrets; the app's fetch hook ([UiFbHttpSourcesOptions.fetch])
/// adds the login. Same JSON as the web version's `UiFbHttpSourceConfig`.
class UiFbHttpSourceConfig {
  UiFbHttpSourceConfig({
    required this.type,
    required this.label,
    this.description,
    required this.url,
    this.searchParam,
    this.paging,
    this.pageParam,
    this.firstPage,
    this.pageSizeParam,
    this.pageSize,
    this.itemsPath,
    required this.valueField,
    required this.labelField,
    this.descriptionField,
    this.totalPath,
    this.hasMorePath,
    this.minQueryLength,
    this.params,
    UiJson? extra,
  }) : extra = extra ?? {};

  factory UiFbHttpSourceConfig.fromJson(Object? json) {
    final j = json is Map ? json.cast<String, Object?>() : const <String, Object?>{};
    String? s(String k) => j[k] is String ? j[k] as String : (j[k] == null ? null : jsString(j[k]));
    int? n(String k) => j[k] is num ? (j[k] as num).toInt() : null;
    return UiFbHttpSourceConfig(
      type: s('type') ?? '',
      label: s('label') ?? '',
      description: s('description'),
      url: s('url') ?? '',
      searchParam: s('searchParam'),
      paging: s('paging'),
      pageParam: s('pageParam'),
      firstPage: n('firstPage'),
      pageSizeParam: s('pageSizeParam'),
      pageSize: n('pageSize'),
      itemsPath: s('itemsPath'),
      valueField: s('valueField') ?? '',
      labelField: s('labelField') ?? '',
      descriptionField: s('descriptionField'),
      totalPath: s('totalPath'),
      hasMorePath: s('hasMorePath'),
      minQueryLength: n('minQueryLength'),
      params: (j['params'] as List?)?.map(UiFbSourceParamSpec.fromJson).toList(),
      extra: {
        for (final e in j.entries)
          if (!_keys.contains(e.key)) e.key: jsonClone(e.value),
      },
    );
  }

  static const _keys = {
    'type', 'label', 'description', 'url', 'searchParam', 'paging', 'pageParam', 'firstPage', 'pageSizeParam', 'pageSize', //
    'itemsPath', 'valueField', 'labelField', 'descriptionField', 'totalPath', 'hasMorePath', 'minQueryLength', 'params',
  };

  /// Stored in forms that use it. Keep it stable once forms use it.
  String type;
  String label;
  String? description;

  /// Address of the list, e.g. `https://api.example.com/students`. Query settings are added to it.
  String url;

  /// Query setting that carries what people typed. Default `q`.
  String? searchParam;

  /// `page`: page numbers. `offset`: how many to skip. Default `page`.
  String? paging;

  /// Query setting for the page number or the offset. Default `page` (or `offset`).
  String? pageParam;

  /// Number of the first page (0 or 1). Default 1.
  int? firstPage;

  /// Query setting for how many per page. Default `pageSize`. Empty to leave it out.
  String? pageSizeParam;
  int? pageSize;

  /// Where the list is in the reply, as a dotted path (`data.items`). Empty when the reply is the list itself.
  String? itemsPath;

  /// Field (dotted path) whose value is saved.
  String valueField;

  /// What people see: a field (`name`) or a pattern combining fields (`{firstName} {lastName}`).
  String labelField;

  /// Optional second line: a field or a pattern.
  String? descriptionField;

  /// Optional: where the reply says how many there are in all.
  String? totalPath;

  /// Optional: where the reply says whether more pages follow.
  String? hasMorePath;

  /// Don't search until this many characters are typed.
  int? minQueryLength;

  /// Settings form builders fill in per question; each is sent as a query setting of the same name.
  List<UiFbSourceParamSpec>? params;
  final UiJson extra;

  UiFbHttpSourceConfig copyWith({String? type, String? url, String? itemsPath, String? valueField}) {
    final j = toJson();
    if (type != null) j['type'] = type;
    if (url != null) j['url'] = url;
    if (itemsPath != null) j['itemsPath'] = itemsPath;
    if (valueField != null) j['valueField'] = valueField;
    return UiFbHttpSourceConfig.fromJson(j);
  }

  UiJson toJson() {
    final out = <String, Object?>{'type': type, 'label': label};
    void put(String k, Object? v) {
      if (v != null) out[k] = v;
    }

    put('description', description);
    out['url'] = url;
    put('searchParam', searchParam);
    put('paging', paging);
    put('pageParam', pageParam);
    put('firstPage', firstPage);
    put('pageSizeParam', pageSizeParam);
    put('pageSize', pageSize);
    put('itemsPath', itemsPath);
    out['valueField'] = valueField;
    out['labelField'] = labelField;
    put('descriptionField', descriptionField);
    put('totalPath', totalPath);
    put('hasMorePath', hasMorePath);
    put('minQueryLength', minQueryLength);
    put('params', params?.map((p) => p.toJson()).toList());
    for (final e in extra.entries) {
      out.putIfAbsent(e.key, () => jsonClone(e.value));
    }
    return out;
  }
}

/// Gets the reply for a request (decoded JSON). Add the session or token here; throw to refuse.
typedef UiFbSourceFetch = Future<Object?> Function(String url, UiFbAbortSignal signal);

class UiFbHttpSourcesOptions {
  const UiFbHttpSourcesOptions({this.fetch, this.allowedOrigins, this.baseUrl, this.ownOrigin});

  /// How requests are made. Default: a GET with `package:http`, reading JSON.
  final UiFbSourceFetch? fetch;

  /// Servers lists may call, as origins (`https://api.example.com`). Settings pointing anywhere
  /// else are refused, in the settings screen and at run time. Leave out to allow only [ownOrigin].
  final List<String>? allowedOrigins;

  /// What relative list addresses are resolved against (the web uses the page's address).
  /// Default `http://localhost`. On Flutter web pass `Uri.base.toString()`.
  final String? baseUrl;

  /// This app's own origin, always allowed (the web uses `location.origin`). Default none.
  /// On Flutter web pass `Uri.base.origin`.
  final String? ownOrigin;
}

/// A source's reply didn't match its setup, or the request was refused. [message] is worded
/// for the admin setting the list up.
class UiFbSourceError implements Exception {
  const UiFbSourceError(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<Object?> _defaultFetch(String url, UiFbAbortSignal signal) async {
  final res = await http.get(Uri.parse(url), headers: const {'Accept': 'application/json'});
  if (res.statusCode < 200 || res.statusCode > 299) {
    final reason = res.reasonPhrase;
    throw UiFbSourceError('The server answered ${res.statusCode}${reason != null && reason.isNotEmpty ? ' $reason' : ''}');
  }
  return jsonDecode(utf8.decode(res.bodyBytes));
}

/// The request function lists use: the app's hook, or a plain GET reading JSON.
UiFbSourceFetch sourceFetch(UiFbHttpSourcesOptions? options) => options?.fetch ?? _defaultFetch;

const Object _missing = Object();

Object? _readPathRaw(Object? obj, String? path) {
  if (path == null || path.isEmpty) return obj;
  Object? cur = obj;
  for (final part in path.split('.')) {
    if (identical(cur, _missing) || cur == null) return _missing;
    if (cur is Map) {
      cur = cur.containsKey(part) ? cur[part] : _missing;
    } else if (cur is List) {
      final i = int.tryParse(part);
      cur = i != null && i >= 0 && i < cur.length && i.toString() == part ? cur[i] : (part == 'length' ? cur.length : _missing);
    } else {
      return _missing;
    }
  }
  return cur;
}

/// Reads a dotted path (`data.items`, `user.name`); an empty path is the value itself.
Object? readPath(Object? obj, String? path) {
  final v = _readPathRaw(obj, path);
  return identical(v, _missing) ? null : v;
}

String _toText(Object? v) => v == null ? '' : (v is Map || v is List ? jsonEncode(v) : jsString(v));

/// `{firstName} {lastName}` fills in fields; a plain name is read as a single field.
String fillPattern(Object? obj, String? pattern) {
  if (pattern == null || pattern.isEmpty) return '';
  if (!pattern.contains('{')) return _toText(readPath(obj, pattern.trim()));
  return pattern.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => _toText(readPath(obj, m.group(1)!.trim()))).replaceAll(RegExp(r'\s+'), ' ').trim();
}

Uri? _resolve(String url, String? base) {
  try {
    return Uri.parse(base ?? 'http://localhost').resolve(url);
  } catch (_) {
    return null;
  }
}

String _originOfUri(Uri u) {
  if (u.scheme != 'http' && u.scheme != 'https') return '';
  if (u.host.isEmpty) return '';
  final host = u.host.contains(':') ? '[${u.host}]' : u.host;
  final defaultPort = u.scheme == 'http' ? 80 : 443;
  return '${u.scheme}://$host${u.hasPort && u.port != defaultPort ? ':${u.port}' : ''}';
}

/// The origin of an address, or '' when it isn't a full http(s) address.
String originOf(String url, {String? baseUrl}) {
  final u = _resolve(url, baseUrl);
  return u == null ? '' : _originOfUri(u);
}

/// Whether a list may call [url]: its origin is allowed, or it's the app's own.
bool originAllowed(String url, List<String>? allowed, {String? baseUrl, String? ownOrigin}) {
  final o = originOf(url, baseUrl: baseUrl);
  if (o.isEmpty) return false;
  return o == (ownOrigin ?? '') || (allowed ?? const []).any((a) => a.replaceFirst(RegExp(r'/+$'), '') == o);
}

// `URLSearchParams` parsing and serialising, so addresses come out byte-for-byte like the web's.
String _formDecode(String s) {
  final bytes = <int>[];
  final src = utf8.encode(s.replaceAll('+', ' '));
  for (var i = 0; i < src.length; i++) {
    final b = src[i];
    if (b == 0x25 && i + 2 < src.length) {
      final h = int.tryParse(String.fromCharCodes(src.sublist(i + 1, i + 3)), radix: 16);
      if (h != null) {
        bytes.add(h);
        i += 2;
        continue;
      }
    }
    bytes.add(b);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _formEncode(String s) {
  final out = StringBuffer();
  for (final b in utf8.encode(s)) {
    final keep = (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b == 0x2A || b == 0x2D || b == 0x2E || b == 0x5F;
    if (keep) {
      out.writeCharCode(b);
    } else if (b == 0x20) {
      out.write('+');
    } else {
      out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// The address a search asks, with the query, paging and settings added.
String sourceUrl(UiFbHttpSourceConfig c, {required String query, required int page, required int pageSize, required Map<String, Object?> params, String? baseUrl}) {
  final u = _resolve(c.url, baseUrl);
  if (u == null) throw UiFbSourceError('“${c.url}” isn’t a web address.');
  final pairs = <List<String>>[
    if (u.hasQuery)
      for (final part in u.query.split('&'))
        if (part.isNotEmpty)
          () {
            final eq = part.indexOf('=');
            return eq < 0 ? [_formDecode(part), ''] : [_formDecode(part.substring(0, eq)), _formDecode(part.substring(eq + 1))];
          }(),
  ];
  var changed = false;
  void set(String? k, Object? v) {
    if (k == null || k.isEmpty || v == null || v == '') return;
    final value = jsString(v);
    changed = true;
    final at = pairs.indexWhere((p) => p[0] == k);
    if (at < 0) {
      pairs.add([k, value]);
      return;
    }
    pairs[at][1] = value;
    for (var i = pairs.length - 1; i > at; i--) {
      if (pairs[i][0] == k) pairs.removeAt(i);
    }
  }

  set(c.searchParam ?? 'q', query);
  final offset = (c.paging ?? 'page') == 'offset';
  final pageParam = c.pageParam != null && c.pageParam!.isNotEmpty ? c.pageParam : (offset ? 'offset' : 'page');
  set(pageParam, offset ? (page - 1) * pageSize : page - 1 + (c.firstPage ?? 1));
  if (c.pageSizeParam != '') set(c.pageSizeParam ?? 'pageSize', pageSize);
  for (final e in params.entries) {
    final v = e.value;
    set(e.key, v is List ? v.map((x) => x == null ? '' : jsString(x)).join(',') : v);
  }
  final path = u.path.isEmpty && u.hasAuthority ? '/' : u.path;
  final head = '${u.scheme}:${u.hasAuthority ? '//${u.authority}' : ''}$path';
  final search = changed ? pairs.map((p) => '${_formEncode(p[0])}=${_formEncode(p[1])}').join('&') : (u.hasQuery ? u.query : null);
  return '$head${search != null && search.isNotEmpty ? '?$search' : ''}${u.hasFragment ? '#${u.fragment}' : ''}';
}

/// Reads one page of a reply. Throws a [UiFbSourceError] in plain English when the reply doesn't
/// match the setup.
UiFbSourcePage readSourceReply(UiFbHttpSourceConfig c, Object? reply, int pageSize) {
  final list = readPath(reply, c.itemsPath);
  if (list is! List) {
    final keys = reply is Map ? reply.keys.take(8).map((k) => k.toString()).join(', ') : '';
    final path = c.itemsPath;
    throw UiFbSourceError(path != null && path.isNotEmpty
        ? 'No list at “$path” in the reply${keys.isNotEmpty ? ' (it has: $keys)' : ''}.'
        : 'The reply isn’t a list${keys.isNotEmpty ? '; the list may be under one of: $keys' : ''}.');
  }
  final items = <UiFbSourceItem>[];
  for (final row in list) {
    final value = readPath(row, c.valueField);
    if (value == null || value == '') continue;
    final filled = fillPattern(row, c.labelField);
    final label = filled.isNotEmpty ? filled : jsString(value);
    String? description;
    if (c.descriptionField != null && c.descriptionField!.isNotEmpty) {
      final d = fillPattern(row, c.descriptionField);
      description = d.isNotEmpty ? d : null;
    }
    items.add(UiFbSourceItem(value: value is num ? value : jsString(value), label: label, description: description));
  }
  if (list.isNotEmpty && items.isEmpty) throw UiFbSourceError('No “${c.valueField}” field in the items.');
  num? total;
  if (c.totalPath != null && c.totalPath!.isNotEmpty) {
    final raw = _readPathRaw(reply, c.totalPath);
    final n = identical(raw, _missing) ? double.nan : jsNumber(raw is Map ? double.nan : raw);
    if (n.isFinite) total = tidyNum(n);
  }
  final more = c.hasMorePath != null && c.hasMorePath!.isNotEmpty ? readPath(reply, c.hasMorePath) : null;
  final bool? hasMore = more is bool ? more : (more == null ? (list.length < pageSize ? false : null) : jsTruthy(more));
  return UiFbSourcePage(items: items, total: total, hasMore: hasMore);
}

/// Turns a list set up in settings into an option source the builder and renderer can search.
UiFbOptionSourceDef httpOptionSource(UiFbHttpSourceConfig c, [UiFbHttpSourcesOptions options = const UiFbHttpSourcesOptions()]) {
  final get = sourceFetch(options);
  final pageSize = c.pageSize ?? 20;
  return UiFbOptionSource(
    type: c.type,
    label: c.label,
    description: c.description,
    params: c.params,
    pageSize: pageSize,
    minQueryLength: c.minQueryLength,
    search: (q) async {
      final url = sourceUrl(c, query: q.query, page: q.page, pageSize: q.pageSize, params: q.params, baseUrl: options.baseUrl);
      if (!originAllowed(url, options.allowedOrigins, baseUrl: options.baseUrl, ownOrigin: options.ownOrigin)) {
        final o = originOf(url, baseUrl: options.baseUrl);
        throw UiFbSourceError('This app doesn’t allow lists from ${o.isNotEmpty ? o : 'that address'}.');
      }
      return readSourceReply(c, await get(url, q.signal), q.pageSize);
    },
  );
}
