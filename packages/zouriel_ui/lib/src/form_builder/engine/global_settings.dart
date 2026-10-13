import 'http_sources.dart';
import 'js.dart';
import 'option_sources.dart';
import 'schema.dart';

/// App-wide form settings, stored by the app as plain JSON (the same JSON the web's
/// `ui-form-global-settings` edits): the lists every form can use, and what new forms start with.
class UiFormGlobalSettings {
  UiFormGlobalSettings({this.version = 1, this.sources, this.defaults, UiJson? extra}) : extra = extra ?? {};

  factory UiFormGlobalSettings.fromJson(Object? json) {
    final j = json is Map ? json.cast<String, Object?>() : const <String, Object?>{};
    return UiFormGlobalSettings(
      version: j['version'] is num ? (j['version'] as num).toInt() : 1,
      sources: (j['sources'] as List?)?.map(UiFbHttpSourceConfig.fromJson).toList(),
      defaults: j['defaults'] is Map ? UiFbSettings.fromJson(j['defaults']) : null,
      extra: {
        for (final e in j.entries)
          if (!const {'version', 'sources', 'defaults'}.contains(e.key)) e.key: jsonClone(e.value),
      },
    );
  }

  int version;

  /// Lists set up by admins (address, paging, how to read the reply).
  List<UiFbHttpSourceConfig>? sources;

  /// What every new form starts with (`createDefinition(defaults: settings.defaults)`). Each form can change its own.
  UiFbSettings? defaults;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'version': version};
    if (sources != null) out['sources'] = [for (final s in sources!) s.toJson()];
    if (defaults != null) out['defaults'] = defaults!.toJson();
    for (final e in extra.entries) {
      out.putIfAbsent(e.key, () => jsonClone(e.value));
    }
    return out;
  }
}

UiFormGlobalSettings createGlobalSettings() => UiFormGlobalSettings(version: 1, sources: [], defaults: UiFbSettings());

/// The lists in global settings as option sources (for the builder and the renderer).
List<UiFbOptionSourceDef> sourcesFromSettings(UiFormGlobalSettings? settings, [UiFbHttpSourcesOptions options = const UiFbHttpSourcesOptions()]) => [
  for (final c in settings?.sources ?? const <UiFbHttpSourceConfig>[])
    if (c.type.isNotEmpty && c.url.isNotEmpty) httpOptionSource(c, options),
];
