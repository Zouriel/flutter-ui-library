import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('theme');
  final controller = UiThemeController(
    theme: UiThemeName.values.firstWhere((t) => t.name == saved, orElse: () => UiThemeName.dark),
  );
  controller.addListener(() => prefs.setString('theme', controller.theme.name));
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
