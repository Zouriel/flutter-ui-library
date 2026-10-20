import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
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
  int _sunRun = 0;
  int _tideRun = 0;

  /// A rounded Maldives island for the sea demos, whatever the page theme.
  Widget _island(BuildContext context, double height, List<Widget> layers) {
    final t = context.ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radiusLg),
      child: UiThemeScope(theme: UiThemeName.maldives, child: SizedBox(height: height, child: Stack(children: layers))),
    );
  }

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
      lead: 'Reveal, split text, marquee, drift, glyph field, grain, intro loader, scroll progress, press tilt and the section label, plus the sea backdrops of the Maldives theme (shown in Maldives islands whatever the app theme). Every effect follows the OS "remove animations" setting: entrances calm down, loops stand still, textures go.',
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
          summary: 'A section marker above a heading. eyebrow is a short accent bar and the label in small caps, in the theme\'s own font, with the index in the primary colour; bracket is the editorial mono marker made for Dark Orange, [ 00 · INDEX ]. auto (the default) picks bracket on Dark Orange and eyebrow everywhere else. The accent is the theme\'s sectionLabelBracket: its primary by default, the warm accent in Winter, blood red in Dark Orange, coral in Maldives. The index is left out when empty.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: const [
            UiSectionLabel(index: '00', label: 'Index'),
            UiSectionLabel(index: '01', label: 'Eyebrow', variant: UiSectionLabelVariant.eyebrow),
            UiSectionLabel(index: '02', label: 'Bracket', variant: UiSectionLabelVariant.bracket),
          ]),
          code: "UiSectionLabel(index: '01', label: 'Work')\nUiSectionLabel(label: 'Work', variant: UiSectionLabelVariant.bracket)",
          shapes: 'enum UiSectionLabelVariant { auto, bracket, eyebrow }',
          api: const [
            ApiRow('label', 'String', 'The section name.'),
            ApiRow('index', 'String', 'Optional number.', def: "''"),
            ApiRow('variant', 'UiSectionLabelVariant', 'bracket on Dark Orange and eyebrow elsewhere, or force one.', def: 'auto'),
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
                const Positioned.fill(child: UiGlyphField(opacity: 0.9)),
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
            Container(
              height: 180,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: Stack(children: [
                UiScrollProgress(
                  child: ListView(padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space8), children: [
                    for (var i = 1; i <= 20; i++) Padding(padding: EdgeInsets.symmetric(vertical: t.space1), child: UiText('Paragraph $i of a long article.')),
                  ]),
                ),
                // Fade the cut-off line at the bottom so the box reads as scrollable rather than clipped.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: t.space8,
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.surface.withValues(alpha: 0), t.surface]))),
                  ),
                ),
                if (_grain) const Positioned.fill(child: UiGrain(opacity: 0.12)),
              ]),
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
        DocSection(
          name: 'Wave footer',
          widget: 'UiWaveFooter',
          summary: 'Two or three stacked wave bands along the bottom of the space it is given (in a Stack, as Positioned.fill), in the theme\'s Lagoon (secondary in themes without one). Each band drifts sideways on its own slow loop, alternating direction (the tide: 30, 38 and 46 seconds). Decorative: it ignores touches and screen readers. The drift stops under reduced motion and with the library\'s animations off.',
          demo: _island(context, 160, const [Positioned.fill(child: UiWaveFooter(height: 110, opacity: 0.6))]),
          code: 'Stack(children: [\n  content,\n  const Positioned.fill(child: UiWaveFooter(layers: 3, height: 120, opacity: 0.5)),\n])',
          api: const [
            ApiRow('layers', 'int (2 | 3)', 'Bands, back to front; 2 drops the middle one.', def: '3'),
            ApiRow('height', 'double', 'Height of the tallest band.', def: '120'),
            ApiRow('opacity', 'double', 'Opacity of the whole footer.', def: '0.5'),
          ],
        ),
        DocSection(
          name: 'Ocean hero',
          widget: 'UiOceanHero',
          summary: 'A sea backdrop behind its child: the theme\'s hero gradient (in Maldives a sand and coral sky over the lagoon into deep teal), an optional photo under it as a wash, and a slow diagonal light sweep every 8 seconds. The photo and sweep are decorative; the sweep stops under reduced motion or with animations off. With fill it expands to the space it is given.',
          demo: _island(context, 220, [
            Positioned.fill(
              child: UiOceanHero(
                fill: true,
                child: Padding(
                  padding: EdgeInsets.all(t.space6),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Builder(builder: (context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space1, children: [
                      Text('Find Doctor', style: context.uiText.h2.copyWith(color: context.ui.primaryContrast)),
                      Text('CARE, CLOSE TO HOME', style: context.uiText.caption.copyWith(color: context.ui.primaryContrast, letterSpacing: context.ui.trackingWide * context.ui.fontSizeSm)),
                    ])),
                  ),
                ),
              ),
            ),
          ]),
          code: 'UiOceanHero(src: const AssetImage(\'beach.jpg\'), child: Text(\'Find a doctor\'))',
          api: const [
            ApiRow('child', 'Widget?', 'The hero content, drawn above the sky.'),
            ApiRow('src', 'ImageProvider?', 'Optional photo under the gradient. Decorative.'),
            ApiRow('shimmer', 'bool', 'The slow light sweep.', def: 'true'),
            ApiRow('fill', 'bool', 'Expand to the space given instead of sizing to the child.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Coral and palm decor',
          widget: 'UiCoralDecor · UiPalmDecor',
          summary: 'Corner silhouettes: branching coral on a sand mound (Coral and Sand), and two leaning palms (Ocean Deep and Lagoon). corner picks the corner of the space they are given and mirrors the shape to face inward. They float 4px up and down on a 5 second loop, which stops under reduced motion or with animations off. Decorative. The shapes are generated from the Angular library\'s shared SVG sources (tool/gen_sea_shapes.mjs).',
          demo: Wrap(spacing: t.space3, runSpacing: t.space3, children: [
            for (final c in UiDecorCorner.values)
              SizedBox(
                width: 168,
                child: _island(context, 140, [
                  Positioned.fill(child: UiCoralDecor(corner: c, scale: 0.6)),
                  Positioned.fill(child: UiPalmDecor(corner: const {UiDecorCorner.bl: UiDecorCorner.br, UiDecorCorner.br: UiDecorCorner.bl, UiDecorCorner.tl: UiDecorCorner.tr, UiDecorCorner.tr: UiDecorCorner.tl}[c]!, scale: 0.55)),
                  Center(child: UiText(c.name, variant: UiTextVariant.code)),
                ]),
              ),
          ]),
          code: 'Positioned.fill(child: UiCoralDecor(corner: UiDecorCorner.bl, scale: 1, opacity: 0.9))\nPositioned.fill(child: UiPalmDecor(corner: UiDecorCorner.br, scale: 0.8))',
          api: const [
            ApiRow('corner', 'UiDecorCorner', 'bl, br, tl or tr; mirrored to face inward.', def: 'bl'),
            ApiRow('scale', 'double', 'Size multiplier: coral is 160 × 128 at 1, palms 160 × 176.', def: '1'),
            ApiRow('opacity', 'double', 'Opacity of the silhouette.', def: '0.9'),
          ],
        ),
        DocSection(
          name: 'Sunrise',
          widget: 'UiSunrise',
          summary: 'A Coral sun with a soft Sand glow behind a logo, for a splash or empty state. On mount it fades in and rises 12px over twice motionSlow, then idles with a slow glow pulse. Under reduced motion it only fades in and does not pulse; with animations off it simply shows.',
          demo: _island(context, 220, [
            Positioned.fill(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: t.space2, children: [
                UiSunrise(key: ValueKey(_sunRun), size: 96, child: const UiIcon(HugeIcons.strokeRoundedStethoscope02)),
                UiButton(label: 'Replay', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _sunRun++)),
              ]),
            ),
          ]),
          code: 'UiSunrise(size: 120, child: logo)',
          api: const [
            ApiRow('child', 'Widget?', 'The logo, centred on the sun, in the accent contrast colour.'),
            ApiRow('size', 'double', 'Diameter of the sun; the widget is 1.6 times that, for the glow.', def: '120'),
          ],
        ),
        DocSection(
          name: 'Sea surface',
          widget: 'UiSeaSurface',
          summary: 'The whole look in one widget. It scopes a theme to the region (maldives by default, null keeps the surrounding theme) like UiThemeScope, paints its background, and lays the wave footer and any corner decor behind the child.',
          demo: ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusLg),
            child: UiSeaSurface(
              coral: UiDecorCorner.bl,
              palm: UiDecorCorner.br,
              decorScale: 0.6,
              waveHeight: 90,
              child: Builder(builder: (context) => Padding(
                padding: EdgeInsets.fromLTRB(context.ui.space6, context.ui.space8, context.ui.space6, context.ui.space20),
                child: Column(spacing: context.ui.space3, children: [
                  const UiText('Book a visit', variant: UiTextVariant.h3),
                  const UiText('Waves along the bottom, coral and palms in the corners, Maldives tokens inside.', variant: UiTextVariant.caption, textAlign: TextAlign.center),
                  UiButton(label: 'Get guidance', variant: UiButtonVariant.accent, onPressed: () {}),
                ]),
              )),
            ),
          ),
          code: 'UiSeaSurface(\n  coral: UiDecorCorner.bl,\n  palm: UiDecorCorner.br,\n  child: content,\n)',
          api: const [
            ApiRow('child', 'Widget', 'The region content, above the backdrop.'),
            ApiRow('theme', 'UiThemeName?', 'Theme scoped to the region (maldivesDark for the night sea); null keeps the surrounding theme.', def: 'maldives'),
            ApiRow('waves', 'bool', 'Show the wave footer.', def: 'true'),
            ApiRow('waveLayers', 'int', 'Wave bands.', def: '3'),
            ApiRow('waveHeight', 'double', 'Wave footer height.', def: '120'),
            ApiRow('waveOpacity', 'double', 'Wave footer opacity.', def: '0.5'),
            ApiRow('coral', 'UiDecorCorner?', 'Corner for the coral, or none.'),
            ApiRow('palm', 'UiDecorCorner?', 'Corner for the palms, or none.'),
            ApiRow('decorScale', 'double', 'Scale of both decor silhouettes.', def: '1'),
          ],
        ),
        DocSection(
          name: 'Tide',
          widget: 'UiTide · UiPulse · UiGradientText · UiGlow',
          summary: 'UiTide is a staggered entrance for lists and cards: each item fades in and slides up 8px, starting delay + index × step after it is built (the web [uiTide]). Reduced motion turns it into a plain fade; animations off skips it. UiPulse is the slow glow pulse for a working or AI-thinking mark (.ui-pulse). UiGradientText and UiGlow are the .ui-gradient-text and .ui-glow classes; in Maldives the gradient ebbs like the tide and the glow shimmers.',
          demo: ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusLg),
            child: UiThemeScope(
              theme: UiThemeName.maldives,
              child: Builder(builder: (context) => Padding(
                padding: EdgeInsets.all(context.ui.space4),
                child: Column(key: ValueKey(_tideRun), crossAxisAlignment: CrossAxisAlignment.stretch, spacing: context.ui.space2, children: [
                  for (final (i, d) in const ['Dr. Aisha Rasheed · Cardiology', 'Dr. Ibrahim Naseem · Paediatrics', 'Dr. Mariyam Shifa · Dermatology'].indexed)
                    UiTide(index: i, step: const Duration(milliseconds: 80), child: UiCard(padding: UiSize.sm, child: Text(d))),
                  Wrap(spacing: context.ui.space3, runSpacing: context.ui.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01, color: context.ui.secondary)),
                    UiGlow(child: UiGradientText('Find Doctor', style: context.uiText.h4)),
                    UiButton(label: 'Replay', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _tideRun++)),
                  ]),
                ]),
              )),
            ),
          ),
          code: 'for (final (i, d) in doctors.indexed) UiTide(index: i, child: DoctorCard(d)),\nUiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01)),',
          api: const [
            ApiRow('UiTide index', 'int', 'The item\'s position in its list.', def: '0'),
            ApiRow('UiTide delay', 'Duration', 'Before the first item.', def: '0'),
            ApiRow('UiTide step', 'Duration', 'Extra delay per index.', def: '60ms'),
            ApiRow('UiGradientText text', 'String', 'Filled with the brand gradient.'),
            ApiRow('UiGlow child', 'Widget', 'Its text gets the theme glow.'),
          ],
        ),
      ],
    );
  }
}
