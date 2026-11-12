import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

const _tour = UiTourSpec('tour.welcome', [
  UiTourStep('demo.feed', 'Your events and the people in them show up here.'),
  UiTourStep('demo.inbox', 'Invitations sent to you land here.'),
  UiTourStep('demo.new', 'Start an event: pick a design, add guests, send.'),
  UiTourStep('demo.me', 'Events you host, your plan and settings.'),
]);

const _checklist = [
  UiChecklistItem(id: 'name', label: 'Add your name and photo', done: true),
  UiChecklistItem(id: 'event', label: 'Start an event'),
  UiChecklistItem(id: 'guests', label: 'Add your guests'),
  UiChecklistItem(id: 'send', label: 'Send it or share the link'),
  UiChecklistItem(id: 'photo', label: 'Get your first photo', description: 'Guests add theirs with the QR code'),
];

/// The Guidance page: tour, offer card, checklist, empty state with art and starters, starter
/// card, the guidance controller and the one-off hint (the web guidance page).
class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  // The page's own guidance controller, in memory: reopen the page (or press Show tips again) to start over.
  final UiGuidance _guidance = UiGuidance(UiMemoryGuidanceStore());
  UiTourOutcome? _tourOutcome;
  bool _offerOpen = true;
  List<UiChecklistItem> _items = _checklist;
  final List<String> _log = [];
  int _tipN = 0;
  bool _hintShown = false;
  bool _hintReported = false;
  UiTourOutcome? _hintDone;

  @override
  void dispose() {
    UiTour.stop();
    _guidance.dispose();
    super.dispose();
  }

  Future<void> _startTour(BuildContext context) async {
    final o = await UiTour.start(context, _tour);
    if (mounted) setState(() => _tourOutcome = o);
  }

  Future<void> _request(String id, UiGuidanceKind kind) async {
    // A stand-in for a real tip: "shown" for a moment, then closed.
    final o = await _guidance.requestTip(
      id,
      () => Future.delayed(const Duration(milliseconds: 400), () => kind == UiGuidanceKind.tour ? UiTourOutcome.finished : UiTourOutcome.closed),
      kind: kind,
    );
    if (!mounted) return;
    setState(() {
      _log.add('$id (${kind.name}): ${o?.name ?? 'refused'}');
      if (_log.length > 6) _log.removeAt(0);
    });
  }

  Future<void> _resetGuidance() async {
    await _guidance.reset();
    if (!mounted) return;
    setState(() {
      _log.add('Show tips again: everything unseen, tips on');
      if (_log.length > 6) _log.removeAt(0);
    });
  }

  Widget _narrow(Widget child) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: child),
      );

  Widget _phone(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    Widget tab(String id, List<List<dynamic>> icon, String label) => Expanded(
          child: UiTourAnchor(
            id: id,
            child: UiInteractive(
              onTap: () {},
              semanticLabel: label,
              excludeChildSemantics: true,
              builder: (context, s) => SizedBox(
                height: 52,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  UiIcon(icon, size: 20, strokeWidth: 1.8, color: t.textSecondary),
                  const SizedBox(height: 2),
                  Text(label, style: ty.caption.copyWith(color: t.textSecondary)),
                ]),
              ),
            ),
          ),
        );
    return Center(
      child: Container(
        width: 360,
        height: 420,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
        child: Column(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
            child: Row(children: [
              Text('invites', style: ty.body.copyWith(fontWeight: FontWeight.w700, color: t.primary)),
              const Spacer(),
              Builder(builder: (context) => UiButton(label: 'Start the tour', size: UiSize.sm, onPressed: () => _startTour(context))),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.all(t.space3), children: [
              if (_tourOutcome != null) Padding(padding: EdgeInsets.only(bottom: t.space3), child: Text('Last tour: ${_tourOutcome!.name}', style: ty.caption)),
              Container(height: 150, decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radius))),
              SizedBox(height: t.space3),
              Container(height: 90, decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radius))),
            ]),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
            child: Row(children: [
              tab('demo.feed', HugeIcons.strokeRoundedHome01, 'Feed'),
              tab('demo.inbox', HugeIcons.strokeRoundedInbox, 'Inbox'),
              tab('demo.new', HugeIcons.strokeRoundedAdd01, 'New'),
              tab('demo.me', HugeIcons.strokeRoundedUser, 'Me'),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    return UiGuidanceScope(
      guidance: _guidance,
      child: DocPage(
        eyebrow: 'Components',
        title: 'Guidance',
        lead: 'Help that shows itself once: a coach-mark tour with a spotlight, a card that offers help, a getting-started checklist, empty pages with a picture and ways to start, and UiGuidance, which decides what may show and remembers what was seen. Coach marks use the primary colour as their fill, so they never pass for the app\'s own controls.',
        children: [
          DocSection(
            name: 'Tour',
            widget: 'UiTourAnchor, UiTour',
            summary: 'Wrap widgets in UiTourAnchor with a shared id, then start a tour from code. The screen dims, a rounded cut-out frames each anchor with a breathing ring, and a bubble beside it shows the text, "2 of 4", Back, Next (Done on the last), Skip and a small Turn off tips. It scrolls each anchor into view first and leaves out steps whose anchor isn\'t laid out (a lazy list\'s unbuilt rows count as missing). It is modal: focus moves to Next and stays in the bubble, Escape closes it, a screen reader hears "Step 2 of 4: text", and focus goes back where it was. With animations off or reduced motion the spotlight jumps instead of gliding. On a phone and a desktop the bubble stays on screen.',
            demo: _phone(context),
            code: '''UiTourAnchor(id: 'nav.feed', child: feedTab)

final outcome = await UiTour.start(context, const UiTourSpec('tour.welcome', [
  UiTourStep('nav.feed', 'Your events and the people in them show up here.'),
  UiTourStep('nav.inbox', 'Invitations sent to you land here.'),
])); // finished | skipped | turnedOff | closed''',
            shapes: '''enum UiTourOutcome { finished, skipped, turnedOff, closed }
UiTourSpec(String id, List<UiTourStep> steps, {UiTourLabels? labels, bool turnOff = true})
UiTourStep(String anchor, String text, {String? title, UiTourPlacement placement = UiTourPlacement.auto})
UiTourLabels({String? back, next, done, skip, turnOff, step})''',
            api: const [
              ApiRow('UiTourAnchor(id:, child:)', 'String', 'The anchor id a step points at (shared with the other app). Several widgets may share one; the first laid out wins.'),
              ApiRow('UiTour.start(context, spec)', 'Future<UiTourOutcome>', 'Runs a tour (1 to 5 steps) in the root overlay. A tour already running ends with closed; no step on screen completes closed at once.'),
              ApiRow('UiTour.stop()', 'void', 'Ends the running tour with closed.'),
              ApiRow('UiTour.active', 'String?', 'The id of the tour on screen.', def: 'null'),
              ApiRow('spec.turnOff', 'bool', 'Show the Turn off tips action.', def: 'true'),
              ApiRow('spec.labels', 'UiTourLabels?', 'Words for this tour; by default the built-in tourBack, tourNext, tourDone, tourSkip, tourStep and tipsOff.', def: 'built-in'),
              ApiRow('step.placement', 'UiTourPlacement', 'The side the bubble prefers (auto: below, else above). It moves to another side, or over the page, when there is no room, and never leaves the screen.', def: 'auto'),
            ],
          ),
          DocSection(
            name: 'Offer card',
            widget: 'UiOfferCard',
            summary: 'A card that offers help, for the top of a feed or list: art, a heading, one line, a main and a quiet button, a close ×, and optionally a small Turn off tips link. It has the coach-mark tint, so it reads as help rather than content. variant: UiOfferVariant.role frames a bigger avatar or cover picture, for "Aisha added you to her event". Fits a 360px phone: the buttons wrap under the text.',
            demo: _narrow(Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
              if (_offerOpen)
                Builder(
                  builder: (context) => UiOfferCard(
                    heading: 'New to invites.blog?',
                    body: 'Take a quick tour.',
                    art: UiIcon(HugeIcons.strokeRoundedSparkles, strokeWidth: 1.8),
                    primaryLabel: 'Show me',
                    onPrimary: () {
                      setState(() => _offerOpen = false);
                      _startTour(context);
                    },
                    secondaryLabel: 'Not now',
                    onSecondary: () => setState(() => _offerOpen = false),
                    onDismiss: () => setState(() => _offerOpen = false),
                    onTipsOff: () => setState(() => _offerOpen = false),
                  ),
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: UiButton(label: 'Show the offer again', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _offerOpen = true)),
                ),
              UiOfferCard(
                variant: UiOfferVariant.role,
                heading: 'Aisha added you to “Our wedding” as a celebrant.',
                body: "You can see who's coming and all the photos.",
                art: SizedBox(width: 56, height: 56, child: CustomPaint(painter: _CoverPainter(t))),
                primaryLabel: 'Open event',
                onPrimary: () {},
                secondaryLabel: 'Show me around',
                onSecondary: () {},
                onDismiss: () {},
              ),
            ])),
            code: '''UiOfferCard(
  heading: 'New to invites.blog?',
  body: 'Take a quick tour.',
  art: UiIcon(HugeIcons.strokeRoundedSparkles),
  primaryLabel: 'Show me', onPrimary: tour,
  secondaryLabel: 'Not now', onSecondary: seen,
  onDismiss: seen,
  onTipsOff: tipsOff,
)''',
            api: const [
              ApiRow('heading', 'String', 'The offer; also names the card.'),
              ApiRow('body', 'String?', 'One line under it.', def: 'null'),
              ApiRow('variant', 'UiOfferVariant', 'standard: a small round icon tile; role: a bigger avatar or cover picture.', def: 'standard'),
              ApiRow('art', 'Widget?', 'An icon, or a picture for the role variant.', def: 'null'),
              ApiRow('primaryLabel / secondaryLabel', 'String?', 'The two buttons; each shows only when given.', def: 'null'),
              ApiRow('tipsOffLabel', 'String?', 'The link\'s words.', def: 'built-in tipsOff'),
              ApiRow('child', 'Widget?', 'Anything else under the body.', def: 'null'),
            ],
            callbacks: const [
              ApiRow('onPrimary / onSecondary', 'VoidCallback?', 'A button was pressed.'),
              ApiRow('onDismiss', 'VoidCallback?', 'Shows the × (named Dismiss); mark the offer seen.'),
              ApiRow('onTipsOff', 'VoidCallback?', 'Shows the small Turn off tips link.'),
            ],
          ),
          DocSection(
            name: 'Checklist',
            widget: 'UiChecklist',
            summary: 'A short getting-started list: title, "2 of 5" and a progress bar, then one row per step with a round check that fills when it\'s done; done rows go quiet. The app sets done (from the account\'s progress), so steps can be finished in any order and the list follows. When every step is done it shows a finished state. Each row is a button; a screen reader hears "Start an event, Not done yet".',
            demo: _narrow(Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
              UiChecklist(
                heading: 'Getting started',
                items: _items,
                onItemTap: (item) => setState(() => _items = [for (final x in _items) x.id == item.id ? UiChecklistItem(id: x.id, label: x.label, description: x.description, done: true) : x]),
                onDismiss: () => setState(() => _items = _checklist),
              ),
              Text('Tap a step to tick it here; the × starts over.', style: ty.caption),
            ])),
            code: '''UiChecklist(
  heading: 'Getting started',
  items: items,
  onItemTap: (item) => open(item.id),
  onDismiss: () => guidance.markSeen(['guide.checklist']),
)''',
            shapes: 'UiChecklistItem({required String id, required String label, String? description, bool done = false})',
            api: const [
              ApiRow('heading', 'String', 'The list title ("Getting started").'),
              ApiRow('items', 'List<UiChecklistItem>', 'The steps; done ones tick and go quiet.', def: '[]'),
              ApiRow('allDoneText', 'String?', 'The finished state\'s words (All set).', def: 'built-in checklistAllDone'),
            ],
            callbacks: const [
              ApiRow('onItemTap', 'ValueChanged<UiChecklistItem>?', 'A row was pressed: open where that step is done.'),
              ApiRow('onDismiss', 'VoidCallback?', 'Shows the ×.'),
            ],
          ),
          DocSection(
            name: 'Empty state with art and starters',
            widget: 'UiEmptyState(art:, starters:)',
            summary: 'An empty page shows a picture of what will fill it (at most 320 x 200, scaled down on a phone) in art, a heading, one line on how it fills, then one to three ways to start in starters: UiStarterCards that stack on a phone and sit two or three across on a wider screen. icon and actions still work.',
            demo: UiEmptyState(
              heading: 'Your feed is quiet',
              description: 'Events you host or are invited to show up here.',
              art: Semantics(
                label: 'An empty feed post',
                image: true,
                child: SizedBox(width: 320, height: 200, child: CustomPaint(painter: _FeedArtPainter(t))),
              ),
              starters: [
                UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedAdd01, strokeWidth: 1.8), heading: 'Start an event', description: 'Pick a design, add guests, send', onTap: () {}),
                UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedView, strokeWidth: 1.8), heading: 'See an example event', description: 'A wedding, filled in', onTap: () {}),
                UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedCalendar03, strokeWidth: 1.8), heading: 'Browse templates', description: 'Designs for every occasion', onTap: () {}),
              ],
            ),
            code: '''UiEmptyState(
  heading: 'Your feed is quiet',
  description: 'Events you host or are invited to show up here.',
  art: SvgPicture.asset('empty-feed-light.svg'),
  starters: [
    UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedAdd01), heading: 'Start an event',
      description: 'Pick a design, add guests, send', onTap: create),
    …
  ],
)''',
            api: const [
              ApiRow('art', 'Widget?', 'A picture of what will fill the page, at most 320 x 200, scaled down keeping its shape.', def: 'null'),
              ApiRow('starters', 'List<Widget>', 'Ways to start: one column on a phone, then two or three across (each at least 200 wide, the grid at most 720), centred.', def: '[]'),
            ],
          ),
          DocSection(
            name: 'Starter card',
            widget: 'UiStarterCard',
            summary: 'One way to start: an icon on a tinted square, a heading and one line, the whole card one button. Made for the empty state\'s starters, and fine on its own.',
            demo: _narrow(UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedUser, strokeWidth: 1.8), heading: 'Add a guest', description: 'One by one, with a name', onTap: () {})),
            code: "UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedUser), heading: 'Add a guest', description: 'One by one, with a name', onTap: add)",
            api: const [
              ApiRow('heading', 'String', 'What it starts.'),
              ApiRow('description', 'String?', 'One line under it.', def: 'null'),
              ApiRow('icon', 'Widget?', 'An icon on a tinted square.', def: 'null'),
              ApiRow('enabled', 'bool', 'Greys the card out.', def: 'true'),
            ],
            callbacks: const [ApiRow('onTap', 'VoidCallback?', 'The card was pressed.')],
          ),
          DocSection(
            name: 'Guidance controller',
            widget: 'UiGuidance, UiGuidanceScope',
            summary: 'Decides what may show and remembers what was seen, the same way on web and Flutter. Give it a store (your server, the device, or both): it never shows anything while tips are off or an id is seen; skipWhen marks an id seen silently (its action is already done); one thing on screen at a time, other requests are refused, not queued; one offer a session; at most 3 new one-off tips a day. Whatever the outcome, the id is seen for good, and Turn off tips turns tips off in the store.',
            demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
              Wrap(spacing: t.space2, runSpacing: t.space2, children: [
                UiButton(label: 'Request the tour', size: UiSize.sm, onPressed: () => _request('tour.welcome', UiGuidanceKind.tour)),
                UiButton(label: 'Request an offer', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _request('offer.welcome', UiGuidanceKind.offer)),
                UiButton(label: 'Request a new tip', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _request('tip.${++_tipN}', UiGuidanceKind.tip)),
                UiButton(label: 'Show tips again', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: _resetGuidance),
              ]),
              Semantics(
                liveRegion: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < _log.length; i++) Text('${i + 1}. ${_log[i]}', style: ty.caption),
                ]),
              ),
            ]),
            code: '''final guidance = UiGuidance(ServerGuidanceStore(api)); // one per app session
UiGuidanceScope(guidance: guidance, child: app)

await guidance.requestTip('tour.welcome', () => UiTour.start(context, tour), kind: UiGuidanceKind.tour);
await guidance.requestTip('tip.feed.templates', showHint, skipWhen: progress.hasEvent);''',
            shapes: '''abstract class UiGuidanceStore {
  FutureOr<bool> tipsOn();
  FutureOr<bool> seen(String id);
  FutureOr<void> markSeen(List<String> ids);
  FutureOr<void> setTipsOn(bool on);
  FutureOr<void> reset();
  FutureOr<int?> readDayCount(String day) => null;      // optional: else kept in memory
  FutureOr<void> writeDayCount(String day, int count) {}
}
enum UiGuidanceKind { tip, offer, tour }   // requestTip / canShow default: tip''',
            api: const [
              ApiRow('UiGuidance(store, {maxTipsPerDay, now})', 'ChangeNotifier', 'One per app session; UiGuidanceScope gives it to the subtree (UiGuidanceScope.maybeOf).', def: 'maxTipsPerDay 3'),
              ApiRow('requestTip(id, show, {skipWhen, kind})', 'Future<UiTourOutcome?>', 'Shows it through show() if the rules allow; null when refused. Marks it seen on any outcome; turnedOff turns tips off.'),
              ApiRow('canShow(id, {skipWhen, kind})', 'Future<bool>', 'The same rules, without showing or changing anything.'),
              ApiRow('markSeen(ids) / isSeen(id)', 'Future', 'For offers whose action happened elsewhere, a checklist closed.'),
              ApiRow('tipsOn() / setTipsOn(on) / reset()', 'Future', 'The Settings switch and Show tips again.'),
              ApiRow('active', 'String?', 'The id on screen (listen to the controller).', def: 'null'),
              ApiRow('UiMemoryGuidanceStore', 'class', 'A store in memory, for tests, demos and a signed-out first run.'),
            ],
          ),
          DocSection(
            name: 'One-off hint',
            widget: 'UiHintOnce',
            summary: 'A UiHint that goes through the nearest UiGuidance: it shows once when is true, if the rules allow, and then never again on this account, however it closed. Placement, duration and the × are UiHint\'s.',
            demo: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (_hintShown)
                UiHintOnce(
                  id: 'tip.demo.settings',
                  message: 'Your plan, sign-in and tips live here.',
                  placement: UiHintPlacement.bottom,
                  onDone: (o) => setState(() {
                    _hintReported = true;
                    _hintDone = o;
                  }),
                  child: UiButton(label: 'Settings', variant: UiButtonVariant.outline, icon: UiIcon(HugeIcons.strokeRoundedSettings02, strokeWidth: 1.8), onPressed: () {}),
                )
              else
                UiButton(label: 'Open the screen', size: UiSize.sm, onPressed: () => setState(() => _hintShown = true)),
              if (_hintShown) UiButton(label: 'Leave the screen', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _hintShown = false)),
              if (_hintReported) Text('Hint: ${_hintDone?.name ?? 'not shown (seen, busy or capped)'}', style: ty.caption),
            ]),
            code: '''UiHintOnce(
  id: 'tip.me.settings',
  message: 'Your plan, sign-in and tips live here.',
  when: !loading,
  skipWhen: false,
  child: settingsButton,
)''',
            api: const [
              ApiRow('id', 'String', 'The tip id.'),
              ApiRow('message', 'String', 'The hint\'s text.'),
              ApiRow('when', 'bool', 'Wait until this is true (the page has loaded, no dialog is open).', def: 'true'),
              ApiRow('skipWhen', 'bool', 'Its action is already done: never show it; it is marked seen silently.', def: 'false'),
              ApiRow('placement / duration / dismissible', 'UiHint\'s', 'As UiHint.', def: 'top / 6 s / false'),
              ApiRow('guidance', 'UiGuidance?', 'The controller; else the nearest UiGuidanceScope. Without one it never shows.', def: 'null'),
            ],
            callbacks: const [ApiRow('onDone', 'ValueChanged<UiTourOutcome?>?', 'How it ended: closed, or null when it was not shown.')],
          ),
        ],
      ),
    );
  }
}

/// The empty feed's picture: a blank feed post card (cover, title lines, a heart), as on the web page.
class _FeedArtPainter extends CustomPainter {
  const _FeedArtPainter(this.t);
  final UiTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 320 x 200 board, scaled to the size given.
    canvas.scale(size.width / 320, size.height / 200);
    Paint fill(Color c) => Paint()..color = c;
    canvas.save();
    canvas.translate(166, 104);
    canvas.rotate(-6 * math.pi / 180);
    canvas.translate(-166, -104);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(66, 24, 200, 160), const Radius.circular(14)), fill(t.surfaceSubtle));
    canvas.restore();
    final card = RRect.fromRectAndRadius(const Rect.fromLTWH(56, 14, 208, 172), const Radius.circular(14));
    canvas.drawRRect(card, fill(t.surface));
    canvas.drawRRect(card, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = t.border);
    final cover = RRect.fromRectAndRadius(const Rect.fromLTWH(68, 26, 184, 92), const Radius.circular(8));
    canvas.drawRRect(cover, fill(uiMix(t.primary, 0.16, t.surface)));
    canvas.drawCircle(const Offset(226, 50), 10, fill(uiMix(t.primary, 0.45, t.surface)));
    canvas.save();
    canvas.clipRRect(cover);
    canvas.drawPath(
      Path()
        ..moveTo(68, 104)
        ..lineTo(112, 70)
        ..lineTo(142, 94)
        ..lineTo(170, 76)
        ..lineTo(252, 112)
        ..lineTo(252, 118)
        ..lineTo(68, 118)
        ..close(),
      fill(uiMix(t.primary, 0.34, t.surface)),
    );
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(68, 130, 120, 10), const Radius.circular(5)), fill(t.borderStrong));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(68, 148, 84, 8), const Radius.circular(4)), fill(t.border));
    canvas.drawPath(
      Path()
        ..moveTo(232, 166)
        ..cubicTo(226, 161, 220, 157, 220, 152)
        ..arcToPoint(const Offset(232, 150), radius: const Radius.circular(5.5))
        ..arcToPoint(const Offset(244, 152), radius: const Radius.circular(5.5))
        ..cubicTo(244, 157, 238, 161, 232, 166)
        ..close(),
      fill(t.primary),
    );
  }

  @override
  bool shouldRepaint(_FeedArtPainter old) => old.t != t;
}

/// The role card's cover: a sun over hills.
class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.t);
  final UiTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 56, size.height / 56);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 56, 56), Paint()..color = uiMix(t.primary, 0.22, t.surface));
    canvas.drawCircle(const Offset(40, 16), 7, Paint()..color = uiMix(t.primary, 0.55, t.surface));
    canvas.drawPath(
      Path()
        ..moveTo(0, 44)
        ..lineTo(18, 28)
        ..lineTo(30, 38)
        ..lineTo(40, 30)
        ..lineTo(56, 42)
        ..lineTo(56, 56)
        ..lineTo(0, 56)
        ..close(),
      Paint()..color = t.primary,
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.t != t;
}

