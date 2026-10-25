import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;

/// Fills `{name}` placeholders in [template] from [params] (0.46.0, the web `uiFormatString`). A
/// placeholder with no value is left as it is.
String uiFormatString(String template, Map<String, Object?> params) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => params.containsKey(m[1]) ? '${params[m[1]]}' : m[0]!);

/// The library's own words: names of icon-only buttons, default labels and the date names (the web
/// `UiStrings`, same keys). English by default; [UiStrings.dv] is a complete Dhivehi set. Give the
/// app's language with `UiConfig(strings: UiStrings.dv)` or `UiStrings(close: 'ބަންދުކުރޭ', …)` (the
/// rest stay English), switch at runtime with [UiThemeController.setStrings]. Read them with
/// `context.uiStrings`. Text from the app (titles, labels, items) is never here.
///
/// Placeholders (`{n}`, `{label}`, …) are filled with [uiFormatString]. The date keys ([locale],
/// [months], …) apply only when set; otherwise names come from `intl` in the app's locale.
@immutable
class UiStrings {
  const UiStrings({
    this.close = 'Close',
    this.dismiss = 'Dismiss',
    this.clear = 'Clear',
    this.clearAll = 'Clear all',
    this.clearSearch = 'Clear search',
    this.previousPage = 'Previous page',
    this.nextPage = 'Next page',
    this.previousMonth = 'Previous month',
    this.nextMonth = 'Next month',
    this.chooseDate = 'Choose a date',
    this.moreActions = 'More actions',
    this.uploadLabel = 'Tap to upload',
    this.uploadHint = 'or drag & drop',
    this.holdHint = 'Press and hold to confirm',
    this.confirmTitle = 'Are you sure?',
    this.confirm = 'Confirm',
    this.cancel = 'Cancel',
    this.zoomIn = 'Zoom in',
    this.zoomOut = 'Zoom out',
    this.placePinAtCentre = 'Place the pin at the centre',
    this.mapLocate = 'Show my location',
    this.mapLocationOff = 'Location is off',
    this.mapYourLocation = 'Your location',
    this.mapOpen = 'Open map',
    this.mapSearchArea = 'Search area',
    this.mapRadiusMeters = '{n} m',
    this.mapRadiusKilometers = '{n} km',
    this.googleSignIn = 'Sign in with Google',
    this.googleSignUp = 'Sign up with Google',
    this.googleContinue = 'Continue with Google',
    this.googleSignInShort = 'Sign in',
    this.sidebarToggle = 'Toggle navigation',
    this.sidebarClose = 'Close navigation',
    this.sidebarLabel = 'Navigation',
    this.loading = 'Loading…',
    this.previous = 'Previous',
    this.next = 'Next',
    this.previousSlide = 'Previous slide',
    this.nextSlide = 'Next slide',
    this.goToSlide = 'Go to slide {n}',
    this.carousel = 'Carousel',
    this.imageViewer = 'Image viewer',
    this.previousImage = 'Previous image',
    this.nextImage = 'Next image',
    this.resetView = 'Reset view',
    this.fit = 'Fit',
    this.fitPage = 'Fit page',
    this.fitToView = 'Fit to view',
    this.doubleTapToZoom = 'Double tap to zoom',
    this.play = 'Play',
    this.pause = 'Pause',
    this.seek = 'Seek',
    this.volume = 'Volume',
    this.playbackSpeed = 'Playback speed',
    this.fullscreen = 'Fullscreen',
    this.video = 'Video',
    this.mediaSet = 'Everything in this set',
    this.path = 'Path',
    this.open = 'Open',
    this.previewUnavailable = 'Preview not available for this file type.',
    this.emptyFolder = 'Empty folder',
    this.loadingPdf = 'Loading PDF viewer…',
    this.pageControls = 'Page controls',
    this.page = 'Page {n}',
    this.pageOf = 'Page {n} of {total}',
    this.pagination = 'Pagination',
    this.resizePanes = 'Resize panes',
    this.resize = 'Resize',
    this.breadcrumb = 'Breadcrumb',
    this.showMore = 'Show {n} more',
    this.onThisPage = 'On this page',
    this.otpLabel = 'One-time code',
    this.otpDigit = 'Digit {n}',
    this.remove = 'Remove {label}',
    this.showPassword = 'Show password',
    this.hidePassword = 'Hide password',
    this.pickColor = 'Pick colour',
    this.hexColor = 'Hex colour',
    this.hue = 'Hue',
    this.commandPalette = 'Command palette',
    this.commandPlaceholder = 'Type a command or search…',
    this.noResults = 'No results',
    this.searchPlaceholder = 'Search…',
    this.selectPlaceholder = 'Select…',
    this.datePlaceholder = 'Select a date',
    this.chooseTime = 'Choose a time',
    this.previousYear = 'Previous year',
    this.nextYear = 'Next year',
    this.previousYears = 'Previous years',
    this.nextYears = 'Next years',
    this.monthsOf = 'Months of {n}',
    this.yearsRange = 'Years {n}',
    this.dateRange = 'From {start} to {end}',
    this.emptyHeading = 'Nothing here yet',
    this.noData = 'No data',
    this.empty = 'Empty',
    this.selectAll = 'Select all',
    this.selectAllRows = 'Select all rows',
    this.selectRow = 'Select row {n}',
    this.actions = 'Actions',
    this.options = 'Options',
    this.tabs = 'Tabs',
    this.progress = 'Progress',
    this.rating = 'Rating',
    this.meterWarn = 'Getting large',
    this.meterDanger = 'Over the limit',
    this.decrease = 'Decrease {label}',
    this.increase = 'Increase {label}',
    this.addTag = 'Add tag…',
    this.menu = 'Menu',
    this.showMenu = 'Show menu',
    this.move = 'Move',
    this.dragHint = 'Drag, or use the arrow keys',
    this.rotate = 'Rotate',
    this.playhead = 'Playhead',
    this.dragToReorder = 'Drag to reorder',
    this.mapShowBoth = 'Show both',
    this.mapLabel = 'Map',
    this.mapChosenLocation = 'Chosen location',
    this.mapResetNorth = 'Reset to north',
    this.navLabel = 'Navigation',
    this.navIn = 'in {distance}',
    this.navThen = 'Then',
    this.navArrive = 'Arrive',
    this.navRecenter = 'Recenter',
    this.navEnd = 'End',
    this.navMinutes = '{min} min',
    this.navHours = '{h} h',
    this.navHoursMinutes = '{h} h {min} min',
    this.navMeters = '{n} m',
    this.navKilometers = '{n} km',
    this.navSummary = '{time} left, {distance}, arrive at {clock}',
    this.adding = 'Adding {label}',
    this.today = 'Today',
    this.notSet = 'Not set',
    this.chooseMonth = 'Choose month, {label}',
    this.chooseYear = 'Choose year, {label}',
    this.opensCalendar = 'Opens a calendar',
    this.opensTimePicker = 'Opens a time picker',
    this.hours = 'Hours',
    this.minutes = 'Minutes',
    this.seconds = 'Seconds',
    this.cut = 'Cut',
    this.copy = 'Copy',
    this.paste = 'Paste',
    this.delete = 'Delete',
    this.lookUp = 'Look up',
    this.searchWeb = 'Search',
    this.share = 'Share',
    this.scanText = 'Scan text',
    this.fieldRequired = '{label} is required',
    this.thisField = 'This field',
    this.sheetSmaller = 'Make smaller',
    this.sheetLarger = 'Make larger',
    this.navigationOpen = 'Navigation open',
    this.currentStep = 'Current step',
    this.upcoming = 'Upcoming',
    this.openImage = 'Open image',
    this.image = 'Image',
    this.meter = 'Meter',
    this.chosenFiles = 'Chosen files',
    this.slider = 'Slider',
    this.locale = '',
    this.months = const [],
    this.monthsShort = const [],
    this.weekdays = const [],
    this.weekdaysShort = const [],
    this.firstDayOfWeek,
    this.dateFormat = '',
    this.dateFormatShort = '',
    this.monthYearFormat = '',
  });

  /// Every built-in word in Dhivehi (Thaana), with Dhivehi month and day names, Sunday-first weeks
  /// and day-month-year dates (0.46.0). Pair it with right-to-left text direction
  /// (`UiApp(textDirection: TextDirection.rtl)`, or a `dv` locale) and a Thaana font
  /// ([UiConfig.fontFamilyFallback]).
  static const UiStrings dv = UiStrings(
    close: 'ބަންދުކުރޭ',
    dismiss: 'ފޮރުވާލާ',
    clear: 'ފޮހެލާ',
    clearAll: 'ހުރިހާ އެއްޗެއް ފޮހެލާ',
    clearSearch: 'ހޯދުން ފޮހެލާ',
    previousPage: 'ކުރީ ޞަފްޙާ',
    nextPage: 'ދެން އޮތް ޞަފްޙާ',
    previousMonth: 'ކުރީ މަސް',
    nextMonth: 'ދެން އޮތް މަސް',
    chooseDate: 'ތާރީޚެއް ހޮވާ',
    moreActions: 'އިތުރު ކަންކަން',
    uploadLabel: 'ފިތާލާ އަޕްލޯޑް ކުރޭ',
    uploadHint: 'ނުވަތަ ދަމައިގެން ލާ',
    holdHint: 'ކަށަވަރުކުރަން ފިތާލައިގެން ހިފަހައްޓާ',
    confirmTitle: 'ޔަގީންތޯ؟',
    confirm: 'ކަށަވަރުކުރޭ',
    cancel: 'ކެންސަލް',
    zoomIn: 'ބޮޑުކުރޭ',
    zoomOut: 'ކުޑަކުރޭ',
    placePinAtCentre: 'ޕިން މެދަށް ލާ',
    mapLocate: 'އަހަރެން ހުރި ތަން ދައްކާ',
    mapLocationOff: 'ލޮކޭޝަން ނިވާލާފައި',
    mapYourLocation: 'ތިބާ ހުރި ތަން',
    mapOpen: 'މެޕް ހުޅުވާ',
    mapSearchArea: 'ހޯދާ ސަރަހައްދު',
    mapRadiusMeters: '{n} މީޓަރު',
    mapRadiusKilometers: '{n} ކިލޯމީޓަރު',
    googleSignIn: 'ގޫގުލްއިން ސައިން އިން ކުރޭ',
    googleSignUp: 'ގޫގުލްއިން ސައިން އަޕް ކުރޭ',
    googleContinue: 'ގޫގުލްއިން ކުރިއަށް',
    googleSignInShort: 'ސައިން އިން',
    sidebarToggle: 'މެނޫ',
    sidebarClose: 'މެނޫ ބަންދުކުރޭ',
    sidebarLabel: 'ނެވިގޭޝަން',
    loading: 'ލޯޑުވަނީ…',
    previous: 'ކުރީގެ',
    next: 'ދެން',
    previousSlide: 'ކުރީ ސްލައިޑް',
    nextSlide: 'ދެން އޮތް ސްލައިޑް',
    goToSlide: 'ސްލައިޑް {n} އަށް',
    carousel: 'ސްލައިޑްތައް',
    imageViewer: 'ފޮޓޯ ބަލާ',
    previousImage: 'ކުރީ ފޮޓޯ',
    nextImage: 'ދެން އޮތް ފޮޓޯ',
    resetView: 'ފުރަތަމަ ގޮތަށް',
    fit: 'ފިޓް',
    fitPage: 'ޞަފްޙާ ފިޓްކުރޭ',
    fitToView: 'ފެންނަ ގޮތަށް ފިޓްކުރޭ',
    doubleTapToZoom: 'ބޮޑުކުރަން ދެފަހަރު ފިތާލާ',
    play: 'ޕްލޭ',
    pause: 'ހުއްޓާ',
    seek: 'ތަން ބަދަލުކުރޭ',
    volume: 'އަޑު',
    playbackSpeed: 'ޕްލޭ ކުރާ މިންވަރު',
    fullscreen: 'ފުލް ސްކްރީން',
    video: 'ވީޑިއޯ',
    mediaSet: 'މި ސެޓްގައި ހުރިހާ އެއްޗެއް',
    path: 'މަގު',
    open: 'ހުޅުވާ',
    previewUnavailable: 'މި ބާވަތުގެ ފައިލް ބަލާކަށް ނުކެރޭ.',
    emptyFolder: 'ފޯލްޑަރު ހުސް',
    loadingPdf: 'ޕީޑީއެފް ލޯޑުވަނީ…',
    pageControls: 'ޞަފްޙާގެ ކޮންޓްރޯލް',
    page: 'ޞަފްޙާ {n}',
    pageOf: 'ޞަފްޙާ {n} / {total}',
    pagination: 'ޞަފްޙާތައް',
    resizePanes: 'ބައިތަކުގެ ސައިޒް ބަދަލުކުރޭ',
    resize: 'ސައިޒް ބަދަލުކުރޭ',
    breadcrumb: 'ތިބާ މިހުރި ތަން',
    showMore: 'އިތުރު {n} ދައްކާ',
    onThisPage: 'މި ޞަފްޙާގައި',
    otpLabel: 'އެއްފަހަރު ބޭނުންކުރާ ކޯޑު',
    otpDigit: 'ނަންބަރު {n}',
    remove: '{label} ނައްތާލާ',
    showPassword: 'ޕާސްވޯޑް ދައްކާ',
    hidePassword: 'ޕާސްވޯޑް ފޮރުވާ',
    pickColor: 'ކުލައެއް ހޮވާ',
    hexColor: 'ހެކްސް ކުލަ',
    hue: 'ކުލަ',
    commandPalette: 'ކޮމާންޑުތައް',
    commandPlaceholder: 'ކޮމާންޑެއް ލިޔޭ ނުވަތަ ހޯދާ…',
    noResults: 'އެއްވެސް އެއްޗެއް ނުފެނުނު',
    searchPlaceholder: 'ހޯދާ…',
    selectPlaceholder: 'ހޮވާ…',
    datePlaceholder: 'ތާރީޚެއް ހޮވާ',
    chooseTime: 'ވަގުތެއް ހޮވާ',
    previousYear: 'ކުރީ އަހަރު',
    nextYear: 'ދެން އޮތް އަހަރު',
    previousYears: 'ކުރީ އަހަރުތައް',
    nextYears: 'ދެން އޮތް އަހަރުތައް',
    monthsOf: '{n} ގެ މަސްތައް',
    yearsRange: 'އަހަރުތައް {n}',
    dateRange: '{start} އިން {end} އަށް',
    emptyHeading: 'މިތާ އަދި އެއްވެސް އެއްޗެއް ނެތް',
    noData: 'މަޢުލޫމާތެއް ނެތް',
    empty: 'ހުސް',
    selectAll: 'ހުރިހާ އެއްޗެއް ހޮވާ',
    selectAllRows: 'ހުރިހާ ލައިނެއް ހޮވާ',
    selectRow: 'ލައިން {n} ހޮވާ',
    actions: 'ކަންކަން',
    options: 'އިޚްތިޔާރުތައް',
    tabs: 'ޓެބްތައް',
    progress: 'ކުރިއެރުން',
    rating: 'ރޭޓިންގ',
    meterWarn: 'ބޮޑުވަމުން',
    meterDanger: 'ހައްދަށްވުރެ ބޮޑު',
    decrease: '{label} ކުޑަކުރޭ',
    increase: '{label} ބޮޑުކުރޭ',
    addTag: 'ޓެގެއް އިތުރުކުރޭ…',
    menu: 'މެނޫ',
    showMenu: 'މެނޫ ދައްކާ',
    move: 'ތަން ބަދަލުކުރޭ',
    dragHint: 'ދަމާ، ނުވަތަ އެރޯ ކީތައް ބޭނުންކުރޭ',
    rotate: 'އަނބުރާ',
    playhead: 'ޕްލޭހެޑް',
    dragToReorder: 'ތަރުތީބު ބަދަލުކުރަން ދަމާ',
    mapShowBoth: 'ދެބައިވެސް ދައްކާ',
    mapLabel: 'މެޕް',
    mapChosenLocation: 'ހޮވި ތަން',
    mapResetNorth: 'އުތުރު މައްޗަށް ގެންނާ',
    navLabel: 'މަގު ދެއްކުން',
    navIn: '{distance} ދުރުން',
    navThen: 'ދެން',
    navArrive: 'ވާސިލުވުން',
    navRecenter: 'މެދަށް ގެންނާ',
    navEnd: 'ނިންމާ',
    navMinutes: '{min} މިނެޓު',
    navHours: '{h} ގަޑިއިރު',
    navHoursMinutes: '{h} ގަޑިއިރު {min} މިނެޓު',
    navMeters: '{n} މީޓަރު',
    navKilometers: '{n} ކިލޯމީޓަރު',
    navSummary: '{time} ބާކީ، {distance}، {clock} ގައި ވާސިލުވާނެ',
    adding: '{label} އިތުރުކުރަނީ',
    today: 'މިއަދު',
    notSet: 'ކަނޑައަޅާފައެއް ނެތް',
    chooseMonth: 'މަސް ހޮވާ، {label}',
    chooseYear: 'އަހަރު ހޮވާ، {label}',
    opensCalendar: 'ކަލަންޑަރު ހުޅުވޭ',
    opensTimePicker: 'ވަގުތު ހޮވާ ތަން ހުޅުވޭ',
    hours: 'ގަޑި',
    minutes: 'މިނެޓު',
    seconds: 'ސިކުންތު',
    cut: 'ކަޓް',
    copy: 'ކޮޕީ',
    paste: 'ޕޭސްޓް',
    delete: 'ފޮހެލާ',
    lookUp: 'ބަލާ',
    searchWeb: 'ހޯދާ',
    share: 'ޝެއާ',
    scanText: 'ލިޔުން ސްކޭން ކުރޭ',
    fieldRequired: '{label} ލާޒިމް',
    thisField: 'މި ބައި',
    sheetSmaller: 'ކުޑަކުރޭ',
    sheetLarger: 'ބޮޑުކުރޭ',
    navigationOpen: 'ނެވިގޭޝަން ހުޅުވިފައި',
    currentStep: 'މިހާރު މިހުރި ފިޔަވަޅު',
    upcoming: 'ކުރިއަށް އޮތް',
    openImage: 'ފޮޓޯ ހުޅުވާ',
    image: 'ފޮޓޯ',
    meter: 'މީޓަރު',
    chosenFiles: 'ހޮވި ފައިލްތައް',
    slider: 'ސްލައިޑަރު',
    locale: 'dv',
    months: ['ޖަނަވަރީ', 'ފެބުރުއަރީ', 'މާރިޗު', 'އެޕްރީލް', 'މޭ', 'ޖޫން', 'ޖުލައި', 'އޯގަސްޓު', 'ސެޕްޓެމްބަރު', 'އޮކްޓޫބަރު', 'ނޮވެމްބަރު', 'ޑިސެމްބަރު'],
    monthsShort: ['ޖަނަވަރީ', 'ފެބުރުއަރީ', 'މާރިޗު', 'އެޕްރީލް', 'މޭ', 'ޖޫން', 'ޖުލައި', 'އޯގަސްޓު', 'ސެޕްޓެމްބަރު', 'އޮކްޓޫބަރު', 'ނޮވެމްބަރު', 'ޑިސެމްބަރު'],
    weekdays: ['އާދިއްތަ', 'ހޯމަ', 'އަންގާރަ', 'ބުދަ', 'ބުރާސްފަތި', 'ހުކުރު', 'ހޮނިހިރު'],
    weekdaysShort: ['އާދި', 'ހޯމަ', 'އަން', 'ބުދަ', 'ބުރާ', 'ހުކު', 'ހޮނި'],
    firstDayOfWeek: 0,
    dateFormat: '{d} {month} {y}',
    dateFormatShort: '{d} {month} {y}',
    monthYearFormat: '{month} {y}',
  );

  /// Close buttons of modal, drawer, bottom sheet, lightbox, window, gallery.
  final String close;

  /// Dismiss buttons of toast, alert, hint.
  final String dismiss;

  /// Combobox clear button.
  final String clear;

  /// Multi-select clear button.
  final String clearAll;

  /// Search input clear button.
  final String clearSearch;

  /// Pagination and PDF viewer arrows.
  final String previousPage;

  /// Pagination and PDF viewer arrows.
  final String nextPage;

  /// Calendar arrows.
  final String previousMonth;

  /// Calendar arrows.
  final String nextMonth;

  /// The date picker's calendar dialog.
  final String chooseDate;

  /// The split button's menu button.
  final String moreActions;

  /// File upload: the action, in bold ("Tap" on a phone, where the web says "Click").
  final String uploadLabel;

  /// File upload: what follows the action when drops are enabled.
  final String uploadHint;

  /// Hold button: what holding does (read with the button).
  final String holdHint;

  /// Confirm dialog (hold button, showUiConfirm) title.
  final String confirmTitle;

  /// Confirm dialog action.
  final String confirm;

  /// Confirm dialog cancel.
  final String cancel;

  /// Zoom buttons (map, image viewer, PDF viewer, canvas).
  final String zoomIn;

  /// Zoom buttons (map, image viewer, PDF viewer, canvas).
  final String zoomOut;

  /// Map: placing the pin at the centre (keyboard / screen reader).
  final String placePinAtCentre;

  /// Map: the "my location" button.
  final String mapLocate;

  /// Map: the locate button when location is off or denied.
  final String mapLocationOff;

  /// Map: the "you are here" dot.
  final String mapYourLocation;

  /// Map preview: the button that opens the full map.
  final String mapOpen;

  /// Map search area: the radius handle.
  final String mapSearchArea;

  /// Map search area radius in metres ({n}).
  final String mapRadiusMeters;

  /// Map search area radius in kilometres ({n}).
  final String mapRadiusKilometers;

  /// Google sign-in button wording (keep the meaning: signing in with a Google account).
  final String googleSignIn;

  /// Google sign-in button wording.
  final String googleSignUp;

  /// Google sign-in button wording.
  final String googleContinue;

  /// Google sign-in button, icon-and-short form.
  final String googleSignInShort;

  /// Sidebar layout: the menu button.
  final String sidebarToggle;

  /// Sidebar layout: the drawer's close control (backdrop).
  final String sidebarClose;

  /// Sidebar layout: the drawer's name.
  final String sidebarLabel;

  /// Spinner default name, intro loader, text viewers, image picker loading.
  final String loading;

  /// Lightbox / gallery previous.
  final String previous;

  /// Lightbox / gallery next.
  final String next;

  /// Carousel arrow.
  final String previousSlide;

  /// Carousel arrow.
  final String nextSlide;

  /// Carousel dot ({n}).
  final String goToSlide;

  /// Carousel default name.
  final String carousel;

  /// Gallery viewer dialog name.
  final String imageViewer;

  /// Image viewer arrow.
  final String previousImage;

  /// Image viewer arrow.
  final String nextImage;

  /// Image viewer / lightbox: back to fit.
  final String resetView;

  /// The "Fit" button text (image and PDF viewers).
  final String fit;

  /// PDF viewer fit button name.
  final String fitPage;

  /// Canvas viewport fit button (web only today).
  final String fitToView;

  /// Image viewer hint (Flutter).
  final String doubleTapToZoom;

  /// Media play.
  final String play;

  /// Media pause.
  final String pause;

  /// Media seek bar.
  final String seek;

  /// Media volume.
  final String volume;

  /// Media playback speed.
  final String playbackSpeed;

  /// Video fullscreen (web).
  final String fullscreen;

  /// Video player name.
  final String video;

  /// Lightbox thumbnail strip (web).
  final String mediaSet;

  /// File explorer path.
  final String path;

  /// File viewer: open externally.
  final String open;

  /// File viewer: no preview.
  final String previewUnavailable;

  /// File explorer: empty folder.
  final String emptyFolder;

  /// File viewer: PDF viewer loading (web).
  final String loadingPdf;

  /// PDF viewer controls group.
  final String pageControls;

  /// Page {n} (pagination, PDF viewer).
  final String page;

  /// Page {n} of {total} (pagination).
  final String pageOf;

  /// Pagination default name.
  final String pagination;

  /// Splitter gutter.
  final String resizePanes;

  /// Resize handle default name.
  final String resize;

  /// Breadcrumbs default name.
  final String breadcrumb;

  /// Breadcrumbs collapsed items ({n}).
  final String showMore;

  /// Anchor nav default name.
  final String onThisPage;

  /// OTP input group.
  final String otpLabel;

  /// OTP input box ({n}).
  final String otpDigit;

  /// Remove buttons of chips, multi-select and chip input ({label}).
  final String remove;

  /// Password input reveal toggle.
  final String showPassword;

  /// Password input reveal toggle.
  final String hidePassword;

  /// Colour picker swatch.
  final String pickColor;

  /// Colour picker hex field.
  final String hexColor;

  /// Colour picker hue slider.
  final String hue;

  /// Command palette name.
  final String commandPalette;

  /// Command palette placeholder.
  final String commandPlaceholder;

  /// Listbox, combobox and command palette empty text.
  final String noResults;

  /// Search input and combobox placeholder.
  final String searchPlaceholder;

  /// Multi-select placeholder.
  final String selectPlaceholder;

  /// Date picker placeholder.
  final String datePlaceholder;

  /// Time picker dialog.
  final String chooseTime;

  /// Calendar month view arrows.
  final String previousYear;

  /// Calendar month view arrows.
  final String nextYear;

  /// Calendar year view arrows.
  final String previousYears;

  /// Calendar year view arrows.
  final String nextYears;

  /// Calendar month grid ({n} is the year).
  final String monthsOf;

  /// Calendar year grid ({n} is the range).
  final String yearsRange;

  /// Date range picker value ({start}, {end}).
  final String dateRange;

  /// Empty state default heading; sequencer empty text.
  final String emptyHeading;

  /// Table empty text.
  final String noData;

  /// Editable text placeholder.
  final String empty;

  /// Checkbox group select-all.
  final String selectAll;

  /// Table header checkbox.
  final String selectAllRows;

  /// Table row checkbox ({n}).
  final String selectRow;

  /// Table actions column.
  final String actions;

  /// Segmented default name.
  final String options;

  /// Tabs default name.
  final String tabs;

  /// Progress bar / circle default name.
  final String progress;

  /// Rating default name.
  final String rating;

  /// Meter warning text.
  final String meterWarn;

  /// Meter danger text.
  final String meterDanger;

  /// Number input stepper ({label}).
  final String decrease;

  /// Number input stepper ({label}).
  final String increase;

  /// Chip input placeholder.
  final String addTag;

  /// Menubar overflow button.
  final String menu;

  /// Context menu hint.
  final String showMenu;

  /// Drag-move default name.
  final String move;

  /// Drag-move hint.
  final String dragHint;

  /// Transform box rotate handle (web).
  final String rotate;

  /// Sequencer playhead.
  final String playhead;

  /// Sequencer rows (web).
  final String dragToReorder;

  /// Map: a "fit both points" custom control (the app adds it; the library names it).
  final String mapShowBoth;

  /// Map default name.
  final String mapLabel;

  /// Map pin default name.
  final String mapChosenLocation;

  /// The map's compass button, which turns it back to north up (0.47.0).
  final String mapResetNorth;

  /// Navigation view's name (0.47.0).
  final String navLabel;

  /// Distance to the next maneuver (`{distance}`, e.g. "80 m").
  final String navIn;

  /// Before the maneuver after next.
  final String navThen;

  /// The arrive step's heading when it has no instruction.
  final String navArrive;

  /// Button that brings the map back to following the person.
  final String navRecenter;

  /// Button that ends navigation.
  final String navEnd;

  /// Time left under an hour (`{min}`).
  final String navMinutes;

  /// Time left in whole hours (`{h}`).
  final String navHours;

  /// Time left over an hour (`{h}`, `{min}`).
  final String navHoursMinutes;

  /// A distance in metres (`{n}`).
  final String navMeters;

  /// A distance in kilometres (`{n}`).
  final String navKilometers;

  /// The bottom bar for screen readers (`{time}`, `{distance}`, `{clock}`).
  final String navSummary;

  /// Image picker busy tile ({label}).
  final String adding;

  /// Calendar: the hint on today.
  final String today;

  /// Date range picker: an end not chosen yet.
  final String notSet;

  /// Calendar heading month button ({label} is the month).
  final String chooseMonth;

  /// Calendar heading year button ({label} is the year).
  final String chooseYear;

  /// Date picker field hint.
  final String opensCalendar;

  /// Time picker field hint.
  final String opensTimePicker;

  /// Time picker columns.
  final String hours;

  /// Time picker columns.
  final String minutes;

  /// Time picker columns.
  final String seconds;

  /// Text field selection menu.
  final String cut;

  /// Text field selection menu.
  final String copy;

  /// Text field selection menu.
  final String paste;

  /// Text field selection menu.
  final String delete;

  /// Text field selection menu.
  final String lookUp;

  /// Text field selection menu.
  final String searchWeb;

  /// Text field selection menu.
  final String share;

  /// Text field selection menu.
  final String scanText;

  /// Form field required message ({label} is the field label).
  final String fieldRequired;

  /// Form field required message when the field has no label.
  final String thisField;

  /// Bottom sheet grip at its largest size.
  final String sheetSmaller;

  /// Bottom sheet grip.
  final String sheetLarger;

  /// Sidebar layout menu button hint while open.
  final String navigationOpen;

  /// Timeline: the current item.
  final String currentStep;

  /// Timeline: an upcoming item.
  final String upcoming;

  /// Gallery thumbnail without alt text.
  final String openImage;

  /// Image viewer without alt text.
  final String image;

  /// Meter default name.
  final String meter;

  /// File upload: the list of chosen files.
  final String chosenFiles;

  /// Slider default name.
  final String slider;

  /// The locale for date names and formats, e.g. 'dv'; empty uses the app's locale.
  final String locale;

  /// Month names, January first (12), long and short; empty takes them from `intl`.
  final List<String> months, monthsShort;

  /// Weekday names, Sunday first (7), long and short (the calendar columns); empty takes them from
  /// `intl`.
  final List<String> weekdays, weekdaysShort;

  /// The calendars' first column: 0 Sunday … 6 Saturday. Null takes it from the locale (Sunday when
  /// the locale has no data).
  final int? firstDayOfWeek;

  /// Date patterns with `{d}`, `{month}`, `{y}` ("{d} {month} {y}"); used only with [months] /
  /// [monthsShort] set. Empty uses the locale's own long / short date and month-year formats.
  final String dateFormat, dateFormatShort, monthYearFormat;

  /// A copy with some words replaced (e.g. `UiStrings.dv.copyWith(close: …)`).
  UiStrings copyWith({
    String? close,
    String? dismiss,
    String? clear,
    String? clearAll,
    String? clearSearch,
    String? previousPage,
    String? nextPage,
    String? previousMonth,
    String? nextMonth,
    String? chooseDate,
    String? moreActions,
    String? uploadLabel,
    String? uploadHint,
    String? holdHint,
    String? confirmTitle,
    String? confirm,
    String? cancel,
    String? zoomIn,
    String? zoomOut,
    String? placePinAtCentre,
    String? mapLocate,
    String? mapLocationOff,
    String? mapYourLocation,
    String? mapOpen,
    String? mapSearchArea,
    String? mapRadiusMeters,
    String? mapRadiusKilometers,
    String? googleSignIn,
    String? googleSignUp,
    String? googleContinue,
    String? googleSignInShort,
    String? sidebarToggle,
    String? sidebarClose,
    String? sidebarLabel,
    String? loading,
    String? previous,
    String? next,
    String? previousSlide,
    String? nextSlide,
    String? goToSlide,
    String? carousel,
    String? imageViewer,
    String? previousImage,
    String? nextImage,
    String? resetView,
    String? fit,
    String? fitPage,
    String? fitToView,
    String? doubleTapToZoom,
    String? play,
    String? pause,
    String? seek,
    String? volume,
    String? playbackSpeed,
    String? fullscreen,
    String? video,
    String? mediaSet,
    String? path,
    String? open,
    String? previewUnavailable,
    String? emptyFolder,
    String? loadingPdf,
    String? pageControls,
    String? page,
    String? pageOf,
    String? pagination,
    String? resizePanes,
    String? resize,
    String? breadcrumb,
    String? showMore,
    String? onThisPage,
    String? otpLabel,
    String? otpDigit,
    String? remove,
    String? showPassword,
    String? hidePassword,
    String? pickColor,
    String? hexColor,
    String? hue,
    String? commandPalette,
    String? commandPlaceholder,
    String? noResults,
    String? searchPlaceholder,
    String? selectPlaceholder,
    String? datePlaceholder,
    String? chooseTime,
    String? previousYear,
    String? nextYear,
    String? previousYears,
    String? nextYears,
    String? monthsOf,
    String? yearsRange,
    String? dateRange,
    String? emptyHeading,
    String? noData,
    String? empty,
    String? selectAll,
    String? selectAllRows,
    String? selectRow,
    String? actions,
    String? options,
    String? tabs,
    String? progress,
    String? rating,
    String? meterWarn,
    String? meterDanger,
    String? decrease,
    String? increase,
    String? addTag,
    String? menu,
    String? showMenu,
    String? move,
    String? dragHint,
    String? rotate,
    String? playhead,
    String? dragToReorder,
    String? mapShowBoth,
    String? mapLabel,
    String? mapChosenLocation,
    String? mapResetNorth,
    String? navLabel,
    String? navIn,
    String? navThen,
    String? navArrive,
    String? navRecenter,
    String? navEnd,
    String? navMinutes,
    String? navHours,
    String? navHoursMinutes,
    String? navMeters,
    String? navKilometers,
    String? navSummary,
    String? adding,
    String? today,
    String? notSet,
    String? chooseMonth,
    String? chooseYear,
    String? opensCalendar,
    String? opensTimePicker,
    String? hours,
    String? minutes,
    String? seconds,
    String? cut,
    String? copy,
    String? paste,
    String? delete,
    String? lookUp,
    String? searchWeb,
    String? share,
    String? scanText,
    String? fieldRequired,
    String? thisField,
    String? sheetSmaller,
    String? sheetLarger,
    String? navigationOpen,
    String? currentStep,
    String? upcoming,
    String? openImage,
    String? image,
    String? meter,
    String? chosenFiles,
    String? slider,
    String? locale,
    List<String>? months,
    List<String>? monthsShort,
    List<String>? weekdays,
    List<String>? weekdaysShort,
    int? firstDayOfWeek,
    String? dateFormat,
    String? dateFormatShort,
    String? monthYearFormat,
  }) =>
      UiStrings(
        close: close ?? this.close,
        dismiss: dismiss ?? this.dismiss,
        clear: clear ?? this.clear,
        clearAll: clearAll ?? this.clearAll,
        clearSearch: clearSearch ?? this.clearSearch,
        previousPage: previousPage ?? this.previousPage,
        nextPage: nextPage ?? this.nextPage,
        previousMonth: previousMonth ?? this.previousMonth,
        nextMonth: nextMonth ?? this.nextMonth,
        chooseDate: chooseDate ?? this.chooseDate,
        moreActions: moreActions ?? this.moreActions,
        uploadLabel: uploadLabel ?? this.uploadLabel,
        uploadHint: uploadHint ?? this.uploadHint,
        holdHint: holdHint ?? this.holdHint,
        confirmTitle: confirmTitle ?? this.confirmTitle,
        confirm: confirm ?? this.confirm,
        cancel: cancel ?? this.cancel,
        zoomIn: zoomIn ?? this.zoomIn,
        zoomOut: zoomOut ?? this.zoomOut,
        placePinAtCentre: placePinAtCentre ?? this.placePinAtCentre,
        mapLocate: mapLocate ?? this.mapLocate,
        mapLocationOff: mapLocationOff ?? this.mapLocationOff,
        mapYourLocation: mapYourLocation ?? this.mapYourLocation,
        mapOpen: mapOpen ?? this.mapOpen,
        mapSearchArea: mapSearchArea ?? this.mapSearchArea,
        mapRadiusMeters: mapRadiusMeters ?? this.mapRadiusMeters,
        mapRadiusKilometers: mapRadiusKilometers ?? this.mapRadiusKilometers,
        googleSignIn: googleSignIn ?? this.googleSignIn,
        googleSignUp: googleSignUp ?? this.googleSignUp,
        googleContinue: googleContinue ?? this.googleContinue,
        googleSignInShort: googleSignInShort ?? this.googleSignInShort,
        sidebarToggle: sidebarToggle ?? this.sidebarToggle,
        sidebarClose: sidebarClose ?? this.sidebarClose,
        sidebarLabel: sidebarLabel ?? this.sidebarLabel,
        loading: loading ?? this.loading,
        previous: previous ?? this.previous,
        next: next ?? this.next,
        previousSlide: previousSlide ?? this.previousSlide,
        nextSlide: nextSlide ?? this.nextSlide,
        goToSlide: goToSlide ?? this.goToSlide,
        carousel: carousel ?? this.carousel,
        imageViewer: imageViewer ?? this.imageViewer,
        previousImage: previousImage ?? this.previousImage,
        nextImage: nextImage ?? this.nextImage,
        resetView: resetView ?? this.resetView,
        fit: fit ?? this.fit,
        fitPage: fitPage ?? this.fitPage,
        fitToView: fitToView ?? this.fitToView,
        doubleTapToZoom: doubleTapToZoom ?? this.doubleTapToZoom,
        play: play ?? this.play,
        pause: pause ?? this.pause,
        seek: seek ?? this.seek,
        volume: volume ?? this.volume,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        fullscreen: fullscreen ?? this.fullscreen,
        video: video ?? this.video,
        mediaSet: mediaSet ?? this.mediaSet,
        path: path ?? this.path,
        open: open ?? this.open,
        previewUnavailable: previewUnavailable ?? this.previewUnavailable,
        emptyFolder: emptyFolder ?? this.emptyFolder,
        loadingPdf: loadingPdf ?? this.loadingPdf,
        pageControls: pageControls ?? this.pageControls,
        page: page ?? this.page,
        pageOf: pageOf ?? this.pageOf,
        pagination: pagination ?? this.pagination,
        resizePanes: resizePanes ?? this.resizePanes,
        resize: resize ?? this.resize,
        breadcrumb: breadcrumb ?? this.breadcrumb,
        showMore: showMore ?? this.showMore,
        onThisPage: onThisPage ?? this.onThisPage,
        otpLabel: otpLabel ?? this.otpLabel,
        otpDigit: otpDigit ?? this.otpDigit,
        remove: remove ?? this.remove,
        showPassword: showPassword ?? this.showPassword,
        hidePassword: hidePassword ?? this.hidePassword,
        pickColor: pickColor ?? this.pickColor,
        hexColor: hexColor ?? this.hexColor,
        hue: hue ?? this.hue,
        commandPalette: commandPalette ?? this.commandPalette,
        commandPlaceholder: commandPlaceholder ?? this.commandPlaceholder,
        noResults: noResults ?? this.noResults,
        searchPlaceholder: searchPlaceholder ?? this.searchPlaceholder,
        selectPlaceholder: selectPlaceholder ?? this.selectPlaceholder,
        datePlaceholder: datePlaceholder ?? this.datePlaceholder,
        chooseTime: chooseTime ?? this.chooseTime,
        previousYear: previousYear ?? this.previousYear,
        nextYear: nextYear ?? this.nextYear,
        previousYears: previousYears ?? this.previousYears,
        nextYears: nextYears ?? this.nextYears,
        monthsOf: monthsOf ?? this.monthsOf,
        yearsRange: yearsRange ?? this.yearsRange,
        dateRange: dateRange ?? this.dateRange,
        emptyHeading: emptyHeading ?? this.emptyHeading,
        noData: noData ?? this.noData,
        empty: empty ?? this.empty,
        selectAll: selectAll ?? this.selectAll,
        selectAllRows: selectAllRows ?? this.selectAllRows,
        selectRow: selectRow ?? this.selectRow,
        actions: actions ?? this.actions,
        options: options ?? this.options,
        tabs: tabs ?? this.tabs,
        progress: progress ?? this.progress,
        rating: rating ?? this.rating,
        meterWarn: meterWarn ?? this.meterWarn,
        meterDanger: meterDanger ?? this.meterDanger,
        decrease: decrease ?? this.decrease,
        increase: increase ?? this.increase,
        addTag: addTag ?? this.addTag,
        menu: menu ?? this.menu,
        showMenu: showMenu ?? this.showMenu,
        move: move ?? this.move,
        dragHint: dragHint ?? this.dragHint,
        rotate: rotate ?? this.rotate,
        playhead: playhead ?? this.playhead,
        dragToReorder: dragToReorder ?? this.dragToReorder,
        mapShowBoth: mapShowBoth ?? this.mapShowBoth,
        mapLabel: mapLabel ?? this.mapLabel,
        mapChosenLocation: mapChosenLocation ?? this.mapChosenLocation,
        mapResetNorth: mapResetNorth ?? this.mapResetNorth,
        navLabel: navLabel ?? this.navLabel,
        navIn: navIn ?? this.navIn,
        navThen: navThen ?? this.navThen,
        navArrive: navArrive ?? this.navArrive,
        navRecenter: navRecenter ?? this.navRecenter,
        navEnd: navEnd ?? this.navEnd,
        navMinutes: navMinutes ?? this.navMinutes,
        navHours: navHours ?? this.navHours,
        navHoursMinutes: navHoursMinutes ?? this.navHoursMinutes,
        navMeters: navMeters ?? this.navMeters,
        navKilometers: navKilometers ?? this.navKilometers,
        navSummary: navSummary ?? this.navSummary,
        adding: adding ?? this.adding,
        today: today ?? this.today,
        notSet: notSet ?? this.notSet,
        chooseMonth: chooseMonth ?? this.chooseMonth,
        chooseYear: chooseYear ?? this.chooseYear,
        opensCalendar: opensCalendar ?? this.opensCalendar,
        opensTimePicker: opensTimePicker ?? this.opensTimePicker,
        hours: hours ?? this.hours,
        minutes: minutes ?? this.minutes,
        seconds: seconds ?? this.seconds,
        cut: cut ?? this.cut,
        copy: copy ?? this.copy,
        paste: paste ?? this.paste,
        delete: delete ?? this.delete,
        lookUp: lookUp ?? this.lookUp,
        searchWeb: searchWeb ?? this.searchWeb,
        share: share ?? this.share,
        scanText: scanText ?? this.scanText,
        fieldRequired: fieldRequired ?? this.fieldRequired,
        thisField: thisField ?? this.thisField,
        sheetSmaller: sheetSmaller ?? this.sheetSmaller,
        sheetLarger: sheetLarger ?? this.sheetLarger,
        navigationOpen: navigationOpen ?? this.navigationOpen,
        currentStep: currentStep ?? this.currentStep,
        upcoming: upcoming ?? this.upcoming,
        openImage: openImage ?? this.openImage,
        image: image ?? this.image,
        meter: meter ?? this.meter,
        chosenFiles: chosenFiles ?? this.chosenFiles,
        slider: slider ?? this.slider,
        locale: locale ?? this.locale,
        months: months ?? this.months,
        monthsShort: monthsShort ?? this.monthsShort,
        weekdays: weekdays ?? this.weekdays,
        weekdaysShort: weekdaysShort ?? this.weekdaysShort,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
        dateFormat: dateFormat ?? this.dateFormat,
        dateFormatShort: dateFormatShort ?? this.dateFormatShort,
        monthYearFormat: monthYearFormat ?? this.monthYearFormat,
      );

  /// Every word by key (the web `UiStrings` keys), for tests and tools.
  Map<String, String> toMap() => {
        'close': close,
        'dismiss': dismiss,
        'clear': clear,
        'clearAll': clearAll,
        'clearSearch': clearSearch,
        'previousPage': previousPage,
        'nextPage': nextPage,
        'previousMonth': previousMonth,
        'nextMonth': nextMonth,
        'chooseDate': chooseDate,
        'moreActions': moreActions,
        'uploadLabel': uploadLabel,
        'uploadHint': uploadHint,
        'holdHint': holdHint,
        'confirmTitle': confirmTitle,
        'confirm': confirm,
        'cancel': cancel,
        'zoomIn': zoomIn,
        'zoomOut': zoomOut,
        'placePinAtCentre': placePinAtCentre,
        'mapLocate': mapLocate,
        'mapLocationOff': mapLocationOff,
        'mapYourLocation': mapYourLocation,
        'mapOpen': mapOpen,
        'mapSearchArea': mapSearchArea,
        'mapRadiusMeters': mapRadiusMeters,
        'mapRadiusKilometers': mapRadiusKilometers,
        'googleSignIn': googleSignIn,
        'googleSignUp': googleSignUp,
        'googleContinue': googleContinue,
        'googleSignInShort': googleSignInShort,
        'sidebarToggle': sidebarToggle,
        'sidebarClose': sidebarClose,
        'sidebarLabel': sidebarLabel,
        'loading': loading,
        'previous': previous,
        'next': next,
        'previousSlide': previousSlide,
        'nextSlide': nextSlide,
        'goToSlide': goToSlide,
        'carousel': carousel,
        'imageViewer': imageViewer,
        'previousImage': previousImage,
        'nextImage': nextImage,
        'resetView': resetView,
        'fit': fit,
        'fitPage': fitPage,
        'fitToView': fitToView,
        'doubleTapToZoom': doubleTapToZoom,
        'play': play,
        'pause': pause,
        'seek': seek,
        'volume': volume,
        'playbackSpeed': playbackSpeed,
        'fullscreen': fullscreen,
        'video': video,
        'mediaSet': mediaSet,
        'path': path,
        'open': open,
        'previewUnavailable': previewUnavailable,
        'emptyFolder': emptyFolder,
        'loadingPdf': loadingPdf,
        'pageControls': pageControls,
        'page': page,
        'pageOf': pageOf,
        'pagination': pagination,
        'resizePanes': resizePanes,
        'resize': resize,
        'breadcrumb': breadcrumb,
        'showMore': showMore,
        'onThisPage': onThisPage,
        'otpLabel': otpLabel,
        'otpDigit': otpDigit,
        'remove': remove,
        'showPassword': showPassword,
        'hidePassword': hidePassword,
        'pickColor': pickColor,
        'hexColor': hexColor,
        'hue': hue,
        'commandPalette': commandPalette,
        'commandPlaceholder': commandPlaceholder,
        'noResults': noResults,
        'searchPlaceholder': searchPlaceholder,
        'selectPlaceholder': selectPlaceholder,
        'datePlaceholder': datePlaceholder,
        'chooseTime': chooseTime,
        'previousYear': previousYear,
        'nextYear': nextYear,
        'previousYears': previousYears,
        'nextYears': nextYears,
        'monthsOf': monthsOf,
        'yearsRange': yearsRange,
        'dateRange': dateRange,
        'emptyHeading': emptyHeading,
        'noData': noData,
        'empty': empty,
        'selectAll': selectAll,
        'selectAllRows': selectAllRows,
        'selectRow': selectRow,
        'actions': actions,
        'options': options,
        'tabs': tabs,
        'progress': progress,
        'rating': rating,
        'meterWarn': meterWarn,
        'meterDanger': meterDanger,
        'decrease': decrease,
        'increase': increase,
        'addTag': addTag,
        'menu': menu,
        'showMenu': showMenu,
        'move': move,
        'dragHint': dragHint,
        'rotate': rotate,
        'playhead': playhead,
        'dragToReorder': dragToReorder,
        'mapShowBoth': mapShowBoth,
        'mapLabel': mapLabel,
        'mapChosenLocation': mapChosenLocation,
        'mapResetNorth': mapResetNorth,
        'navLabel': navLabel,
        'navIn': navIn,
        'navThen': navThen,
        'navArrive': navArrive,
        'navRecenter': navRecenter,
        'navEnd': navEnd,
        'navMinutes': navMinutes,
        'navHours': navHours,
        'navHoursMinutes': navHoursMinutes,
        'navMeters': navMeters,
        'navKilometers': navKilometers,
        'navSummary': navSummary,
        'adding': adding,
        'today': today,
        'notSet': notSet,
        'chooseMonth': chooseMonth,
        'chooseYear': chooseYear,
        'opensCalendar': opensCalendar,
        'opensTimePicker': opensTimePicker,
        'hours': hours,
        'minutes': minutes,
        'seconds': seconds,
        'cut': cut,
        'copy': copy,
        'paste': paste,
        'delete': delete,
        'lookUp': lookUp,
        'searchWeb': searchWeb,
        'share': share,
        'scanText': scanText,
        'fieldRequired': fieldRequired,
        'thisField': thisField,
        'sheetSmaller': sheetSmaller,
        'sheetLarger': sheetLarger,
        'navigationOpen': navigationOpen,
        'currentStep': currentStep,
        'upcoming': upcoming,
        'openImage': openImage,
        'image': image,
        'meter': meter,
        'chosenFiles': chosenFiles,
        'slider': slider,
      };

  @override
  bool operator ==(Object other) =>
      other is UiStrings &&
      mapEquals(other.toMap(), toMap()) &&
      other.locale == locale &&
      listEquals(other.months, months) &&
      listEquals(other.monthsShort, monthsShort) &&
      listEquals(other.weekdays, weekdays) &&
      listEquals(other.weekdaysShort, weekdaysShort) &&
      other.firstDayOfWeek == firstDayOfWeek &&
      other.dateFormat == dateFormat &&
      other.dateFormatShort == dateFormatShort &&
      other.monthYearFormat == monthYearFormat;

  @override
  int get hashCode => Object.hash(Object.hashAll(toMap().values), locale, Object.hashAll(months), Object.hashAll(weekdaysShort), firstDayOfWeek, dateFormat);
}
