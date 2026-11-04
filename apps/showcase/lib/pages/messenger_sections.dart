import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

// The 0.57 sections: messenger buttons (Buttons page), contact channels and table cell builders (Data
// page), phone input (Forms page). Kept in their own file so the pages' other sections stay untouched.

String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Buttons page: "Messenger buttons".
class MessengerButtonSection extends StatefulWidget {
  const MessengerButtonSection({super.key});
  @override
  State<MessengerButtonSection> createState() => _MessengerButtonSectionState();
}

class _MessengerButtonSectionState extends State<MessengerButtonSection> {
  String _log = 'Nothing yet';
  final Map<UiMessengerApp, String> _opened = {};

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    void press(UiMessengerApp app) => setState(() {
          _opened[app] = 'Opened ${_clock(DateTime.now())}';
          _log = '${UiMessengerBrand.name(app)} pressed';
        });
    return DocSection(
      name: 'Messenger buttons',
      widget: 'UiMessengerButton',
      summary:
          'Opens a chat in WhatsApp, Viber or Telegram: the brand\'s fill, its official logo (unaltered, from each brand\'s own download) and the app\'s name in a dark ink that passes AA on the fill (white does not on any of the three), 44 high with the theme\'s corners. Logo and name are centred together. compact shows the logo alone (44x44; the name stays the accessible name); auto does so exactly when the whole name would not fit (never an ellipsis), for equal rows that must fit a phone. ticked adds a success tick at the top-end corner, in the same place on every button; the button stays usable, tickLabel is read after the name and shown as a tooltip (long press on touch). It only reports the press: the app opens the link. The web twin is ui-messenger-button.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
        Wrap(spacing: t.space2, runSpacing: t.space3, children: [
          for (final app in UiMessengerApp.values) UiMessengerButton(app: app, ticked: _opened.containsKey(app), tickLabel: _opened[app], onPressed: () => press(app)),
        ]),
        Wrap(spacing: t.space3, runSpacing: t.space3, children: [
          for (final app in UiMessengerApp.values) UiMessengerButton(app: app, compact: UiMessengerCompact.on, onPressed: () => press(app)),
          UiMessengerButton(app: UiMessengerApp.viber, compact: UiMessengerCompact.on, ticked: true, tickLabel: 'Opened yesterday', onPressed: () => press(UiMessengerApp.viber)),
          const UiMessengerButton(app: UiMessengerApp.telegram, onPressed: null),
        ]),
        Row(spacing: t.space2, children: [
          for (final app in UiMessengerApp.values)
            Expanded(child: UiMessengerButton(app: app, expand: true, compact: UiMessengerCompact.auto, ticked: _opened.containsKey(app), tickLabel: _opened[app], onPressed: () => press(app))),
        ]),
        UiText(_log, variant: UiTextVariant.caption),
      ]),
      code: '''Row(spacing: 8, children: [
  for (final app in UiMessengerApp.values)
    Expanded(
      child: UiMessengerButton(
        app: app,
        expand: true,
        compact: UiMessengerCompact.auto,
        ticked: opened.containsKey(app),
        tickLabel: opened[app],
        onPressed: () => openChat(app),
      ),
    ),
])''',
      api: const [
        ApiRow('app', 'UiMessengerApp', 'whatsapp, viber or telegram.'),
        ApiRow('onPressed', 'VoidCallback?', 'Open the chat. Null disables the button (half opacity).'),
        ApiRow('label', 'String?', 'The visible words.', def: 'the app\'s name'),
        ApiRow('compact', 'UiMessengerCompact', 'off, on (logo only, 44x44), auto (logo only when the whole label would not fit; never an ellipsis).', def: 'off'),
        ApiRow('expand', 'bool', 'Fill the width; logo and words stay centred.', def: 'false'),
        ApiRow('ticked', 'bool', 'The success tick badge at the top-end corner. Still usable.', def: 'false'),
        ApiRow('tickLabel', 'String?', 'What the tick means: read after the name, shown as a tooltip.', def: 'UiStrings.messengerOpened'),
        ApiRow('semanticLabel', 'String?', 'The accessible name ("Send to Aisha on WhatsApp").', def: 'label'),
        ApiRow('focusNode / autofocus', 'FocusNode? / bool', 'Keyboard focus.'),
      ],
      shapes: 'enum UiMessengerApp { whatsapp, viber, telegram }\nenum UiMessengerCompact { off, on, auto }\n// Brand colours, logo sizes and the fill: UiMessengerBrand.\n// labelledWidth(context): the width auto needs to show the label.',
    );
  }
}

/// Data page: "Contact channels".
class ContactChannelsSection extends StatefulWidget {
  const ContactChannelsSection({super.key});
  @override
  State<ContactChannelsSection> createState() => _ContactChannelsSectionState();
}

class _ContactChannelsSectionState extends State<ContactChannelsSection> {
  final Map<UiMessengerApp, String> _ticks = {};
  bool _busy = false;
  UiEmailStatus _second = UiEmailStatus.bounced;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _busy = false;
        _second = UiEmailStatus.sent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget card(Widget child) => UiCard(child: child);
    return DocSection(
      name: 'Contact channels',
      widget: 'UiContactChannels',
      summary:
          'One person\'s ways to be reached, in columns that line up: Email (label, address, status), Number, and under it a row of messenger buttons that starts at the value column. The label column is at least 64 wide (as wide as the widest label), the status column at least 44. The email status is a Send button, a success tick (sent or delivered, emailTickLabel as its tooltip and name), Retry with the error under the row (failed or bounced), or a spinner while emailBusy. The buttons share the width equally and turn icon-only when there isn\'t room (a phone), keeping their names for screen readers. It only reports presses: the app sends and sets the ticks. Press a button below to tick it. The web twin is ui-contact-channels.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        card(UiContactChannels(
          email: 'aisha@example.com',
          emailStatus: UiEmailStatus.delivered,
          emailTickLabel: 'Emailed 4 Nov, 19:02',
          phone: '+960 777 1234',
          messengers: [
            for (final app in UiMessengerApp.values)
              UiMessengerChannel(app: app, ticked: _ticks.containsKey(app), tickLabel: _ticks[app], semanticLabel: 'Send to Aisha on ${UiMessengerBrand.name(app)}'),
          ],
          onMessengerPressed: (app) => setState(() => _ticks[app] = 'Opened ${_clock(DateTime.now())}'),
        )),
        card(UiContactChannels(
          email: 'hassan@exampel.com',
          emailStatus: _second,
          emailBusy: _busy,
          emailError: 'The address bounced: no such mailbox.',
          phone: '+44 7700 900123',
          messengers: const [UiMessengerChannel(app: UiMessengerApp.whatsapp), UiMessengerChannel(app: UiMessengerApp.viber, hidden: true), UiMessengerChannel(app: UiMessengerApp.telegram)],
          onEmailRetry: _retry,
          onMessengerPressed: (_) {},
        )),
      ]),
      code: '''UiContactChannels(
  email: guest.email,
  emailStatus: UiEmailStatus.delivered,
  emailTickLabel: 'Emailed 4 Nov, 19:02',
  phone: guest.phone,
  messengers: [
    for (final app in UiMessengerApp.values)
      UiMessengerChannel(app: app, ticked: guest.opened(app), tickLabel: guest.openedLabel(app)),
  ],
  onEmailSend: sendEmail,
  onEmailRetry: sendEmail,
  onMessengerPressed: openChat,
)''',
      api: const [
        ApiRow('email', 'String?', 'The address; no row without one.'),
        ApiRow('emailStatus', 'UiEmailStatus', 'none / skipped: Send; sent / delivered: tick; failed / bounced: Retry.', def: 'none'),
        ApiRow('emailTickLabel', 'String?', 'The tick\'s tooltip and name.', def: 'UiStrings.contactEmailSent'),
        ApiRow('emailError', 'String?', 'Shown under the row with Retry; describes the Retry button.'),
        ApiRow('emailBusy', 'bool', 'A spinner in the status cell.', def: 'false'),
        ApiRow('phone', 'String?', 'Shown as given; no number or messenger row without one.'),
        ApiRow('messengers', 'List<UiMessengerChannel>', 'The buttons under the number, in order.', def: '[]'),
        ApiRow('emailLabel / numberLabel', 'String?', 'Row labels.', def: 'UiStrings.contactEmail / contactNumber'),
      ],
      callbacks: const [
        ApiRow('onEmailSend', 'VoidCallback?', 'Send pressed.'),
        ApiRow('onEmailRetry', 'VoidCallback?', 'Retry pressed.'),
        ApiRow('onMessengerPressed', 'ValueChanged<UiMessengerApp>?', 'A messenger button pressed.'),
      ],
      shapes: 'enum UiEmailStatus { none, skipped, sent, delivered, failed, bounced }\nclass UiMessengerChannel { UiMessengerApp app; bool ticked; String? tickLabel; String? semanticLabel; bool hidden; }',
    );
  }
}

typedef _Guest = ({String name, String status, bool opened});

/// Data page: a table with a custom cell.
class TableCellSection extends StatefulWidget {
  const TableCellSection({super.key});
  @override
  State<TableCellSection> createState() => _TableCellSectionState();
}

class _TableCellSectionState extends State<TableCellSection> {
  final List<_Guest> _guests = [
    (name: 'Aisha Mohamed', status: 'Coming', opened: true),
    (name: 'Hassan Ali', status: 'Not replied', opened: false),
    (name: 'Mariyam Zahir', status: 'Declined', opened: true),
  ];
  String _last = 'Nothing yet';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    UiStatus tone(String s) => switch (s) { 'Coming' => UiStatus.success, 'Declined' => UiStatus.danger, _ => UiStatus.neutral };
    return DocSection(
      name: 'Table: custom cells',
      widget: 'UiColumn.cellBuilder',
      summary:
          'A column\'s cellBuilder draws its cells as widgets (a status pill, a button) in place of the formatted text, inside the usual cell padding and alignment. Sorting still uses the column\'s value. The web twin is the uiCell template inside ui-table.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        UiTable<_Guest>(
          columns: [
            UiColumn(key: 'name', header: 'Guest', sortable: true, value: (g) => g.name),
            UiColumn(key: 'status', header: 'Reply', sortable: true, value: (g) => g.status, cellBuilder: (context, g) => UiBadge(label: g.status, tone: tone(g.status))),
            UiColumn(
              key: 'whatsapp',
              header: 'WhatsApp',
              cellBuilder: (context, g) => UiMessengerButton(
                app: UiMessengerApp.whatsapp,
                compact: UiMessengerCompact.on,
                ticked: g.opened,
                semanticLabel: 'Send to ${g.name} on WhatsApp',
                onPressed: () => setState(() => _last = 'WhatsApp for ${g.name}'),
              ),
            ),
          ],
          data: _guests,
        ),
        UiText(_last, variant: UiTextVariant.caption),
      ]),
      code: '''UiColumn<Guest>(
  key: 'status',
  header: 'Reply',
  sortable: true,
  value: (g) => g.status,
  cellBuilder: (context, g) => UiBadge(label: g.status, tone: toneOf(g.status)),
)''',
      api: const [
        ApiRow('cellBuilder', 'Widget Function(BuildContext, T row)?', 'Builds the cell in place of format\'s text; sort still reads value.'),
      ],
    );
  }
}

/// Forms page: "Phone input".
class PhoneInputSection extends StatefulWidget {
  const PhoneInputSection({super.key});
  @override
  State<PhoneInputSection> createState() => _PhoneInputSectionState();
}

class _PhoneInputSectionState extends State<PhoneInputSection> {
  final _form = GlobalKey<FormState>();
  String? _phone;
  String _country = 'GB';
  String _saved = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Phone input',
      widget: 'UiPhoneInput',
      summary:
          'A phone number as one E.164 string (+447700900123): a country button (flag and dial code) opening a searchable list of every country (by name, ISO code or dial code), beside the number field. A value picks its country from its dial code (for a shared code like +1, by the number\'s leading digits, else defaultCountry, else the main country) and the field shows the national digits as stored. Out: the typed digits with spaces, dashes, dots and brackets dropped and the trunk prefix removed (the UK\'s leading 0; Italy keeps its 0). Typing or pasting +44… or 0044… switches the country. Empty, or no country chosen: null. Without defaultCountry no country is assumed (a globe and +). Checking that a number is real is the app\'s job; show the result with invalid or a form field error. The web twin is ui-phone-input.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        UiFormField(
          label: 'Mobile',
          hint: 'Country: $_country',
          child: UiPhoneInput(
            value: _phone,
            defaultCountry: 'GB',
            placeholder: '7700 900123',
            onChanged: (v) => setState(() => _phone = v),
            onCountryChanged: (iso) => setState(() => _country = iso),
          ),
        ),
        UiText('Value: ${_phone ?? 'null'}', variant: UiTextVariant.caption),
        Form(
          key: _form,
          child: UiFormField<String>.validated(
            label: 'Emergency contact (no default country)',
            required: true,
            validator: (v) => v != null && v.length < 8 ? 'That number looks too short' : null,
            builder: (field) => UiPhoneInput(value: field.value, onChanged: field.didChange),
          ),
        ),
        Row(spacing: t.space3, children: [
          UiButton(
            label: 'Save',
            size: UiSize.sm,
            onPressed: () => setState(() => _saved = _form.currentState!.validate() ? 'Saved' : 'Fix the errors'),
          ),
          UiText(_saved, variant: UiTextVariant.caption),
        ]),
      ]),
      code: '''UiFormField(
  label: 'Mobile',
  child: UiPhoneInput(
    value: phone,                  // '+447700900123' or null
    defaultCountry: 'GB',
    onChanged: (v) => setState(() => phone = v),
  ),
)''',
      api: const [
        ApiRow('value / onChanged', 'String? / ValueChanged<String?>', 'E.164, or null when empty or no country is chosen.'),
        ApiRow('defaultCountry', 'String?', 'ISO 3166 alpha-2 chosen while the value is empty. No default otherwise.'),
        ApiRow('onCountryChanged', 'ValueChanged<String>?', 'The ISO code the user picked (from the list or by typing +).'),
        ApiRow('placeholder', 'String?', 'For the number field.'),
        ApiRow('semanticLabel', 'String?', 'The number field\'s name.', def: 'the form field label, else "Phone number"'),
        ApiRow('size', 'UiSize', 'sm, md, lg as other fields.', def: 'md'),
        ApiRow('invalid', 'bool', 'Red border (also set by a UiFormField error).', def: 'false'),
        ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
        ApiRow('enabled', 'bool', 'False greys it out.', def: 'true'),
        ApiRow('focusNode / autofocus', 'FocusNode? / bool', 'The number field\'s focus.'),
      ],
      callbacks: const [
        ApiRow('uiPhoneSplit / uiPhoneE164 / uiPhoneSearch', 'functions', 'The same parsing, output and search the widget uses; uiPhoneCountries holds the 245 countries (libphonenumber v9.0.42).'),
      ],
      shapes: 'class UiPhoneCountry { String iso2, name, dial, trunk, leading; bool main; String flag; }',
    );
  }
}
