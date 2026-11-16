// Generated from the Angular `form-strings.ts` / `fixtures/form-strings.json`; keep the wording identical.

import 'js.dart';

/// The words the form renderer and engine say themselves (buttons, step text, error summary, Yes/No,
/// default messages of the built-in checks, ...), as opposed to text written into the form. One field
/// per phrase, named like the web `UiFbStrings`; `{placeholders}` are filled in by the code
/// ([fbFormat]). The builder's own admin screens stay English.
///
/// Text the form author wrote (`settings.submitLabel`, a field's `requiredMessage`, a rule's `message`)
/// always wins over these. English and Dhivehi ship in the library; add or adjust any language with
/// `strings` on the renderer or engine, or [UiFormStringsScope].
class UiFbStrings {
  const UiFbStrings({
    required this.submit,
    required this.saveChanges,
    required this.next,
    required this.back,
    required this.stepOf,
    required this.problemOne,
    required this.problemMany,
    required this.errorLabel,
    required this.changeOne,
    required this.changeMany,
    required this.noChanges,
    required this.empty,
    required this.yes,
    required this.no,
    required this.notAnswered,
    required this.optional,
    required this.calculatedHint,
    required this.noLongerOption,
    required this.noLongerOffered,
    required this.entryTitle,
    required this.addAnother,
    required this.nothingAdded,
    required this.noneAdded,
    required this.remove,
    required this.moveUp,
    required this.moveDown,
    required this.entryAdded,
    required this.entryRemoved,
    required this.entryRemovedAnnounce,
    required this.entryRestored,
    required this.undo,
    required this.choose,
    required this.selectDate,
    required this.fileUploadLabel,
    required this.fileUploadHint,
    required this.uploading,
    required this.uploadFailed,
    required this.checking,
    required this.searchSource,
    required this.search,
    required this.clear,
    required this.tryAgain,
    required this.listUnavailable,
    required this.savedAnswer,
    required this.chooseFirst,
    required this.typeToSearch,
    required this.loadFailed,
    required this.searching,
    required this.loadingMore,
    required this.noMatches,
    required this.nothingToChoose,
    required this.requiredField,
    required this.requiredQuestion,
    required this.requiredTick,
    required this.compareEq,
    required this.compareGt,
    required this.compareGte,
    required this.compareLt,
    required this.compareLte,
    required this.dateToday,
    required this.dateInDays,
    required this.dateDaysAgo,
    required this.validatorInvalid,
    required this.validatorEmail,
    required this.validatorUrl,
    required this.validatorPhone,
    required this.validatorMinLength,
    required this.validatorMaxLength,
    required this.validatorMinWords,
    required this.validatorMaxWords,
    required this.validatorPattern,
    required this.validatorMin,
    required this.validatorMax,
    required this.validatorInteger,
    required this.validatorDecimalPlaces,
    required this.validatorMinDate,
    required this.validatorMaxDate,
    required this.validatorAgeAtLeast,
    required this.validatorAgeAtMost,
    required this.validatorEarliestTime,
    required this.validatorLatestTime,
    required this.validatorMinSelected,
    required this.validatorMaxSelected,
    required this.validatorFileType,
    required this.validatorMaxFileSize,
    required this.validatorMaxFiles,
    required this.validatorEqualsField,
    required this.validatorCompareField,
  });

  // Buttons and progress
  /// Primary button on the last page.
  final String submit;
  /// Primary button on the last page when editing saved answers.
  final String saveChanges;
  /// Primary button on every page but the last.
  final String next;
  /// Back button.
  final String back;
  /// Progress line (`{n}` of `{total}`); the page title is appended after a colon.
  final String stepOf;

  // Error summary and change list
  /// Error summary heading with one problem.
  final String problemOne;
  /// Error summary heading with several problems.
  final String problemMany;
  /// Read out before a field's error message.
  final String errorLabel;
  /// Change list toggle with one change.
  final String changeOne;
  /// Change list toggle with several changes.
  final String changeMany;
  /// Shown when editing and nothing changed.
  final String noChanges;
  /// An empty value in the change list.
  final String empty;

  // Answers
  /// A ticked checkbox or switch, shown as text.
  final String yes;
  /// An unticked checkbox or switch, shown as text.
  final String no;
  /// A question with no answer, when viewing saved answers.
  final String notAnswered;
  /// Marker after the label of an optional question.
  final String optional;
  /// A calculated field that has no result yet.
  final String calculatedHint;
  /// A saved answer whose option is gone (`{value}`).
  final String noLongerOption;
  /// An archived option that is still chosen (`{label}`).
  final String noLongerOffered;

  // Repeating sections
  /// Default title of a repeat entry (`{n}`).
  final String entryTitle;
  /// Default add button of a repeating section.
  final String addAnother;
  /// A repeating section with no entries.
  final String nothingAdded;
  /// A repeating section with no entries, when viewing.
  final String noneAdded;
  /// Remove button of an entry, a file or a chosen item (`{name}`).
  final String remove;
  /// Move an entry up (`{name}`).
  final String moveUp;
  /// Move an entry down (`{name}`).
  final String moveDown;
  /// Read out when an entry is added (`{name}`).
  final String entryAdded;
  /// Shown after an entry is removed (`{name}`), before Undo.
  final String entryRemoved;
  /// Read out when an entry is removed (`{name}`).
  final String entryRemovedAnnounce;
  /// Read out when a removed entry is restored (`{name}`).
  final String entryRestored;
  /// Undo button after removing an entry.
  final String undo;

  // Controls
  /// Placeholder of a dropdown or multi-select.
  final String choose;
  /// Placeholder of a date field.
  final String selectDate;
  /// Bold part of the file drop area.
  final String fileUploadLabel;
  /// Rest of the file drop area.
  final String fileUploadHint;
  /// Shown while a file uploads.
  final String uploading;
  /// Shown when a file upload fails.
  final String uploadFailed;
  /// Shown while a server check runs.
  final String checking;

  // Lists searched from the app (source picker)
  /// Placeholder of a sourced list (`{name}`, the list's name in lower case).
  final String searchSource;
  /// Placeholder of a search box.
  final String search;
  /// Clear button of a sourced list.
  final String clear;
  /// Retry button when a list fails to load.
  final String tryAgain;
  /// A sourced list the app does not provide.
  final String listUnavailable;
  /// Appended to the line above (`{answer}`).
  final String savedAnswer;
  /// A dependent list waiting for another answer (`{name}`).
  final String chooseFirst;
  /// A list that needs more typing (`{n}` characters).
  final String typeToSearch;
  /// A list that failed to load.
  final String loadFailed;
  /// A list that is searching.
  final String searching;
  /// A list loading its next page.
  final String loadingMore;
  /// A search with no results (`{query}`).
  final String noMatches;
  /// A list with nothing in it.
  final String nothingToChoose;

  // Required
  /// Default message of a required question (`{label}`).
  final String requiredField;
  /// Default message of a required question whose label is a question.
  final String requiredQuestion;
  /// Default message of a required checkbox.
  final String requiredTick;

  // Comparison and date words used inside messages
  /// `{comparison}` of a "compare with another answer" check.
  final String compareEq;
  final String compareGt;
  final String compareGte;
  final String compareLt;
  final String compareLte;
  /// A date setting of "today" inside a message.
  final String dateToday;
  /// A date setting of "today+n" inside a message.
  final String dateInDays;
  /// A date setting of "today-n" inside a message.
  final String dateDaysAgo;

  // Default messages of the built-in checks (key: "validator" + the check's type with a capital)
  /// A registered check that has no message of its own.
  final String validatorInvalid;
  final String validatorEmail;
  final String validatorUrl;
  final String validatorPhone;
  final String validatorMinLength;
  final String validatorMaxLength;
  final String validatorMinWords;
  final String validatorMaxWords;
  final String validatorPattern;
  final String validatorMin;
  final String validatorMax;
  final String validatorInteger;
  final String validatorDecimalPlaces;
  final String validatorMinDate;
  final String validatorMaxDate;
  final String validatorAgeAtLeast;
  final String validatorAgeAtMost;
  final String validatorEarliestTime;
  final String validatorLatestTime;
  final String validatorMinSelected;
  final String validatorMaxSelected;
  final String validatorFileType;
  final String validatorMaxFileSize;
  final String validatorMaxFiles;
  final String validatorEqualsField;
  final String validatorCompareField;

  /// Every key name, in table order.
  static const List<String> keys = [
    'submit',
    'saveChanges',
    'next',
    'back',
    'stepOf',
    'problemOne',
    'problemMany',
    'errorLabel',
    'changeOne',
    'changeMany',
    'noChanges',
    'empty',
    'yes',
    'no',
    'notAnswered',
    'optional',
    'calculatedHint',
    'noLongerOption',
    'noLongerOffered',
    'entryTitle',
    'addAnother',
    'nothingAdded',
    'noneAdded',
    'remove',
    'moveUp',
    'moveDown',
    'entryAdded',
    'entryRemoved',
    'entryRemovedAnnounce',
    'entryRestored',
    'undo',
    'choose',
    'selectDate',
    'fileUploadLabel',
    'fileUploadHint',
    'uploading',
    'uploadFailed',
    'checking',
    'searchSource',
    'search',
    'clear',
    'tryAgain',
    'listUnavailable',
    'savedAnswer',
    'chooseFirst',
    'typeToSearch',
    'loadFailed',
    'searching',
    'loadingMore',
    'noMatches',
    'nothingToChoose',
    'requiredField',
    'requiredQuestion',
    'requiredTick',
    'compareEq',
    'compareGt',
    'compareGte',
    'compareLt',
    'compareLte',
    'dateToday',
    'dateInDays',
    'dateDaysAgo',
    'validatorInvalid',
    'validatorEmail',
    'validatorUrl',
    'validatorPhone',
    'validatorMinLength',
    'validatorMaxLength',
    'validatorMinWords',
    'validatorMaxWords',
    'validatorPattern',
    'validatorMin',
    'validatorMax',
    'validatorInteger',
    'validatorDecimalPlaces',
    'validatorMinDate',
    'validatorMaxDate',
    'validatorAgeAtLeast',
    'validatorAgeAtMost',
    'validatorEarliestTime',
    'validatorLatestTime',
    'validatorMinSelected',
    'validatorMaxSelected',
    'validatorFileType',
    'validatorMaxFileSize',
    'validatorMaxFiles',
    'validatorEqualsField',
    'validatorCompareField',
  ];

  /// The phrases by key name (the shape [UiFbStringOverrides] uses).
  Map<String, String> toMap() => {
    'submit': submit,
    'saveChanges': saveChanges,
    'next': next,
    'back': back,
    'stepOf': stepOf,
    'problemOne': problemOne,
    'problemMany': problemMany,
    'errorLabel': errorLabel,
    'changeOne': changeOne,
    'changeMany': changeMany,
    'noChanges': noChanges,
    'empty': empty,
    'yes': yes,
    'no': no,
    'notAnswered': notAnswered,
    'optional': optional,
    'calculatedHint': calculatedHint,
    'noLongerOption': noLongerOption,
    'noLongerOffered': noLongerOffered,
    'entryTitle': entryTitle,
    'addAnother': addAnother,
    'nothingAdded': nothingAdded,
    'noneAdded': noneAdded,
    'remove': remove,
    'moveUp': moveUp,
    'moveDown': moveDown,
    'entryAdded': entryAdded,
    'entryRemoved': entryRemoved,
    'entryRemovedAnnounce': entryRemovedAnnounce,
    'entryRestored': entryRestored,
    'undo': undo,
    'choose': choose,
    'selectDate': selectDate,
    'fileUploadLabel': fileUploadLabel,
    'fileUploadHint': fileUploadHint,
    'uploading': uploading,
    'uploadFailed': uploadFailed,
    'checking': checking,
    'searchSource': searchSource,
    'search': search,
    'clear': clear,
    'tryAgain': tryAgain,
    'listUnavailable': listUnavailable,
    'savedAnswer': savedAnswer,
    'chooseFirst': chooseFirst,
    'typeToSearch': typeToSearch,
    'loadFailed': loadFailed,
    'searching': searching,
    'loadingMore': loadingMore,
    'noMatches': noMatches,
    'nothingToChoose': nothingToChoose,
    'requiredField': requiredField,
    'requiredQuestion': requiredQuestion,
    'requiredTick': requiredTick,
    'compareEq': compareEq,
    'compareGt': compareGt,
    'compareGte': compareGte,
    'compareLt': compareLt,
    'compareLte': compareLte,
    'dateToday': dateToday,
    'dateInDays': dateInDays,
    'dateDaysAgo': dateDaysAgo,
    'validatorInvalid': validatorInvalid,
    'validatorEmail': validatorEmail,
    'validatorUrl': validatorUrl,
    'validatorPhone': validatorPhone,
    'validatorMinLength': validatorMinLength,
    'validatorMaxLength': validatorMaxLength,
    'validatorMinWords': validatorMinWords,
    'validatorMaxWords': validatorMaxWords,
    'validatorPattern': validatorPattern,
    'validatorMin': validatorMin,
    'validatorMax': validatorMax,
    'validatorInteger': validatorInteger,
    'validatorDecimalPlaces': validatorDecimalPlaces,
    'validatorMinDate': validatorMinDate,
    'validatorMaxDate': validatorMaxDate,
    'validatorAgeAtLeast': validatorAgeAtLeast,
    'validatorAgeAtMost': validatorAgeAtMost,
    'validatorEarliestTime': validatorEarliestTime,
    'validatorLatestTime': validatorLatestTime,
    'validatorMinSelected': validatorMinSelected,
    'validatorMaxSelected': validatorMaxSelected,
    'validatorFileType': validatorFileType,
    'validatorMaxFileSize': validatorMaxFileSize,
    'validatorMaxFiles': validatorMaxFiles,
    'validatorEqualsField': validatorEqualsField,
    'validatorCompareField': validatorCompareField,
  };

  /// A copy with the phrases in [overrides] (by key name) replaced. Unknown keys are ignored.
  UiFbStrings merge(Map<String, String> overrides) => UiFbStrings(
    submit: overrides['submit'] ?? submit,
    saveChanges: overrides['saveChanges'] ?? saveChanges,
    next: overrides['next'] ?? next,
    back: overrides['back'] ?? back,
    stepOf: overrides['stepOf'] ?? stepOf,
    problemOne: overrides['problemOne'] ?? problemOne,
    problemMany: overrides['problemMany'] ?? problemMany,
    errorLabel: overrides['errorLabel'] ?? errorLabel,
    changeOne: overrides['changeOne'] ?? changeOne,
    changeMany: overrides['changeMany'] ?? changeMany,
    noChanges: overrides['noChanges'] ?? noChanges,
    empty: overrides['empty'] ?? empty,
    yes: overrides['yes'] ?? yes,
    no: overrides['no'] ?? no,
    notAnswered: overrides['notAnswered'] ?? notAnswered,
    optional: overrides['optional'] ?? optional,
    calculatedHint: overrides['calculatedHint'] ?? calculatedHint,
    noLongerOption: overrides['noLongerOption'] ?? noLongerOption,
    noLongerOffered: overrides['noLongerOffered'] ?? noLongerOffered,
    entryTitle: overrides['entryTitle'] ?? entryTitle,
    addAnother: overrides['addAnother'] ?? addAnother,
    nothingAdded: overrides['nothingAdded'] ?? nothingAdded,
    noneAdded: overrides['noneAdded'] ?? noneAdded,
    remove: overrides['remove'] ?? remove,
    moveUp: overrides['moveUp'] ?? moveUp,
    moveDown: overrides['moveDown'] ?? moveDown,
    entryAdded: overrides['entryAdded'] ?? entryAdded,
    entryRemoved: overrides['entryRemoved'] ?? entryRemoved,
    entryRemovedAnnounce: overrides['entryRemovedAnnounce'] ?? entryRemovedAnnounce,
    entryRestored: overrides['entryRestored'] ?? entryRestored,
    undo: overrides['undo'] ?? undo,
    choose: overrides['choose'] ?? choose,
    selectDate: overrides['selectDate'] ?? selectDate,
    fileUploadLabel: overrides['fileUploadLabel'] ?? fileUploadLabel,
    fileUploadHint: overrides['fileUploadHint'] ?? fileUploadHint,
    uploading: overrides['uploading'] ?? uploading,
    uploadFailed: overrides['uploadFailed'] ?? uploadFailed,
    checking: overrides['checking'] ?? checking,
    searchSource: overrides['searchSource'] ?? searchSource,
    search: overrides['search'] ?? search,
    clear: overrides['clear'] ?? clear,
    tryAgain: overrides['tryAgain'] ?? tryAgain,
    listUnavailable: overrides['listUnavailable'] ?? listUnavailable,
    savedAnswer: overrides['savedAnswer'] ?? savedAnswer,
    chooseFirst: overrides['chooseFirst'] ?? chooseFirst,
    typeToSearch: overrides['typeToSearch'] ?? typeToSearch,
    loadFailed: overrides['loadFailed'] ?? loadFailed,
    searching: overrides['searching'] ?? searching,
    loadingMore: overrides['loadingMore'] ?? loadingMore,
    noMatches: overrides['noMatches'] ?? noMatches,
    nothingToChoose: overrides['nothingToChoose'] ?? nothingToChoose,
    requiredField: overrides['requiredField'] ?? requiredField,
    requiredQuestion: overrides['requiredQuestion'] ?? requiredQuestion,
    requiredTick: overrides['requiredTick'] ?? requiredTick,
    compareEq: overrides['compareEq'] ?? compareEq,
    compareGt: overrides['compareGt'] ?? compareGt,
    compareGte: overrides['compareGte'] ?? compareGte,
    compareLt: overrides['compareLt'] ?? compareLt,
    compareLte: overrides['compareLte'] ?? compareLte,
    dateToday: overrides['dateToday'] ?? dateToday,
    dateInDays: overrides['dateInDays'] ?? dateInDays,
    dateDaysAgo: overrides['dateDaysAgo'] ?? dateDaysAgo,
    validatorInvalid: overrides['validatorInvalid'] ?? validatorInvalid,
    validatorEmail: overrides['validatorEmail'] ?? validatorEmail,
    validatorUrl: overrides['validatorUrl'] ?? validatorUrl,
    validatorPhone: overrides['validatorPhone'] ?? validatorPhone,
    validatorMinLength: overrides['validatorMinLength'] ?? validatorMinLength,
    validatorMaxLength: overrides['validatorMaxLength'] ?? validatorMaxLength,
    validatorMinWords: overrides['validatorMinWords'] ?? validatorMinWords,
    validatorMaxWords: overrides['validatorMaxWords'] ?? validatorMaxWords,
    validatorPattern: overrides['validatorPattern'] ?? validatorPattern,
    validatorMin: overrides['validatorMin'] ?? validatorMin,
    validatorMax: overrides['validatorMax'] ?? validatorMax,
    validatorInteger: overrides['validatorInteger'] ?? validatorInteger,
    validatorDecimalPlaces: overrides['validatorDecimalPlaces'] ?? validatorDecimalPlaces,
    validatorMinDate: overrides['validatorMinDate'] ?? validatorMinDate,
    validatorMaxDate: overrides['validatorMaxDate'] ?? validatorMaxDate,
    validatorAgeAtLeast: overrides['validatorAgeAtLeast'] ?? validatorAgeAtLeast,
    validatorAgeAtMost: overrides['validatorAgeAtMost'] ?? validatorAgeAtMost,
    validatorEarliestTime: overrides['validatorEarliestTime'] ?? validatorEarliestTime,
    validatorLatestTime: overrides['validatorLatestTime'] ?? validatorLatestTime,
    validatorMinSelected: overrides['validatorMinSelected'] ?? validatorMinSelected,
    validatorMaxSelected: overrides['validatorMaxSelected'] ?? validatorMaxSelected,
    validatorFileType: overrides['validatorFileType'] ?? validatorFileType,
    validatorMaxFileSize: overrides['validatorMaxFileSize'] ?? validatorMaxFileSize,
    validatorMaxFiles: overrides['validatorMaxFiles'] ?? validatorMaxFiles,
    validatorEqualsField: overrides['validatorEqualsField'] ?? validatorEqualsField,
    validatorCompareField: overrides['validatorCompareField'] ?? validatorCompareField,
  );

  /// One phrase by key name, or `null` for an unknown key.
  String? operator [](String key) => toMap()[key];

  @override
  bool operator ==(Object other) {
    if (other is! UiFbStrings) return false;
    final a = toMap();
    final b = other.toMap();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// English (the default).
const UiFbStrings uiFbStringsEn = UiFbStrings(

  // Buttons and progress
  submit: 'Submit',
  saveChanges: 'Save changes',
  next: 'Continue',
  back: 'Back',
  stepOf: 'Step {n} of {total}',

  // Error summary and change list
  problemOne: 'There is a problem',
  problemMany: 'There are {n} problems',
  errorLabel: 'Error:',
  changeOne: '1 change',
  changeMany: '{n} changes',
  noChanges: 'No changes',
  empty: 'Empty',

  // Answers
  yes: 'Yes',
  no: 'No',
  notAnswered: 'Not answered',
  optional: '(optional)',
  calculatedHint: 'Worked out as you answer',
  noLongerOption: '{value} (no longer an option)',
  noLongerOffered: '{label} (no longer offered)',

  // Repeating sections
  entryTitle: 'Entry {n}',
  addAnother: 'Add another',
  nothingAdded: 'Nothing added yet.',
  noneAdded: 'None added.',
  remove: 'Remove {name}',
  moveUp: 'Move {name} up',
  moveDown: 'Move {name} down',
  entryAdded: '{name} added',
  entryRemoved: '{name} removed.',
  entryRemovedAnnounce: '{name} removed. Undo is next to the add button.',
  entryRestored: '{name} restored',
  undo: 'Undo',

  // Controls
  choose: 'Choose…',
  selectDate: 'Select a date',
  fileUploadLabel: 'Click to upload',
  fileUploadHint: 'or drag & drop',
  uploading: 'Uploading…',
  uploadFailed: 'The file could not be uploaded. Try again.',
  checking: 'Checking…',

  // Lists searched from the app (source picker)
  searchSource: 'Search {name}…',
  search: 'Search…',
  clear: 'Clear',
  tryAgain: 'Try again',
  listUnavailable: 'This list isn’t available right now.',
  savedAnswer: 'Saved answer: {answer}.',
  chooseFirst: 'Choose {name} first.',
  typeToSearch: 'Type at least {n} characters to search.',
  loadFailed: 'Couldn’t load the list.',
  searching: 'Searching…',
  loadingMore: 'Loading more…',
  noMatches: 'No matches for “{query}”.',
  nothingToChoose: 'Nothing to choose from.',

  // Required
  requiredField: '{label} is required.',
  requiredQuestion: 'Answer “{label}”',
  requiredTick: '{label} must be ticked.',

  // Comparison and date words used inside messages
  compareEq: 'the same as',
  compareGt: 'more than',
  compareGte: 'at least',
  compareLt: 'less than',
  compareLte: 'at most',
  dateToday: 'today',
  dateInDays: '{n} days from today',
  dateDaysAgo: '{n} days ago',

  // Default messages of the built-in checks (key: "validator" + the check's type with a capital)
  validatorInvalid: '{label} is not valid.',
  validatorEmail: 'Enter an email address like name@example.com.',
  validatorUrl: 'Enter a web address like example.com.',
  validatorPhone: 'Enter a phone number, like +44 20 7946 0958.',
  validatorMinLength: '{label} must be at least {min} characters.',
  validatorMaxLength: '{label} must be {max} characters or fewer.',
  validatorMinWords: '{label} must be at least {min} words.',
  validatorMaxWords: '{label} must be {max} words or fewer.',
  validatorPattern: '{label} contains characters that are not allowed.',
  validatorMin: '{label} must be {min} or more.',
  validatorMax: '{label} must be {max} or less.',
  validatorInteger: '{label} must be a whole number.',
  validatorDecimalPlaces: '{label} can have at most {places} decimal places.',
  validatorMinDate: '{label} must be on or after {date}.',
  validatorMaxDate: '{label} must be on or before {date}.',
  validatorAgeAtLeast: 'You must be at least {years} years old.',
  validatorAgeAtMost: 'You must be {years} years old or younger.',
  validatorEarliestTime: '{label} must be {time} or later.',
  validatorLatestTime: '{label} must be {time} or earlier.',
  validatorMinSelected: 'Choose at least {count} options for {label}.',
  validatorMaxSelected: 'Choose no more than {count} options for {label}.',
  validatorFileType: 'Upload files of these types: {accept}.',
  validatorMaxFileSize: 'Each file must be {mb} MB or smaller.',
  validatorMaxFiles: 'Upload no more than {count} files.',
  validatorEqualsField: '{label} must match {field}.',
  validatorCompareField: '{label} must be {comparison} {field}.',
);

/// Dhivehi (Thaana). The same phrases and `{placeholders}` as English.
const UiFbStrings uiFbStringsDv = UiFbStrings(

  // Buttons and progress
  submit: 'ހުށަހަޅާ',
  saveChanges: 'ބަދަލުތައް ރައްކާކުރޭ',
  next: 'ކުރިއަށް',
  back: 'ފަހަތަށް',
  stepOf: 'ފިޔަވަޅު {total} އިން {n}',

  // Error summary and change list
  problemOne: 'މައްސަލައެއް ހުރެއެވެ',
  problemMany: '{n} މައްސަލަ ހުރެއެވެ',
  errorLabel: 'މައްސަލަ:',
  changeOne: 'ބަދަލު 1',
  changeMany: 'ބަދަލު {n}',
  noChanges: 'ބަދަލެއް ނެތް',
  empty: 'ހުސް',

  // Answers
  yes: 'އާނ',
  no: 'ނޫން',
  notAnswered: 'ޖަވާބެއް ނުދީ',
  optional: '(އިޚްތިޔާރީ)',
  calculatedHint: 'ޖަވާބު ދެއްވާ ވަރަކަށް ހިސާބުކުރެވޭނެ',
  noLongerOption: '{value} (މިހާރު ޚިޔާރެއް ނޫން)',
  noLongerOffered: '{label} (މިހާރު ހުށަހަޅާފައެއް ނުވޭ)',

  // Repeating sections
  entryTitle: 'އެންޓްރީ {n}',
  addAnother: 'އިތުރު އެއް އިތުރުކުރޭ',
  nothingAdded: 'އަދި އެއްވެސް އެއްޗެއް އިތުރެއް ނުކުރެއެވެ.',
  noneAdded: 'އެއްވެސް އެއްޗެއް އިތުރެއް ނުކުރެއެވެ.',
  remove: '{name} ނައްތާލާ',
  moveUp: '{name} މަތިއަށް ބަދަލުކުރޭ',
  moveDown: '{name} ތިރިއަށް ބަދަލުކުރޭ',
  entryAdded: '{name} އިތުރުކުރެވިއްޖެ',
  entryRemoved: '{name} ނައްތާލެވިއްޖެ.',
  entryRemovedAnnounce: '{name} ނައްތާލެވިއްޖެ. އަނބުރާކުރުމުގެ ބަޓަން އިތުރުކުރާ ބަޓަނުގެ ކައިރީގައި ހުރެއެވެ.',
  entryRestored: '{name} އަނބުރާ ލެވިއްޖެ',
  undo: 'އަނބުރާކުރޭ',

  // Controls
  choose: 'ހޮވާ…',
  selectDate: 'ތާރީޚެއް ހޮވާ',
  fileUploadLabel: 'ކްލިކްކޮށް އަޕްލޯޑް ކުރޭ',
  fileUploadHint: 'ނުވަތަ ދަމައިގެން ލާ',
  uploading: 'އަޕްލޯޑުކުރަނީ…',
  uploadFailed: 'ފައިލް އަޕްލޯޑު ނުކުރެވުނެވެ. އަލުން މަސައްކަތް ކުރައްވާ.',
  checking: 'ބަލަނީ…',

  // Lists searched from the app (source picker)
  searchSource: '{name} ހޯދާ…',
  search: 'ހޯދާ…',
  clear: 'ފޮހެލާ',
  tryAgain: 'އަލުން މަސައްކަތް ކުރޭ',
  listUnavailable: 'މި ލިސްޓް މިހާރު ލިބެން ނެތެވެ.',
  savedAnswer: 'ރައްކާކުރެވިފައިވާ ޖަވާބު: {answer}.',
  chooseFirst: 'ފުރަތަމަ {name} ހޮވާ.',
  typeToSearch: 'ހޯދުމަށް މަދުވެގެން {n} އަކުރު ޓައިޕްކުރައްވާ.',
  loadFailed: 'ލިސްޓް ލޯޑު ނުކުރެވުނެވެ.',
  searching: 'ހޯދަނީ…',
  loadingMore: 'އިތުރު ލޯޑުވަނީ…',
  noMatches: '“{query}” އާ ގުޅޭ އެއްޗެއް ނުފެނުނެވެ.',
  nothingToChoose: 'ހޮވަން އެއްޗެއް ނެތެވެ.',

  // Required
  requiredField: '{label} ފުރިހަމަ ކުރަންޖެހެއެވެ.',
  requiredQuestion: '“{label}” ގެ ޖަވާބު ދެއްވާ.',
  requiredTick: '{label} ޓިކްކުރަންޖެހެއެވެ.',

  // Comparison and date words used inside messages
  compareEq: 'އާ އެއްގޮތް',
  compareGt: 'އަށްވުރެ ބޮޑު',
  compareGte: 'އާ އެއްވަރު ނުވަތަ އެއަށްވުރެ ބޮޑު',
  compareLt: 'އަށްވުރެ ކުޑަ',
  compareLte: 'އާ އެއްވަރު ނުވަތަ އެއަށްވުރެ ކުޑަ',
  dateToday: 'މިއަދު',
  dateInDays: 'މިއަދުން {n} ދުވަސް ފަހުން',
  dateDaysAgo: '{n} ދުވަސް ކުރިން',

  // Default messages of the built-in checks (key: "validator" + the check's type with a capital)
  validatorInvalid: '{label} ރަނގަޅެއް ނޫނެވެ.',
  validatorEmail: 'name@example.com ފަދަ އީމެއިލް އެޑްރެހެއް ލިޔުއްވާ.',
  validatorUrl: 'example.com ފަދަ ވެބް އެޑްރެހެއް ލިޔުއްވާ.',
  validatorPhone: 'ފޯނު ނަންބަރެއް ލިޔުއްވާ، މިސާލަކަށް +960 777 1234.',
  validatorMinLength: '{label} ގައި މަދުވެގެން {min} އަކުރު ހުންނަންޖެހެއެވެ.',
  validatorMaxLength: '{label} ގައި {max} އަކުރަށްވުރެ ގިނަ ނުވާންވާނެއެވެ.',
  validatorMinWords: '{label} ގައި މަދުވެގެން {min} ބަސް ހުންނަންޖެހެއެވެ.',
  validatorMaxWords: '{label} ގައި {max} ބަހަށްވުރެ ގިނަ ނުވާންވާނެއެވެ.',
  validatorPattern: '{label} ގައި ބޭނުންކުރުމަށް ހުއްދަ ނުދެވޭ އަކުރުތައް ހިމެނިފައިވެއެވެ.',
  validatorMin: '{label} އަކީ {min} ނުވަތަ އެއަށްވުރެ ބޮޑު އަދަދެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorMax: '{label} އަކީ {max} ނުވަތަ އެއަށްވުރެ ކުޑަ އަދަދެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorInteger: '{label} އަކީ ފުރިހަމަ އަދަދެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorDecimalPlaces: '{label} ގައި ޑެސިމަލް ތަންތަން {places} އަށްވުރެ ގިނަ ނުވާންވާނެއެވެ.',
  validatorMinDate: '{label} އަކީ {date} ނުވަތަ އޭގެ ފަހުގެ ތާރީޚެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorMaxDate: '{label} އަކީ {date} ނުވަތަ އޭގެ ކުރީގެ ތާރީޚެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorAgeAtLeast: 'އުމުރު މަދުވެގެން {years} އަހަރު ވާންޖެހެއެވެ.',
  validatorAgeAtMost: 'އުމުރު {years} އަހަރު ނުވަތަ އެއަށްވުރެ ކުޑަ ވާންޖެހެއެވެ.',
  validatorEarliestTime: '{label} އަކީ {time} ނުވަތަ އޭގެ ފަހުގެ ވަގުތެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorLatestTime: '{label} އަކީ {time} ނުވަތަ އޭގެ ކުރީގެ ވަގުތެއް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorMinSelected: '{label} އަށް މަދުވެގެން {count} ޚިޔާރު ހޮވާ.',
  validatorMaxSelected: '{label} އަށް {count} ޚިޔާރަށްވުރެ ގިނަ ނުހޮވާ.',
  validatorFileType: 'މި ބާވަތްތަކުގެ ފައިލްތައް އަޕްލޯޑުކުރައްވާ: {accept}.',
  validatorMaxFileSize: 'ކޮންމެ ފައިލެއް {mb} އެމްބީ ނުވަތަ އެއަށްވުރެ ކުޑަ ވާންޖެހެއެވެ.',
  validatorMaxFiles: 'ފައިލް {count} އަށްވުރެ ގިނަ އަޕްލޯޑު ނުކުރައްވާ.',
  validatorEqualsField: '{label} އަކީ {field} އާ އެއްގޮތް ކަމުގައި ވާންޖެހެއެވެ.',
  validatorCompareField: '{label} އަކީ {field} {comparison} ކަމުގައި ވާންޖެހެއެވެ.',
);

/// The built-in tables, by language code.
const Map<String, UiFbStrings> uiFbStrings = {'en': uiFbStringsEn, 'dv': uiFbStringsDv};

/// Wording changes per language code, on top of the built-in table: `{'dv': {'submit': '…'}}`. The
/// inner keys are the [UiFbStrings] field names; a missing key keeps the built-in word and an unknown
/// key is ignored. (The web's `Partial<Record<string, Partial<UiFbStrings>>>`.)
typedef UiFbStringOverrides = Map<String, Map<String, String>>;

bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

UiFbStrings _table(String locale) {
  for (final k in uiFbStrings.keys) {
    if (_same(k, locale)) return uiFbStrings[k]!;
  }
  final base = locale.split(RegExp(r'[-_]'))[0];
  for (final k in uiFbStrings.keys) {
    if (_same(k, base)) return uiFbStrings[k]!;
  }
  return uiFbStringsEn;
}

/// The words for a language. Picks the table by exact code, then by base language (`dv-MV` uses `dv`),
/// else English. The overrides for the base language, then for the exact code, are laid on top. A
/// language with no built-in table but with overrides gets English plus those overrides.
UiFbStrings fbStrings(String? locale, [UiFbStringOverrides? overrides]) {
  final loc = locale == null || locale.isEmpty ? 'en' : locale;
  var out = _table(loc);
  if (overrides != null) {
    final base = loc.split(RegExp(r'[-_]'))[0];
    Iterable<Map<String, String>> pick(String code) => [for (final e in overrides.entries) if (_same(e.key, code)) e.value];
    for (final o in [if (!_same(base, loc)) ...pick(base), ...pick(loc)]) {
      out = out.merge(o);
    }
  }
  return out;
}

/// Fills `{name}` placeholders in a phrase; a missing or null value leaves the placeholder as written.
String fbFormat(String phrase, Map<String, Object?> vars) => phrase.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
  final v = vars[m.group(1)!];
  return v == null ? m.group(0)! : jsString(v);
});

/// Merges two sets of overrides, per key; [b] wins.
UiFbStringOverrides? mergeFbStringOverrides(UiFbStringOverrides? a, UiFbStringOverrides? b) {
  if (a == null || b == null) return a ?? b;
  final out = <String, Map<String, String>>{for (final e in a.entries) e.key: {...e.value}};
  for (final e in b.entries) {
    out[e.key] = {...?out[e.key], ...e.value};
  }
  return out;
}

/// Whether two sets of overrides say the same thing.
bool fbStringOverridesEqual(UiFbStringOverrides? a, UiFbStringOverrides? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final e in a.entries) {
    final o = b[e.key];
    if (o == null || o.length != e.value.length) return false;
    for (final p in e.value.entries) {
      if (o[p.key] != p.value) return false;
    }
  }
  return true;
}
