import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

const _plans = [
  UiPlanColumn(key: 'free', name: 'Free'),
  UiPlanColumn(key: 'gold', name: 'Gold pass', tier: UiTier.gold),
  UiPlanColumn(key: 'platinum', name: 'Platinum pass', tier: UiTier.platinum),
  UiPlanColumn(key: 'premium', name: 'Premium', tier: UiTier.premium),
];

const _rows = [
  UiPlanRow(label: 'Photo and video space', values: {'free': '1 GB', 'gold': '25 GB', 'platinum': '50 GB', 'premium': '3 GB per event'}),
  UiPlanRow(label: 'Guest uploads', values: {'free': true, 'gold': true, 'platinum': true, 'premium': true}),
  UiPlanRow(label: 'Keep photos after the event', values: {'free': false, 'gold': true, 'platinum': true, 'premium': true}),
  UiPlanRow(label: 'Design your own invitation', values: {'free': true, 'gold': true, 'platinum': true, 'premium': true}),
  UiPlanRow(label: 'Priority help', values: {'free': null, 'gold': false, 'platinum': true, 'premium': true}),
];

/// The Plans page: plan cards, the grid, the comparison table and tier buttons.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String _picked = '';

  void _pick(String plan) => setState(() => _picked = plan);

  Widget _tierButtons() {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
      Wrap(spacing: t.space2, runSpacing: t.space2, children: [
        UiButton(label: 'Get Gold', tier: UiTier.gold, onPressed: () => _pick('Gold')),
        UiButton(label: 'Get Platinum', tier: UiTier.platinum, onPressed: () => _pick('Platinum')),
        UiButton(label: 'Go Premium', tier: UiTier.premium, onPressed: () => _pick('Premium')),
      ]),
      Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        UiButton(label: 'Small', tier: UiTier.gold, size: UiSize.sm, onPressed: () {}),
        UiButton(label: 'Large', tier: UiTier.platinum, size: UiSize.lg, onPressed: () {}),
        UiButton(label: 'Paying', tier: UiTier.premium, loading: true, onPressed: () {}),
        const UiButton(label: 'Sold out', tier: UiTier.gold, onPressed: null),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Plans',
      lead: 'Plan cards, a responsive plan grid, a comparison table and buttons in the tier metals (gold, platinum, premium) for plans and billing pages.',
      children: [
        DocSection(
          name: 'Plan card',
          widget: 'UiPlanCard, UiPlanGrid',
          summary: 'One plan: name, price (already formatted) with its period, an optional note and tagline, and a check list of features. tier adds a slim strip of the tier metal on top and a small tier dot by the name; the card stays on the theme surface. highlight puts a ribbon on the top edge and a stronger border; use it on one card at most. current shows a "Your plan" badge; the caller decides the action. action sits at the bottom and lines up across cards; fineprint is small muted text under it. Screen readers get a group named by the plan and the price as one phrase ("MVR 499 per event"). UiPlanGrid shows one column under 600px, two under 912px, at most three, with equal-height cards.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
            UiPlanGrid(children: [
              UiPlanCard(
                name: 'Free',
                price: 'MVR 0',
                tagline: 'Try it with a small party',
                features: const ['1 GB of photos and videos', 'Guest uploads', 'Design your own invitation'],
                current: true,
                action: UiButton(label: 'Your plan', variant: UiButtonVariant.outline, block: true, onPressed: null),
              ),
              UiPlanCard(
                name: 'Gold pass',
                price: 'MVR 499',
                period: 'per event',
                note: r'about $32',
                tagline: 'Birthdays, parties and gatherings',
                tier: UiTier.gold,
                features: const ['25 GB of photos and videos', 'Guest uploads', 'Keep photos after the event'],
                action: UiButton(label: 'Get Gold', tier: UiTier.gold, block: true, onPressed: () => _pick('Gold pass')),
                fineprint: const Text('One payment, no subscription'),
              ),
              UiPlanCard(
                name: 'Platinum pass',
                price: 'MVR 899',
                period: 'per event',
                note: r'about $58',
                tagline: 'Weddings and big celebrations',
                tier: UiTier.platinum,
                highlight: 'For weddings',
                features: const ['50 GB of photos and videos', 'Guest uploads', 'Keep photos after the event', 'Priority help'],
                action: UiButton(label: 'Get Platinum', tier: UiTier.platinum, block: true, onPressed: () => _pick('Platinum pass')),
                fineprint: const Text('One payment, no subscription'),
              ),
            ]),
            SizedBox(
              width: 360,
              child: UiPlanCard(
                name: 'Premium',
                price: 'MVR 299',
                period: 'a month',
                note: r'about $19',
                tagline: 'For hosts with many events',
                tier: UiTier.premium,
                features: const ['3 GB for every event, kept while subscribed', 'Every design feature'],
                action: UiButton(label: 'Go Premium', tier: UiTier.premium, block: true, onPressed: () => _pick('Premium')),
                fineprint: const Text('Cancel any time'),
              ),
            ),
            UiText(_picked.isEmpty ? 'Pick a plan' : 'Picked: $_picked', variant: UiTextVariant.caption),
          ]),
          code: '''UiPlanGrid(children: [
  UiPlanCard(name: 'Free', price: 'MVR 0', features: ['1 GB'], current: true),
  UiPlanCard(
    name: 'Platinum pass',
    price: 'MVR 899',
    period: 'per event',
    note: 'about \\\$58',
    tier: UiTier.platinum,
    highlight: 'For weddings',
    features: ['50 GB of photos and videos', 'Priority help'],
    action: UiButton(label: 'Get Platinum', tier: UiTier.platinum, block: true, onPressed: buy),
    fineprint: Text('One payment, no subscription'),
  ),
])''',
          api: const [
            ApiRow('name', 'String', 'Plan name; also names the card for screen readers.'),
            ApiRow('price', 'String', 'Already formatted, e.g. "MVR 499".'),
            ApiRow('period', 'String?', 'After the price ("per event", "a month"); read with it.', def: 'null'),
            ApiRow('note', 'String?', 'Small line under the price ("about \$32").', def: 'null'),
            ApiRow('tagline', 'String?', 'Muted line under the name.', def: 'null'),
            ApiRow('features', 'List<String>', 'A check list.', def: 'const []'),
            ApiRow('tier', 'UiTier?', 'gold, platinum or premium: a slim metal strip on top and a tier dot by the name.', def: 'null'),
            ApiRow('highlight', 'String?', 'Ribbon on the top edge ("Most popular") and a stronger border. One per grid.', def: 'null'),
            ApiRow('current', 'bool', 'Shows the currentLabel badge.', def: 'false'),
            ApiRow('currentLabel', 'String', 'The current badge text.', def: "'Your plan'"),
            ApiRow('action', 'Widget?', 'Buttons at the bottom, aligned across a grid.', def: 'null'),
            ApiRow('fineprint', 'Widget?', 'Small muted text under the action.', def: 'null'),
            ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
            ApiRow('UiPlanGrid.children', 'List<Widget>', 'The cards: 1 column under 600px, 2 under 912px, at most 3; equal heights.'),
          ],
        ),
        DocSection(
          name: 'Plan comparison',
          widget: 'UiPlanCompare',
          summary: 'A plain table comparing plans. true shows a check read as "Included", false or null a dash read as "Not included", and strings show as text. Column headers carry a slim underline in the plan tier. highlight tints one column. On a narrow screen the table scrolls sideways inside itself and the first column stays put.',
          demo: const UiPlanCompare(plans: _plans, rows: _rows, highlight: 'platinum', caption: 'Compare plans'),
          code: '''UiPlanCompare(
  caption: 'Compare plans',
  highlight: 'platinum',
  plans: [
    UiPlanColumn(key: 'free', name: 'Free'),
    UiPlanColumn(key: 'gold', name: 'Gold pass', tier: UiTier.gold),
    UiPlanColumn(key: 'platinum', name: 'Platinum pass', tier: UiTier.platinum),
  ],
  rows: [
    UiPlanRow(label: 'Photo and video space', values: {'free': '1 GB', 'gold': '25 GB', 'platinum': '50 GB'}),
    UiPlanRow(label: 'Priority help', values: {'free': false, 'gold': false, 'platinum': true}),
  ],
)''',
          api: const [
            ApiRow('plans', 'List<UiPlanColumn>', 'Columns: key, name and an optional tier.'),
            ApiRow('rows', 'List<UiPlanRow>', 'label and values by plan key: String, bool or null.'),
            ApiRow('highlight', 'String?', 'Plan key whose column is tinted.', def: 'null'),
            ApiRow('caption', 'String?', 'Names the table for screen readers.', def: 'null'),
            ApiRow('includedLabel / notIncludedLabel', 'String', 'What screen readers hear for a check and a dash.', def: "'Included' / 'Not included'"),
          ],
          shapes: 'class UiPlanColumn { String key; String name; UiTier? tier; }\nclass UiPlanRow { String label; Map<String, Object?> values; }',
        ),
        DocSection(
          name: 'Tier buttons',
          widget: 'UiButton(tier:)',
          summary: 'A button in a tier metal: the tier sheen, its contrast label (AA on every part of the sheen, in hover and press too) and edge, and a focus ring in the edge colour. Platinum gets a soft light sweep on hover, none when animations are off. Works with size, block, icons and loading. Wins over variant. The metals are the same in every theme.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            for (final th in [UiThemeName.light, UiThemeName.dark])
              UiThemeScope(
                theme: th,
                child: Builder(builder: (context) {
                  final s = context.ui;
                  return Container(
                    padding: EdgeInsets.all(s.space4),
                    decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(s.radius), border: Border.all(color: s.border)),
                    child: _tierButtons(),
                  );
                }),
              ),
          ]),
          code: '''UiButton(label: 'Get Gold', tier: UiTier.gold, onPressed: buy)
UiButton(label: 'Get Platinum', tier: UiTier.platinum, block: true, onPressed: buy)
UiButton(label: 'Go Premium', tier: UiTier.premium, loading: paying, onPressed: buy)''',
          api: const [
            ApiRow('tier', 'UiTier?', 'gold, platinum or premium. Wins over variant.', def: 'null'),
          ],
          shapes: 'typedef UiTier = UiBadgeTier; // enum { gold, platinum, premium }',
        ),
      ],
    );
  }
}
