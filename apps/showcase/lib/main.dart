import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('theme');
  final density = prefs.getString('density');
  final controller = UiThemeController(
    theme: UiThemeName.values.firstWhere((t) => t.name == saved, orElse: () => UiThemeName.dark),
    config: UiConfig(density: UiDensity.values.firstWhere((d) => d.name == density, orElse: () => UiDensity.comfortable)),
  );
  controller.addListener(() {
    prefs.setString('theme', controller.theme.name);
    prefs.setString('density', controller.config.density.name);
  });
  runApp(ShowcaseApp(controller: controller));
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key, required this.controller});
  final UiThemeController controller;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'zouriel_ui',
      controller: controller,
      home: ShowcaseShell(controller: controller),
    );
  }
}
