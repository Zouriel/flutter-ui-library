import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('theme');
  final density = prefs.getString('density');
  final rtl = ValueNotifier(prefs.getBool('rtl') ?? false);
  final controller = UiThemeController(
    theme: UiThemeName.values.firstWhere((t) => t.name == saved, orElse: () => UiThemeName.dark),
    config: UiConfig(
      density: UiDensity.values.firstWhere((d) => d.name == density, orElse: () => UiDensity.comfortable),
      strings: rtl.value ? UiStrings.dv : const UiStrings(),
    ),
  );
  controller.addListener(() {
    prefs.setString('theme', controller.theme.name);
    prefs.setString('density', controller.config.density.name);
  });
  rtl.addListener(() => prefs.setBool('rtl', rtl.value));
  runApp(ShowcaseApp(controller: controller, rtl: rtl));
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key, required this.controller, this.rtl});
  final UiThemeController controller;

  /// The RTL · Dhivehi switch (0.46.0): right-to-left layout with the library's Dhivehi words.
  final ValueNotifier<bool>? rtl;

  @override
  Widget build(BuildContext context) => _RtlHost(controller: controller, rtl: rtl);
}

class _RtlHost extends StatefulWidget {
  const _RtlHost({required this.controller, this.rtl});
  final UiThemeController controller;
  final ValueNotifier<bool>? rtl;

  @override
  State<_RtlHost> createState() => _RtlHostState();
}

class _RtlHostState extends State<_RtlHost> {
  late final ValueNotifier<bool> _rtl = widget.rtl ?? ValueNotifier(false);

  @override
  void dispose() {
    if (widget.rtl == null) _rtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _rtl,
      builder: (context, rtl, _) => UiApp(
        title: 'zouriel_ui',
        controller: widget.controller,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        home: ShowcaseShell(controller: widget.controller, rtl: _rtl),
      ),
    );
  }
}
