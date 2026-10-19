import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class FxPage extends StatefulWidget {
  const FxPage({super.key});

  @override
  State<FxPage> createState() => _FxPageState();
}

class _FxPageState extends State<FxPage> {
  int _splitRun = 0;
  int _introRun = 0;
  bool _introDone = false;
  bool _grain = true;

  Widget _card(BuildContext context, String title, String body) {
    final t = context.ui;
    return Container(
      width: 180,
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
        UiText(title, variant: UiTextVariant.h5),
        UiText(body, variant: UiTextVariant.caption),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Motion',
      title: 'Motion & FX',
      lead: 'Reveal, split text, marquee, drift, glyph field, grain, intro loader, scroll progress, press tilt and the section label. Every effect follows the OS "remove animations" setting: entrances calm down, loops stand still, textures go.',
      children: [
        DocSection(
          name: 'Reveal',
          widget: 'UiReveal',
          summary: 'Fades its child in as it scrolls into view: up, down, left, right, blur (also un-blurs) or scale. threshold of it must be on screen (the bottom 8% of the screen does not count). With once off it hides again on leaving. Under reduced motion it still fades in, but only from a 6px lift; with the library\'s animations off it just shows.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            for (final m in UiRevealMode.values)
              UiReveal(
                mode: m,
                once: false,
                child: Container(
                  padding: EdgeInsets.all(t.space4),
                  decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
                  child: UiText('mode: ${m.name}'),
                ),
              ),
          ]),
          code: 'UiReveal(mode: UiRevealMode.blur, delay: const Duration(milliseconds: 120), child: card)',
          api: const [
            ApiRow('mode', 'UiRevealMode', 'up, down, left, right, blur, scale.', def: 'up'),
            ApiRow('delay', 'Duration', 'Before it starts.', def: '0'),
            ApiRow('threshold', 'double', 'Share that must be visible.', def: '0.18'),
            ApiRow('once', 'bool', 'Stay shown after the first reveal.', def: 'true'),
            ApiRow('duration', 'Duration', 'The fade.', def: '900ms'),
          ],
        ),
        DocSection(
          name: 'Split text',
          widget: 'UiSplitText',
          summary: 'A headline whose letters rise in one after another. Words never break, so it still wraps between words. Screen readers hear the whole text once. Under reduced motion it plays as a fade with a small lift and no rotation.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            UiSplitText('Made to move', key: ValueKey(_splitRun), style: context.uiText.h1),
            UiButton(label: 'Play again', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _splitRun++)),
          ]),
          code: "UiSplitText('Mohamed', style: context.uiText.h1)",
          api: const [
            ApiRow('text', 'String', 'The words.'),
            ApiRow('style', 'TextStyle?', 'Merged over the surrounding style.'),
            ApiRow('stagger / base / duration', 'Duration', 'Between letters, before the first, per letter.', def: '35 / 120 / 900 ms'),
          ],
        ),
        DocSection(
          name: 'Marquee',
          widget: 'UiMarquee',
          summary: 'An endless sideways scroll of text with faded edges. Alternate items step back in colour, not opacity, so they keep their contrast. It pauses while pressed (or hovered) and stands still under reduced motion. The separator (a drawn sparkle) and the loop\'s copy are hidden from screen readers.',
          demo: const UiMarquee(items: ['Design', 'Build', 'Ship', 'Measure', 'Repeat'], duration: Duration(seconds: 20)),
          code: "UiMarquee(items: const ['Design', 'Build', 'Ship'], duration: const Duration(seconds: 38))",
          api: const [
            ApiRow('items', 'List<String>', 'The words.'),
            ApiRow('duration', 'Duration', 'One loop.', def: '38s'),
            ApiRow('gap', 'double', 'Between items.', def: '48'),
            ApiRow('reverse', 'bool', 'Scroll to the right.', def: 'false'),
            ApiRow('separator', 'Widget?', 'Defaults to a UiSparkle.'),
          ],
        ),
        DocSection(
          name: 'Drift row',
          widget: 'UiDriftRow',
          summary: 'A rail that drifts on its own (to a random side by default, ping-ponging at the ends) and stays scrollable. It pauses while hovered, while focus is inside and after any touch or scroll, resuming resumeDelay after the last one. Under reduced motion it does not drift but still scrolls. With interactive off it is a passive display.',
          demo: SizedBox(
            height: 110,
            child: UiDriftRow(gap: 16, children: [
              for (var i = 1; i <= 8; i++) _card(context, 'Card $i', 'Swipe me, or wait.'),
            ]),
          ),
          code: 'UiDriftRow(speed: 26, gap: 16, children: cards)',
          api: const [
            ApiRow('speed', 'double', 'px per second.', def: '26'),
            ApiRow('direction', 'UiDriftDirection', 'auto, left, right.', def: 'auto'),
            ApiRow('gap', 'double', 'Between children.', def: '24'),
            ApiRow('pauseOnHover', 'bool', 'Stop under a mouse.', def: 'true'),
            ApiRow('resumeDelay', 'Duration', 'Stillness before it drifts again.', def: '1800ms'),
            ApiRow('fade', 'bool', 'Fade the edges when it overflows.', def: 'true'),
            ApiRow('interactive', 'bool', 'False: drifts but ignores touches.', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Section label',
          widget: 'UiSectionLabel',
          summary: 'An editorial mono section marker, e.g. [ 00 · INDEX ]. The index and its dot are left out when index is empty.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: const [
            UiSectionLabel(index: '00', label: 'Index'),
            UiSectionLabel(label: 'Work'),
          ]),
          code: "UiSectionLabel(index: '01', label: 'Work')",
          api: const [
            ApiRow('label', 'String', 'The section name.'),
            ApiRow('index', 'String', 'Optional number.', def: "''"),
          ],
        ),
        DocSection(
          name: 'Glyph field',
          widget: 'UiGlyphField',
          summary: 'A backdrop of flickering glyphs lit by a drifting field of light, tinted from dim through mid to bright (the Dark Orange brand colours, or the theme\'s primary and accent). Put it in a Stack under content; it ignores touches and screen readers. Under reduced motion it draws one still frame.',
          demo: ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusLg),
            child: SizedBox(
              height: 200,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: t.surface)),
                const Positioned.fill(child: UiGlyphField()),
                const Center(child: UiText('Backdrop', variant: UiTextVariant.h2)),
              ]),
            ),
          ),
          code: "Stack(children: [\n  const Positioned.fill(child: UiGlyphField(chars: '01', cell: 16)),\n  content,\n])",
          api: const [
            ApiRow('opacity', 'double', 'Overall strength.', def: '0.55'),
            ApiRow('chars', 'String', 'Glyphs to draw.', def: "'01'"),
            ApiRow('cell', 'double', 'Grid cell size.', def: '16'),
            ApiRow('speed', 'double', 'Drift speed.', def: '1'),
            ApiRow('colors', '(Color, Color, Color)?', 'Dim, mid, bright.'),
          ],
        ),
        DocSection(
          name: 'Grain & scroll progress',
          widget: 'UiGrain · UiScrollProgress',
          summary: 'UiGrain is a film-grain overlay for the top of a Stack over the app; it ignores touches and is hidden under reduced motion. UiScrollProgress wraps a scroll view and draws a 2px bar along its top that fills with the brand gradient as it scrolls; it is decorative and hidden from screen readers.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: SizedBox(
                height: 180,
                child: Stack(children: [
                  UiScrollProgress(
                    child: ListView(padding: EdgeInsets.all(t.space4), children: [
                      for (var i = 1; i <= 20; i++) Padding(padding: EdgeInsets.symmetric(vertical: t.space1), child: UiText('Paragraph $i of a long article.')),
                    ]),
                  ),
                  if (_grain) const Positioned.fill(child: UiGrain(opacity: 0.12)),
                ]),
              ),
            ),
            Align(alignment: Alignment.centerLeft, child: UiButton(label: _grain ? 'Hide grain' : 'Show grain', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _grain = !_grain))),
          ]),
          code: 'Stack(children: [\n  UiScrollProgress(child: articleListView),\n  const Positioned.fill(child: UiGrain()),\n])',
          api: const [
            ApiRow('UiGrain.opacity', 'double', 'Strength.', def: '0.06'),
            ApiRow('UiScrollProgress.child', 'Widget', 'The scroll view it tracks.'),
          ],
        ),
        DocSection(
          name: 'Intro loader',
          widget: 'UiIntroLoader',
          summary: 'A full-screen veil with a logo over a progress line that fills for duration, then fades and lifts away and calls onDone. Setting open false removes it at once. Under reduced motion it holds for a third of the time and fades without the lift. Announced as "Loading…".',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: SizedBox(
                height: 160,
                child: Stack(children: [
                  Positioned.fill(child: Center(child: UiText(_introDone ? 'The page' : '', variant: UiTextVariant.h3))),
                  Positioned.fill(
                    child: UiIntroLoader(
                      key: ValueKey(_introRun),
                      onDone: () => setState(() => _introDone = true),
                      child: const UiText('zouriel', variant: UiTextVariant.h2),
                    ),
                  ),
                ]),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(label: 'Replay', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() {
                _introRun++;
                _introDone = false;
              })),
            ),
          ]),
          code: 'Stack(children: [\n  app,\n  UiIntroLoader(child: logo, onDone: () => ...),\n])',
          api: const [
            ApiRow('child', 'Widget?', 'Logo or wordmark.'),
            ApiRow('duration', 'Duration', 'How long it holds.', def: '1400ms'),
            ApiRow('open', 'bool', 'False removes it at once.', def: 'true'),
            ApiRow('onDone', 'VoidCallback?', 'After it has gone.'),
          ],
        ),
        DocSection(
          name: 'Press tilt',
          widget: 'UiMagnetic',
          summary: 'The web\'s magnetic pull, adapted for touch: the child tilts toward the finger while pressed and springs back on release (a phone has no cursor to follow). With a mouse it drifts toward the pointer while hovered. Off under reduced motion. Taps still reach the child.',
          demo: Center(
            child: UiMagnetic(
              strength: 0.6,
              child: Container(
                width: 220,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: t.gradientBrand.toGradient(), borderRadius: BorderRadius.circular(t.radiusLg), boxShadow: t.shadow2),
                child: UiText('Press and hold', color: t.primaryContrast, variant: UiTextVariant.h5),
              ),
            ),
          ),
          code: 'UiMagnetic(strength: 0.35, child: card)',
          api: const [
            ApiRow('strength', 'double', 'How far it follows (0–1).', def: '0.35'),
            ApiRow('maxTilt', 'double', 'Steepest tilt at full strength, degrees.', def: '10'),
          ],
        ),
      ],
    );
  }
}
