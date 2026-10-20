import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// The Find Doctor reference screens, rebuilt from library widgets inside UiSeaSurface (the twin of
/// the web showcase's Find Doctor page). Opening it switches the app to Maldives, and back on leaving;
/// the screens follow whatever theme is picked meanwhile.
class FindDoctorPage extends StatefulWidget {
  const FindDoctorPage({super.key});

  @override
  State<FindDoctorPage> createState() => _FindDoctorPageState();
}

class _FindDoctorPageState extends State<FindDoctorPage> {
  UiThemeController? _controller;
  UiThemeName? _previous;

  @override
  void initState() {
    super.initState();
    // After the first frame: switching rebuilds the app above this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _controller = mounted ? UiThemeController.maybeOf(context) : null;
      if (c == null) return;
      _previous = c.theme;
      // Already on a Maldives variant (day or night): keep it.
      if (c.theme != UiThemeName.maldives && c.theme != UiThemeName.maldivesDark) c.set(UiThemeName.maldives);
    });
  }

  @override
  void dispose() {
    final c = _controller, previous = _previous;
    // Only undo our own switch (a theme picked while here stays), and not mid-teardown.
    if (c != null && previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.theme == UiThemeName.maldives) c.set(previous);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const _FindDoctorScreens();
}

class _FindDoctorScreens extends StatelessWidget {
  const _FindDoctorScreens();

  static const _doctors = [
    ('Dr. Aisha Rasheed', 'Aisha Rasheed', 'Cardiologist', 'Malé', '4.9'),
    ('Dr. Ibrahim Naseem', 'Ibrahim Naseem', 'Cardiologist', 'Hulhumalé', '4.8'),
    ('Dr. Mariyam Shifa', 'Mariyam Shifa', 'Cardiologist', 'Addu City', '4.7'),
  ];

  static const _nav = [
    UiBottomNavItem(label: 'Home', value: 'home', icon: HugeIcons.strokeRoundedHome01),
    UiBottomNavItem(label: 'Search', value: 'search', icon: HugeIcons.strokeRoundedSearch01),
    UiBottomNavItem(label: 'Visits', value: 'visits', icon: HugeIcons.strokeRoundedCalendar03),
    UiBottomNavItem(label: 'Profile', value: 'profile', icon: HugeIcons.strokeRoundedUser03),
  ];

  @override
  Widget build(BuildContext context) {
    return DocPage(
      eyebrow: 'Themes',
      title: 'Find Doctor',
      lead: 'The Maldives theme in use: the five Find Doctor app screens rebuilt from existing widgets inside UiSeaSurface. White cards on Mist, Ocean Deep ink and buttons, a Coral call to action, Poppins, and the sea backdrops. Opening this page switches the app to Maldives (and back when you leave); the screens follow whatever theme is picked while you are here.',
      children: [
        DocSection(
          name: 'Splash',
          widget: 'UiOceanHero · UiSunrise',
          summary: 'An ocean hero with the sunrise and the wordmark, over a sheet holding the two first actions. The sunrise rises once; the light sweeps across the sky every 8 seconds.',
          demo: _Phone(child: UiSeaSurface(theme: null, waveHeight: 70, waveOpacity: 0.4, child: Builder(builder: _splash))),
          code: 'UiSeaSurface(child: Column(children: [\n  UiOceanHero(child: UiSunrise(child: logo)),\n  UiButton(label: \'Get started\', block: true, size: UiSize.lg, onPressed: start),\n]))',
        ),
        DocSection(
          name: 'Home',
          widget: 'UiSearchInput · UiCard · UiBottomNav',
          summary: 'Greeting, search, the coral guidance card (the accent button), specialty chips and the top doctors as white list cards with a bookmark and a chevron, entering one after another with UiTide. The bottom navigation marks the current page in Ocean Deep.',
          demo: _Phone(child: UiSeaSurface(theme: null, waves: false, child: Builder(builder: _home))),
          code: 'for (final (i, d) in doctors.indexed) UiTide(index: i, child: UiCard(padding: UiSize.sm, child: DoctorRow(d))),\nUiBottomNav(items: nav, active: \'home\')',
        ),
        DocSection(
          name: 'Doctor profile',
          widget: 'UiAvatar · UiTabs · UiButton',
          summary: 'The doctor over the waves, three facts, tabs underlined in Ocean Deep, and the full-width booking button.',
          demo: _Phone(child: UiSeaSurface(theme: null, waveHeight: 80, child: Builder(builder: _profile))),
          code: 'UiTabs(tabs: [UiTab(label: \'About\', child: about), UiTab(label: \'Reviews\', child: reviews)])\nUiButton(label: \'Book appointment\', size: UiSize.lg, block: true, onPressed: book)',
        ),
        DocSection(
          name: 'AI symptom checker',
          widget: 'UiTextarea · UiPulse',
          summary: 'A short conversation: the assistant\'s mark pulses while it is thinking (UiPulse), quick answers are chips, and the reply box is a one-line textarea that grows with the text, with a round send button level with its last line. Coral decor in the corner; the waves stay low.',
          demo: _Phone(
            child: UiSeaSurface(theme: null, coral: UiDecorCorner.br, decorScale: 0.5, waveLayers: 2, waveHeight: 60, waveOpacity: 0.35, child: Builder(builder: _checker)),
          ),
          code: 'UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01))\nUiTextarea(rows: 1, autosize: true, maxRows: 4, placeholder: \'Describe your symptoms\')\nUiIconButton(icon: UiIcon(HugeIcons.strokeRoundedSent), label: \'Send\', size: UiSize.lg, round: true, onPressed: send)',
        ),
        DocSection(
          name: 'Search results',
          widget: 'UiSearchInput · UiChip · UiTide',
          summary: 'The query, filter chips and a count, then the matching doctors entering with UiTide, and the bottom navigation on Search.',
          demo: _Phone(child: UiSeaSurface(theme: null, waves: false, child: Builder(builder: _results))),
          code: 'UiSearchInput(value: query, onChanged: search)\nfor (final (i, d) in results.indexed) UiTide(index: i, child: DoctorCard(d))',
        ),
      ],
    );
  }

  static Widget _splash(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: UiOceanHero(
          fill: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(t.space4, t.space4, t.space4, t.space8),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const UiSunrise(size: 80, child: UiIcon(HugeIcons.strokeRoundedStethoscope02)),
              // Over the deep water: Sand is a light ink there in maldives and maldivesDark alike
              // (primaryContrast is the night canvas colour in the dark one).
              Column(spacing: t.space1, children: [
                Text('Find Doctor', style: context.uiText.h2.copyWith(color: t.sand ?? t.primaryContrast, fontWeight: FontWeight.w600)),
                Text('CARE ACROSS THE ATOLLS', style: context.uiText.caption.copyWith(color: t.sand ?? t.primaryContrast, letterSpacing: t.trackingWide * t.fontSizeSm)),
              ]),
            ]),
          ),
        ),
      ),
      // The sheet takes its natural height and overlaps the hero by space6; the hero takes the rest.
      Transform.translate(
          offset: Offset(0, -t.space6),
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg))),
            child: Padding(
              padding: EdgeInsets.fromLTRB(t.space4, t.space6, t.space4, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
                const UiText('Your health, close to home', variant: UiTextVariant.h3),
                UiText('Find and book doctors near you, and get guidance when you are not sure who to see.', color: t.textMuted),
                UiButton(label: 'Get started', size: UiSize.lg, block: true, onPressed: () {}),
                UiButton(label: 'I already have an account', size: UiSize.lg, variant: UiButtonVariant.ghost, block: true, onPressed: () {}),
                SizedBox(height: t.space12),
              ]),
            ),
          ),
        ),
    ]);
  }

  static Widget _doctorCard(BuildContext context, int i, (String, String, String, String, String) d) {
    final t = context.ui;
    return UiTide(
      index: i,
      delay: const Duration(milliseconds: 80),
      child: UiCard(
        padding: UiSize.sm,
        child: Row(spacing: t.space3, children: [
          UiAvatar(name: d.$2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              UiText(d.$1, variant: UiTextVariant.label),
              UiText('${d.$3} · ${d.$4}', variant: UiTextVariant.caption),
              _stars(context, d.$5),
            ]),
          ),
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedBookmark02), label: 'Save ${d.$1}', size: UiSize.sm, onPressed: () {}),
          UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 18, color: t.textMuted),
        ]),
      ),
    );
  }

  static Widget _stars(BuildContext context, String rating) {
    final t = context.ui;
    return Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
      UiIcon(HugeIcons.strokeRoundedStar, size: 14, color: t.ratingFill),
      Text(rating, style: context.uiText.label),
    ]);
  }

  static Widget _home(BuildContext context) {
    final t = context.ui;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.space4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Row(spacing: t.space2, children: [
              const UiAvatar(name: 'Aminath Zahir'),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                UiText('Good morning', variant: UiTextVariant.caption),
                UiText('Aminath', variant: UiTextVariant.h4),
              ])),
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedNotification01), label: 'Notifications', onPressed: () {}),
            ]),
            const UiSearchInput(placeholder: 'Search doctors, specialties', label: 'Search doctors'),
            DecoratedBox(
              decoration: BoxDecoration(color: t.accentSubtle, borderRadius: BorderRadius.circular(t.radius)),
              child: Padding(
                padding: EdgeInsets.all(t.space3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
                  Row(spacing: t.space3, children: [
                    UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01, size: 28, color: t.secondary)),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      UiText('Not sure who to see?', variant: UiTextVariant.label),
                      UiText('Describe how you feel and we will suggest a specialist.', variant: UiTextVariant.caption),
                    ])),
                  ]),
                  UiButton(label: 'Get guidance', variant: UiButtonVariant.accent, block: true, onPressed: () {}),
                ]),
              ),
            ),
            const UiText('Specialties', variant: UiTextVariant.h5),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              for (final s in const ['Cardiology', 'Paediatrics', 'Dermatology', 'Dental', 'ENT']) UiChip(label: s),
            ]),
            const UiText('Top doctors', variant: UiTextVariant.h5),
            for (final (i, d) in _doctors.indexed) _doctorCard(context, i, d),
          ]),
        ),
      ),
      Padding(padding: EdgeInsets.fromLTRB(t.space3, 0, t.space3, t.space3), child: const UiBottomNav(items: _nav, active: 'home', label: 'Main', safeArea: false)),
    ]);
  }

  static Widget _profile(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: EdgeInsets.all(t.space4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        Row(children: [
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01), label: 'Back', onPressed: () {}),
          const Spacer(),
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedFavourite), label: 'Favourite', iconColor: t.danger, onPressed: () {}),
        ]),
        Column(spacing: t.space1, children: [
          const UiAvatar(name: 'Aisha Rasheed', size: UiSize.lg),
          const UiText('Dr. Aisha Rasheed', variant: UiTextVariant.h3),
          const UiText('Cardiologist', variant: UiTextVariant.caption),
          Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
            UiIcon(HugeIcons.strokeRoundedLocation01, size: 14, color: t.textMuted),
            const UiText('IGMH, Malé', variant: UiTextVariant.caption),
          ]),
        ]),
        UiCard(
          padding: UiSize.sm,
          child: Row(children: [
            for (final (v, l) in const [('1.2k', 'Patients'), ('12 yrs', 'Experience'), ('', 'Rating')])
              Expanded(child: Column(children: [
                if (v.isEmpty) _stars(context, '4.9') else UiText(v, variant: UiTextVariant.label),
                UiText(l, variant: UiTextVariant.caption),
              ])),
          ]),
        ),
        Expanded(
          child: UiTabs(label: 'Doctor details', tabs: [
            UiTab(label: 'About', child: Padding(padding: EdgeInsets.only(top: t.space2), child: UiText('Consultant cardiologist with a focus on prevention and heart rhythm. Speaks Dhivehi and English.', color: t.textMuted))),
            UiTab(label: 'Reviews', child: Padding(padding: EdgeInsets.only(top: t.space2), child: UiText('“Took the time to explain everything.” · 214 reviews', color: t.textMuted))),
            UiTab(label: 'Location', child: Padding(padding: EdgeInsets.only(top: t.space2), child: UiText('Indira Gandhi Memorial Hospital, Kanbaa Aisa Rani Hingun, Malé.', color: t.textMuted))),
          ]),
        ),
        UiButton(label: 'Book appointment', icon: const UiIcon(HugeIcons.strokeRoundedCalendar03), size: UiSize.lg, block: true, onPressed: () {}),
      ]),
    );
  }

  static Widget _bubble(BuildContext context, String text, {bool me = false, Widget? leading}) {
    final t = context.ui;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: me ? t.primary : t.surfaceRaised,
            boxShadow: me ? const [] : t.shadow1,
            borderRadius: BorderRadius.circular(t.radiusLg).copyWith(
              bottomLeft: me ? null : Radius.circular(t.radiusXs),
              bottomRight: me ? Radius.circular(t.radiusXs) : null,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
              ?leading,
              Flexible(child: Text(text, style: context.uiText.caption.copyWith(color: me ? t.primaryContrast : (leading != null ? t.textMuted : t.text), height: 1.45))),
            ]),
          ),
        ),
      ),
    );
  }

  static Widget _checker(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space4, t.space4, t.space4, t.space12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        Row(spacing: t.space2, children: [
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01), label: 'Back', onPressed: () {}),
          const Expanded(child: UiText('Symptom checker', variant: UiTextVariant.h4)),
          UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01, size: 22, color: t.secondary)),
        ]),
        UiTide(child: _bubble(context, 'Hi Aminath. What is bothering you today?')),
        UiTide(index: 1, child: _bubble(context, 'I have had a headache and a mild fever since yesterday.', me: true)),
        UiTide(index: 2, child: _bubble(context, 'Thanks. Do you also have a stiff neck or a rash?')),
        UiTide(index: 3, child: Wrap(spacing: t.space2, children: const [UiChip(label: 'No'), UiChip(label: 'Stiff neck'), UiChip(label: 'Rash')])),
        UiTide(index: 4, child: _bubble(context, 'Thinking…', leading: UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01, size: 16, color: t.textMuted)))),
        const Spacer(),
        // A chat composer: the box grows with the text and the send button stays level with its last
        // line. On touch the button sits centred in a 48dp target, so drop it by that padding to
        // line its visible edge up with the box.
        Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: t.space2, children: [
          const Expanded(child: UiTextarea(rows: 1, autosize: true, maxRows: 4, placeholder: 'Describe your symptoms', semanticLabel: 'Describe your symptoms')),
          Transform.translate(
            offset: Offset(0, uiTouchPlatform(context) ? (uiMinTouchTarget - t.sizeLg) / 2 : 0),
            child: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSent), label: 'Send', size: UiSize.lg, round: true, variant: UiButtonVariant.primary, onPressed: () {}),
          ),
        ]),
        const UiText('Guidance only, not a diagnosis. In an emergency call 102.', variant: UiTextVariant.caption, textAlign: TextAlign.center),
      ]),
    );
  }

  static Widget _results(BuildContext context) {
    final t = context.ui;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.space4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Row(spacing: t.space2, children: [
              const Expanded(child: UiSearchInput(value: 'Cardiologist', label: 'Search doctors')),
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedFilterHorizontal), label: 'Filters', variant: UiButtonVariant.outline, onPressed: () {}),
            ]),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: const [
              UiChip(label: 'Malé', tone: UiStatus.primary),
              UiChip(label: 'Available today'),
              UiChip(label: 'Video visit'),
            ]),
            UiText('${_doctors.length} cardiologists near you', variant: UiTextVariant.caption),
            for (final (i, d) in _doctors.indexed) _doctorCard(context, i, d),
          ]),
        ),
      ),
      Padding(padding: EdgeInsets.fromLTRB(t.space3, 0, t.space3, t.space3), child: const UiBottomNav(items: _nav, active: 'search', label: 'Main', safeArea: false)),
    ]);
  }
}

/// A phone-sized frame for one screen, centred.
class _Phone extends StatelessWidget {
  const _Phone({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          height: 720,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusLg), boxShadow: t.shadow2),
            child: ClipRRect(borderRadius: BorderRadius.circular(t.radiusLg), child: child),
          ),
        ),
      ),
    );
  }
}
