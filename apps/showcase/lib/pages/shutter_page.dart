import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// 0.72.0: the shutter loader, the app-wide spinner switch, pull to refresh and the overscroll ball.
class ShutterPage extends StatefulWidget {
  const ShutterPage({super.key});

  @override
  State<ShutterPage> createState() => _ShutterPageState();
}

class _ShutterPageState extends State<ShutterPage> {
  // Used when the page has no app controller to switch (its tests); the showcase app switches the
  // whole app, as an app's own UiConfig would.
  UiSpinnerStyle _spinner = UiSpinnerStyle.ring;
  UiOverscrollStyle _overscroll = UiOverscrollStyle.platform;

  final List<String> _rows = [for (var i = 1; i <= 12; i++) 'Photo $i'];
  int _refreshes = 0;
  Timer? _done;

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  Future<void> _refresh() {
    final c = Completer<void>();
    _done = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _rows.insert(0, 'New photo ${++_refreshes}'));
      c.complete();
    });
    return c.future;
  }

  Widget _islands(BuildContext context, Widget Function(BuildContext context) build) {
    final t = context.ui;
    Widget island(UiThemeName theme) => ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusLg),
          child: UiThemeScope(
            theme: theme,
            child: Padding(padding: EdgeInsets.all(t.space4), child: Builder(builder: build)),
          ),
        );
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 560;
      final both = [island(UiThemeName.light), island(UiThemeName.dark)];
      return wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [for (final w in both) Expanded(child: w)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: both);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final app = UiThemeController.maybeOf(context);
    final config = context.uiTheme.config;
    final spinner = app != null ? config.spinner : _spinner;
    final overscroll = app != null ? config.overscroll : _overscroll;
    void setSpinner(UiSpinnerStyle v) => app != null ? app.setConfig(app.config.copyWith(spinner: v)) : setState(() => _spinner = v);
    void setOverscroll(UiOverscrollStyle v) => app != null ? app.setConfig(app.config.copyWith(overscroll: v)) : setState(() => _overscroll = v);

    Widget list(List<String> rows, {Key? key}) => ListView.separated(
          key: key,
          padding: EdgeInsets.all(t.space3),
          itemCount: rows.length,
          separatorBuilder: (_, _) => SizedBox(height: t.space2),
          itemBuilder: (context, i) => Container(
            padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
            decoration: BoxDecoration(color: context.ui.surface, borderRadius: BorderRadius.circular(context.ui.radius), border: Border.all(color: context.ui.border)),
            child: Text(rows[i]),
          ),
        );
    Widget frame(Widget child) => Container(
          height: 320,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(t.radiusLg), border: Border.all(color: t.border)),
          child: child,
        );

    Widget page = DocPage(
      eyebrow: 'Components',
      title: 'Shutter loader',
      lead: 'A camera shutter for loading, an app-wide switch that puts it in every spinner, pull to refresh, and the shutter ball past a list\'s ends.',
      children: [
        DocSection(
          name: 'Shutter loader',
          widget: 'UiShutterLoader',
          summary: 'Six blades click shut three times, then the shutter rests open; the loop takes 2.1 seconds, under three flashes a second. It takes the surrounding text colour (in a button, the button\'s text colour) unless you give it one, and is announced as "Loading" like the spinner. Under reduced motion the blades stay still and it pulses gently instead; it never freezes.',
          demo: _islands(
            context,
            (context) => UiTheme(
              // The buttons' spinners draw the shutter here whatever the app's setting.
              data: context.uiTheme.copyWith(config: context.uiTheme.config.copyWith(spinner: UiSpinnerStyle.shutter)),
              child: Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: context.ui.space4, children: [
                    Row(spacing: context.ui.space4, children: [
                      const UiShutterLoader(),
                      const UiShutterLoader(size: 24),
                      const UiShutterLoader(size: 40),
                      UiShutterLoader(size: 64, color: context.ui.primary),
                    ]),
                    Wrap(spacing: context.ui.space3, runSpacing: context.ui.space3, children: [
                      UiButton(label: 'Saving', loading: true, onPressed: () {}),
                      UiButton(label: 'Saving', variant: UiButtonVariant.secondary, loading: true, onPressed: () {}),
                    ]),
                    UiCard(
                      child: Row(spacing: context.ui.space3, children: [
                        UiShutterLoader(size: 28, color: context.ui.primary),
                        const Expanded(child: UiText('Loading photos…', variant: UiTextVariant.caption)),
                      ]),
                    ),
                  ])),
            ),
          ),
          code: 'UiShutterLoader(size: 24)',
          api: const [
            ApiRow('size', 'double', 'Width and height.', def: '16'),
            ApiRow('color', 'Color?', 'Defaults to the surrounding text colour.'),
            ApiRow('label', 'String?', 'Accessible name.', def: "'Loading…'"),
            ApiRow('decorative', 'bool', 'Hide from screen readers when something else announces it.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Every spinner',
          widget: 'UiConfig.spinner',
          summary: 'UiConfig(spinner: UiSpinnerStyle.shutter) makes every UiSpinner in the library draw the shutter, at the same size and colour: button loading states, loading overlays, the image picker, the PDF viewer, the map. The default, ring, leaves apps as they were. This switch changes the whole showcase.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
            UiSegmented<UiSpinnerStyle>(
              label: 'Spinner',
              options: const [UiSegmentedOption(value: UiSpinnerStyle.ring, label: 'Ring'), UiSegmentedOption(value: UiSpinnerStyle.shutter, label: 'Shutter')],
              value: spinner,
              onChanged: setSpinner,
            ),
            Wrap(spacing: t.space4, runSpacing: t.space3, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const UiSpinner(),
              const UiSpinner(size: 24),
              UiButton(label: 'Uploading', loading: true, onPressed: () {}),
            ]),
          ]),
          code: 'UiApp(\n  config: const UiConfig(spinner: UiSpinnerStyle.shutter),\n  home: …,\n)',
          api: const [
            ApiRow('spinner', 'UiSpinnerStyle', 'ring or shutter.', def: 'ring'),
          ],
        ),
        DocSection(
          name: 'Pull to refresh',
          widget: 'UiPullToRefresh',
          summary: 'Wrap a vertical scroll view. Pulling down at its top drops in the shutter ball; past about 80 px the ball snaps to its resting spot with a selection click and clicks its blades while onRefresh runs, then slides back up when it finishes (or fails). It listens to scrolling rather than adding a gesture, so the content\'s taps, long presses and pinches are untouched. Screen readers get a Refresh action. Phones only: browsers own this gesture on the web.',
          demo: frame(UiPullToRefresh(onRefresh: _refresh, child: list(_rows, key: const ValueKey('refresh-list')))),
          code: 'UiPullToRefresh(\n  onRefresh: () => album.reload(),\n  child: ListView(children: tiles),\n)',
          api: const [
            ApiRow('onRefresh', 'Future<void> Function()', 'Runs once per pull; the ball stays until it completes.'),
            ApiRow('child', 'Widget', 'A vertical ListView, GridView, CustomScrollView…'),
            ApiRow('threshold', 'double', 'Finger travel that starts a refresh.', def: '80'),
            ApiRow('enabled', 'bool', 'Off: pulls never refresh.', def: 'true'),
            ApiRow('notificationPredicate', 'ScrollNotificationPredicate', 'Which scroll view to follow; (n) => n.depth == 1 inside a NestedScrollView.', def: 'depth 0'),
          ],
        ),
        DocSection(
          name: 'Overscroll',
          widget: 'UiConfig.overscroll',
          summary: 'What a vertical scroll view shows when pulled past its ends. platform (the default) is the stretch on Android and the bounce on iOS. shutter drops a small shutter ball in from the top edge, following the finger and slowing as it goes, and springs it back on release; past the bottom it rises from the bottom edge. Horizontal scroll views keep the platform\'s. This switch changes the whole showcase; pull past either end of the list.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: UiSegmented<UiOverscrollStyle>(
                label: 'Overscroll',
                options: const [UiSegmentedOption(value: UiOverscrollStyle.platform, label: 'Platform'), UiSegmentedOption(value: UiOverscrollStyle.shutter, label: 'Shutter')],
                value: overscroll,
                onChanged: setOverscroll,
              ),
            ),
            frame(list([for (var i = 1; i <= 10; i++) 'Guest $i'], key: const ValueKey('overscroll-list'))),
          ]),
          code: 'UiApp(\n  config: const UiConfig(overscroll: UiOverscrollStyle.shutter),\n  home: …,\n)',
          api: const [
            ApiRow('overscroll', 'UiOverscrollStyle', 'platform or shutter.', def: 'platform'),
          ],
        ),
      ],
    );
    if (app == null) {
      page = UiTheme(data: context.uiTheme.copyWith(config: config.copyWith(spinner: _spinner, overscroll: _overscroll)), child: page);
    }
    return page;
  }
}
