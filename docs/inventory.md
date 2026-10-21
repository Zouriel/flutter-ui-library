# @zouriel/ui → Flutter: inventory

Generated from the Angular source by `tool/angular_inventory.py` (re-run to refresh). Each class has a port checklist.

## accordion

### UiAccordionItem (component, `ui-accordion-item`)
File: `accordion/src/accordion.ts`  
`ui-accordion-item` — a titled, collapsible panel. Use inside `ui-accordion`.  
- Inputs: `title`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiAccordion (component, `ui-accordion`)
File: `accordion/src/accordion.ts`  
`ui-accordion` — groups `ui-accordion-item`s. Single-open unless `multiple`.  
- Inputs: `multiple` = false
- Methods: `toggle(item: UiAccordionItem)`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## alert

### UiAlert (component, `ui-alert`)
File: `alert/src/alert.ts`  
`ui-alert` — inline contextual message. Uses role="alert" for danger/warning.  
- Inputs: `tone`: UiAlertTone = 'info'; `heading`: string; `dismissible` = false; `radius`: boolean = this.config.radius
- Outputs: `dismiss`: void
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

- type `UiAlertTone` (alert.ts)

## badge

### UiAvatarGroup (component, `ui-avatar-group`)
File: `badge/src/avatar-group.ts`  
`ui-avatar-group` — overlapping stack of avatars. Project `ui-avatar` elements; they overlap by the `--ui-avatar-overlap` amount.  
- Inputs: `max`: number
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiAvatar (component, `ui-avatar`)
File: `badge/src/avatar.ts`  
`ui-avatar` — user/entity image with graceful initials fallback. Provide `src`+`alt`, or `name` to render initials. Initials also replace an image that fails to load.  
- Inputs: `src`: string; `alt`: string; `name`: string; `size`: UiSize = 'md'; `square` = false
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiBadge (component, `ui-badge`)
File: `badge/src/badge.ts`  
`ui-badge` — small status/count label.  
- Inputs: `tone`: UiStatus = 'neutral'; `dot` = false
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiChip (component, `ui-chip`)
File: `badge/src/chip.ts`  
`ui-chip` — compact, optionally-removable tag/token.  
- Inputs: `tone`: UiStatus = 'neutral'; `removable` = false; `label`: string; `radius`: boolean = this.config.radius
- Outputs: `remove`: void
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase


## behaviors

### UiCopyToClipboard (directive, `[uiCopyToClipboard]`)
File: `behaviors/src/copy-to-clipboard.ts`  
`uiCopyToClipboard` — copies the bound text to the clipboard on click and exposes a transient `copied` state. Emits `(copied)` / `(copyFailed)`.  
- Inputs: `uiCopyToClipboard`: string = ''
- Outputs: `copied`: string; `copyFailed`: unknown
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- const `SWIPE_FRACTION` (gestures.ts)
- const `SWIPE_MIN` (gestures.ts)
- const `SWIPE_MAX` (gestures.ts)
- const `FLICK_DISTANCE` (gestures.ts)
- const `FLICK_SPEED` (gestures.ts)
- const `RUBBER_BAND` (gestures.ts)
- function `isSwipe` (gestures.ts)
- function `resist` (gestures.ts)
### UiInfiniteScroll (directive, `[uiInfiniteScroll]`)
File: `behaviors/src/infinite-scroll.ts`  
`uiInfiniteScroll` — emits `(scrolledToEnd)` when the host scrolls within `threshold` px of the bottom. Re-arms once scrolled back up.  
- Inputs: `uiInfiniteScrollThreshold` = 120; `uiInfiniteScrollDisabled` = false
- Outputs: `scrolledToEnd`: void
- [x] Flutter port  - [x] widget tests  - [ ] golden/visual check (n/a: no visuals of its own)  - [x] showcase

### UiIntersect (directive, `[uiIntersect]`)
File: `behaviors/src/intersect.ts`  
`uiIntersect` — emits `(intersect)` with visibility as the host enters/leaves the viewport.  
- Inputs: `uiIntersectRootMargin` = '0px'; `uiIntersectOnce` = false
- Outputs: `uiIntersect`: boolean
- [x] Flutter port  - [x] widget tests  - [ ] golden/visual check (n/a: no visuals of its own)  - [x] showcase

### UiResizeObserver (directive, `[uiResizeObserver]`)
File: `behaviors/src/resize-observer.ts`  
`uiResizeObserver` — emits `(uiResizeObserver)` with the host's content-box size on change.  
- Outputs: `uiResizeObserver`: UiSize2D
- [x] Flutter port  - [x] widget tests  - [ ] golden/visual check (n/a: no visuals of its own)  - [x] showcase

- interface `UiSize2D` (resize-observer.ts)
### UiRipple (directive, `[uiRipple]`)
File: `behaviors/src/ripple.ts`  
`uiRipple` — emits a material-style ripple from the pointer position on press.  
- Inputs: `uiRippleDisabled` = false; `uiRippleColor` = 'currentColor'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSlideTransition (directive, `[uiSlideTransition]`) (0.34)
File: `behaviors/src/slide-transition.ts`  
`uiSlideTransition` — slides a routed or stacked view in from start or end (View Transitions API, with a short fallback); `uiSlideRouteTransition` for the router. Flutter twin: `UiPageRoute(transition: UiPageTransition.slideFromStart / slideFromEnd)`, the Flutter way to change views.  
- Inputs: `uiSlideTransition`: UiSlideFrom = 'end'; method `run(update, { from?, back? })`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSwipe (directive, `[uiSwipe]`)
File: `behaviors/src/swipe.ts`  
`uiSwipe` — reports a horizontal swipe across the host, and gets out of the way of everything else the finger might have meant. <h4>Why this listens to touch events and not pointer events</h4> <p>Pointer events are the modern, unified API and they are the wrong tool here. A browser does not promote a touch to a pointer event until it knows the touch is not a gesture, and a swipe IS a gesture — so the promotion never happens. Measured on Chromium, the same finger produces:</p> <pre> tap     pointerdown + touchstart ............ pointerup + touchend swipe   touchstart + touchmove x12 + touchend        (no pointer events at all) </pre> <p>Not a `pointercancel` to react to, not a truncated stream to salvage — nothing. Anything built on pointer events can answer a tap and can never answer a swipe. Touch events, by contrast, are delivered in full and uninterrupted throughout, which is exactly why every swipe library worth the name is built on them. So: touch events carry the finger, and pointer events are kept only for the mouse and the pen, which are never subject to that arbitration.</p> <p>Nothing here calls `preventDefault`, and the host is deliberately left with its normal `touch-action`: the page must still scroll down under exactly the same finger, and a strip that scrolls sideways inside it must keep doing that too — which rules out the usual `touch-action: pan-y`, since a descendant cannot take back a direction an ancestor gave away. The drag is instead measured as it happens, against the shared thresholds in {@link isSwipe}, and answered the moment it qualifies. That reads better anyway: the screen turns under the finger rather than after it.</p> <p>It declines far more often than it fires, and that is the point:</p> <ul> <li><b>A second finger</b> cancels the candidate outright. A pinch is not half a swipe.</li> <li><b>The screen's edges</b> belong to the browser — that is where back and forward live on both iOS and Android, and a page that answered there would fire alongside them.</li> <li><b>Anything scrollable sideways</b> under the finger keeps its own drag: a tab strip, a carousel, a wide table. Reaching the end of one is not permission to leave the page.</li> <li><b>Fields, sliders and editable text</b>, which are dragged for their own reasons.</li> <li><b>The mouse</b>, unless asked for. A mouse drag across a page is a text selection, and whoever has one also has the whole navigation on screen.</li> </ul> <p>Anything else can opt out by marking a subtree `data-no-swipe`.</p>  
- Inputs: `uiSwipeDisabled` = false; `uiSwipeMouse` = false
- Outputs: `uiSwipeLeft`: void; `uiSwipeRight`: void
- [x] Flutter port  - [x] widget tests  - [ ] golden/visual check (n/a: no visuals of its own)  - [x] showcase

### UiVirtualList (component, `ui-virtual-list`)
File: `behaviors/src/virtual-list.ts`  
`ui-virtual-list` — renders only the visible slice of a large list via the CDK virtual scroll. Provide an item template: <ui-virtual-list [items]="rows" [itemSize]="32" height="320px"> <ng-template let-item>{{ item.name }}</ng-template> </ui-virtual-list>  
- Inputs: `items`: T[] = []; `itemSize` = 32; `height` = '320px'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## button

### UiButtonGroup (component, `ui-button-group`)
File: `button/src/button-group.ts`  
`ui-button-group` — visually joins a row of `ui-button`s into a segmented control.  
- Inputs: `label`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiButton (component, `ui-button`)
File: `button/src/button.ts`  
`ui-button` — the action primitive. Wires `glass`/`radius` to the global UiConfig defaults (overridable per instance) and uses only design tokens.  
- Inputs: `variant`: UiButtonVariant = 'primary'; `size`: UiSize = 'md'; `type`: 'button' | 'submit' | 'reset' = 'button'; `disabled` = false; `loading` = false; `block` = false; `glass` = false; `radius`: boolean = this.config.radius
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

- type `UiButtonVariant` (button.ts)
### UiDropdownButton (component, `ui-dropdown-button`)
File: `button/src/dropdown-button.ts`  
`ui-dropdown-button` — a button that opens a menu of actions (CDK Overlay).  
- Inputs: `items`: UiDropdownItem[] = []; `variant`: UiButtonVariant = 'secondary'; `size`: UiSize = 'md'; `disabled` = false; `radius`: boolean = this.config.radius
- Outputs: `select`: UiDropdownItem
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiDropdownItem` (dropdown-button.ts)
### UiFab (component, `ui-fab`)
File: `button/src/fab.ts`  
`ui-fab` — floating action button, fixed to a screen corner. `label` is required (a11y).  
- Inputs: `label`: string; `position`: 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left' = 'bottom-right'; `size`: 'sm' | 'md' = 'md'; `disabled` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiIconButton (component, `ui-icon-button`)
File: `button/src/icon-button.ts`  
`ui-icon-button` — square, icon-only action. `label` is REQUIRED and applied as `aria-label` so the control is named for assistive tech (WCAG).  
- Inputs: `label`: string; `variant`: UiButtonVariant = 'ghost'; `size`: UiSize = 'md'; `type`: 'button' | 'submit' | 'reset' = 'button'; `disabled` = false; `round` = false; `glass` = false; `radius`: boolean = this.config.radius
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiSegmented (component, `ui-segmented`)
File: `button/src/segmented.ts`  
`ui-segmented` — a row of mutually exclusive options, e.g. alignment or a preview mode. A radio group underneath: arrow keys move the choice, only the chosen option is in the tab order. Use `[(value)]` or ngModel.  
- Inputs: `options`: readonly UiSegmentedOption[] = []; `label` = 'Options'; `size`: UiSize = 'md'
- Two-way: `value`: string | null = null
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiSegmentedOption` (segmented.ts)
### UiSplitButton (component, `ui-split-button`)
File: `button/src/split-button.ts`  
`ui-split-button` — a primary action plus a caret that emits `(menu)` for an attached dropdown. Project the main label as content.  
- Inputs: `variant`: UiButtonVariant = 'primary'; `size`: UiSize = 'md'; `disabled` = false; `radius`: boolean = this.config.radius
- Outputs: `action`: void; `menu`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiToggleButton (component, `ui-toggle-button`)
File: `button/src/toggle-button.ts`  
`ui-toggle-button` — two-state button (`aria-pressed`). Bind `[(pressed)]`.  
- Inputs: `size`: UiSize = 'md'; `disabled` = false; `radius`: boolean = this.config.radius
- Two-way: `pressed` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## canvas

- type `UiBrushKind` (ink.ts)
- interface `UiBrush` (ink.ts)
- interface `UiInkSample` (ink.ts)
- function `brushSteadiness` (ink.ts)
- function `brushUsesPressure` (ink.ts)
- function `simulatedPressure` (ink.ts)
- function `inkRadii` (ink.ts)
- function `inkRadiusAt` (ink.ts)
- function `inkPiece` (ink.ts)
- function `convexHull` (ink.ts)
- function `inkArea` (ink.ts)
- function `inkD` (ink.ts)
- function `pieceD` (ink.ts)
- function `thinSamples` (ink.ts)
- type `UiInkShape` (ink.ts)
- function `recognizeShape` (ink.ts)
- function `shapeSamples` (ink.ts)
### UiPathEditor (component, `ui-path-editor`)
File: `canvas/src/path-editor.ts`  
`ui-path-editor` — a vector editing surface. It draws `items` (outlines made of points with optional curve handles, see `path.ts`) over an artboard and lets them be edited with a mouse, a finger or a pen. Four modes: - **objects**: tap an item to select it, drag to move it, the corner knobs scale it and the top knob rotates it. - **points** (Photoshop's Direct Selection): the selected item's points and handles show. Drag a point or a handle; tap an edge to add a point; double-tap a point to switch it between corner and curve; Shift-click or long-press to select several and move them together; drag across empty space with a mouse or pen to select a box of them. Alt-drag a handle to bend one side only (or set `freeHandles`), Alt-drag a corner to pull curve handles out of it, and hold Shift to keep to 45°. - **pen** (Photoshop's Pen): tap to place corners, drag to place a curve, tap the first point to close the shape, tap the last point (or press Enter) to finish an open line. Starting on a loose end of the selected item carries that line on. - **draw**: paint with `brush`. Pens report pressure; a finger or mouse gets it from speed. Once a pen has been used, fingers move the view instead of drawing (palm rejection, as `fingerDraws` 'auto'). Hold still at the end of a stroke to snap it to a line, circle, ellipse, rectangle or triangle. Each finished stroke is reported through `stroke`: the host decides what it becomes. The view zooms with a two-finger pinch or the wheel, and pans by dragging empty space (or with two fingers). It never mutates `items`: a finished gesture is reported once through `itemsChange`, so the host owns undo. While a gesture runs, a draft is drawn instead.  
- Inputs: `items`: UiPathItem[]; `width` = 100; `height` = 100; `mode`: UiPathEditorMode = 'objects'; `showArtboard` = true; `lockAspect` = false; `label` = 'Shape editor'; `brush`: UiBrush; `fill`: string | null = null; `fingerDraws`: boolean | 'auto' = 'auto'; `snapToShape` = true; `freeHandles` = false
- Two-way: `selectedId`: string | null = null; `selectedPoint`: UiPointRef | null = null; `selectedPoints`: UiPointRef[] = []
- Outputs: `itemsChange`: UiPathItem[]; `pointTap`: UiPointRef; `stroke`: UiInkStroke; `penDetected`: void
- Methods: `fit()`, `zoomBy(factor: number)`, `selectAllPoints()`, `finishPen(closed: boolean)`, `undoPenPoint()`, `cancelPen()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiPathEditorMode` (path-editor.ts)
- interface `UiInkStroke` (path-editor.ts)
- interface `UiPathXY` (path.ts)
- interface `UiPathPoint` (path.ts)
- interface `UiPathContour` (path.ts)
- interface `UiPathItem` (path.ts)
- type `UiPathOp` (path.ts)
- function `itemOp` (path.ts)
- interface `UiPathBounds` (path.ts)
- interface `UiPointRef` (path.ts)
- function `pathD` (path.ts)
- function `segmentPathD` (path.ts)
- function `segmentCount` (path.ts)
- function `pointOnSegment` (path.ts)
- function `flattenContour` (path.ts)
- function `pathBounds` (path.ts)
- function `mapContours` (path.ts)
- function `translateContours` (path.ts)
- function `scaleContours` (path.ts)
- function `rotateContours` (path.ts)
- function `nearestOnPath` (path.ts)
- function `insertPoint` (path.ts)
- function `deletePoint` (path.ts)
- function `breakAt` (path.ts)
- function `toggleClosed` (path.ts)
- function `joinEnds` (path.ts)
- function `toggleSmooth` (path.ts)
- function `movePoint` (path.ts)
- function `movePoints` (path.ts)
- function `deletePoints` (path.ts)
- function `allPoints` (path.ts)
- function `pullHandles` (path.ts)
- function `reverseContour` (path.ts)
- function `contourArea` (path.ts)
- function `insideContour` (path.ts)
- function `orientContours` (path.ts)
- function `moveHandle` (path.ts)
- function `rectContour` (path.ts)
- function `ellipseContour` (path.ts)
- function `polygonContour` (path.ts)
- function `starContour` (path.ts)
- function `archContour` (path.ts)
### UiSnapGuides (component, `ui-snap-guides`)
File: `canvas/src/snap.ts`  
`ui-snap-guides` — draws guide lines from {@link uiSnap} over a positioned stage.  
- Inputs: `guides`: readonly UiGuide[] = []; `scale` = 1
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiRect` (snap.ts)
- interface `UiGuide` (snap.ts)
- interface `UiSnapResult` (snap.ts)
- function `uiSnap` (snap.ts)
- function `uiRotatedBounds` (snap.ts)
### UiTransformBox (component, `ui-transform-box`)
File: `canvas/src/transform-box.ts`  
`ui-transform-box` — selection handles for an element on a design stage: drag the body to move, a handle to resize, the top knob to rotate. Place it inside a positioned stage; it lays itself out from `box` (stage units) times `scale` (screen px per unit). The component never mutates `box`. It reports `transform` on every pointer move and `transformEnd` once on release, so the host decides what a change means (live preview vs an undo step). Resizing respects rotation: the opposite edge stays put on screen. Modifiers: Shift keeps proportions while resizing and snaps rotation to 15°; Alt resizes from the centre. Arrow keys nudge by one unit, Shift+arrow by ten; Alt+arrow resizes (width with ←/→, height with ↑/↓); `[` / `]` rotate by 1° (15° with Shift) — the keyboard's way to every drag. Two fingers pinch: the box grows or shrinks toward the point between the fingers — that point stays under them, like zooming a photo — proportions kept, and moves with them. Fingers either side of the middle grow it equally from every side. A second finger landing anywhere while one drags the box turns the drag into a pinch; a host that sees two fingers land elsewhere (both beside a small element) can start one with `startPinch`. It reports as a resize: `transformStart('resize')`, `transform`, `transformEnd`.  
- Inputs: `box`: UiBox; `scale` = 1; `pointerScale`: number | null = null; `resizable` = true; `rotatable` = true; `lockAspect` = false; `minSize` = 4; `disabled` = false; `label` = ''; `showSize` = false; `cornersOnly` = false
- Outputs: `transformStart`: UiTransformMode; `transform`: UiBox; `transformEnd`: UiBox; `activate`: void; `tap`: UiTransformTap
- Methods: `startPinch(a: { pointerId: number; clientX: number; clientY: )`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiBox` (transform-box.ts)
- type `UiTransformMode` (transform-box.ts)
- interface `UiTransformTap` (transform-box.ts)

## card

### UiCard (component, `ui-card`)
File: `card/src/card.ts`  
`ui-card` — surface container with optional header/footer slots. Project header content with `[card-header]` and footer with `[card-footer]`.  
- Inputs: `padding`: 'sm' | 'md' | 'lg' = 'md'; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius; `interactive` = false
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiStatCard (component, `ui-stat-card`)
File: `card/src/stat-card.ts`  
`ui-stat-card` — KPI tile: label, value, optional delta + icon slot.  
- Inputs: `label` = ''; `value`: string | number = ''; `delta`: string | number; `trend`: 'up' | 'down' = 'up'; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiFeatureCard (component, `ui-feature-card`) (0.37)
File: `card/src/feature-card.ts`  
Product or service card for a landing page: icon in a tinted badge, eyebrow, title, description and an action; the whole card is one target.  
- Inputs: `title`; `description`; `eyebrow`; `actionLabel`; `href` (web only); `tone` (primary | accent | brand | neutral); `layout` (vertical | horizontal); `size` (sm | md | lg; sm since 0.38); `surface` (default | tinted, Flutter `UiFeatureSurface.standard | tinted`, 0.38); `trailingArrow` (0.38); `descriptionLines` (0.38); `badgeTone` (0.39); `colors` (UiFeatureCardColors, 0.39); `enter` / `enterDelay` (Flutter `Duration`, 0.39); `disabled` (Flutter `enabled: false`); `glass`; `radius` (boolean | 'control', Flutter `radius` + `controlRadius`, 0.38); `[icon]` slot (Flutter `icon`)
- Outputs: `action` (Flutter `onPressed`)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## combobox

### UiCombobox (component, `ui-combobox`)
File: `combobox/src/combobox.ts`  
`ui-combobox` — filterable autocomplete (CVA). Type to filter; Arrow keys + Enter to choose; Escape to close. Backed by the CDK Overlay (WAI-ARIA combobox). With `clearable` (the default) a chosen value can be removed: the Clear button next to the chevron, or emptying the text and leaving the field, sets the value to null.  
- Inputs: `options`: UiComboboxOption[] = []; `placeholder` = 'Search…'; `label`: string; `size`: UiSize = 'md'; `invalid` = false; `radius`: boolean = this.config.radius; `clearable` = true
- Methods: `clear()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiComboboxOption` (combobox.ts)
### UiMultiSelect (component, `ui-multi-select`)
File: `combobox/src/multi-select.ts`  
`ui-multi-select` — choose several options; selections shown as chips (CVA; value is string[]). Type to filter; Arrow keys + Enter toggle the active option; Backspace in an empty field removes the last chip; Escape closes. With `clearable` (the default) a Clear all button at the end of the field empties the selection.  
- Inputs: `options`: UiComboboxOption[] = []; `placeholder` = 'Select…'; `label`: string; `invalid` = false; `radius`: boolean = this.config.radius; `size`: UiSize = 'md'; `clearable` = true
- Methods: `clear(e?: Event)`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## command-palette

### UiCommandPalette (component, `ui-command-palette`)
File: `command-palette/src/command-palette.ts`  
`ui-command-palette` — ⌘K-style command launcher. Bind `[(open)]`, pass `commands`, listen to `(run)`. Typing filters by case-insensitive substring over label, group and keywords; ArrowUp/Down move the highlight, Enter runs it, Escape or a backdrop click closes. Focus is trapped while open and returns to where it was on close. While open it sits on its own layer at the end of `<body>` (so a transformed or clipped ancestor can't trap it) and page scroll is blocked with the CDK's block scroll strategy (needs `@angular/cdk/overlay-prebuilt.css`, like the other overlays). It binds no global shortcut: open it from your own keydown handler.  
- Inputs: `commands`: UiCommand[] = []; `placeholder` = 'Type a command or search…'; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- Two-way: `open` = false
- Outputs: `run`: UiCommand
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiCommand` (command-palette.ts)

## data

### UiCodeBlock (component, `ui-code-block`)
File: `data/src/code-block.ts`  
`ui-code-block` — monospace code panel with language label and copy button.  
- Inputs: `code` = ''; `language` = 'text'; `radius` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiDescriptionList (component, `ui-description-list`)
File: `data/src/description-list.ts`  
`ui-description-list` — key/value pairs (a semantic `<dl>`).  
- Inputs: `items`: UiDescriptionItem[] = []; `layout`: 'stacked' | 'row' = 'row'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiDescriptionItem` (description-list.ts)
### UiTimeline (component, `ui-timeline`)
File: `data/src/timeline.ts`  
`ui-timeline` — vertical sequence of events with connector line.  
- Inputs: `items`: UiTimelineItem[] = []
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiTimelineItem` (timeline.ts)
### UiTreeTable (component, `ui-tree-table`)
File: `data/src/tree-table.ts`  
`ui-tree-table` — hierarchical table; the first column is an expandable tree.  
- Inputs: `rows`: UiTreeTableRow[] = []; `columns`: UiTreeTableColumn[] = []; `firstHeader` = 'Name'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiTreeTableColumn` (tree-table.ts)
- interface `UiTreeTableRow` (tree-table.ts)
### UiTree (component, `ui-tree`)
File: `data/src/tree.ts`  
`ui-tree` — expandable hierarchy with single selection, following the WAI-ARIA tree view pattern: one tab stop (roving tabindex), arrow-key navigation, nested `role="group"` containers and type-ahead by first letter.  
- Inputs: `nodes`: UiTreeNode[] = []; `label` = ''
- Two-way: `selected`: string | null = null
- Outputs: `nodeSelect`: UiTreeNode
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiTreeNode` (tree.ts)

## datepicker

### UiCalendar (component, `ui-calendar`)
File: `datepicker/src/calendar.ts`  
`ui-calendar` — inline month calendar (CVA; value is an ISO `YYYY-MM-DD` string).  
- Inputs: `min`: string | null = null; `max`: string | null = null
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- const `MONTHS` (date-names.ts)
- const `MONTHS_SHORT` (date-names.ts)
- const `WEEKDAYS` (date-names.ts)
- function `monthYear` (date-names.ts)
- function `formatIsoDate` (date-names.ts)
### UiDatePicker (component, `ui-date-picker`)
File: `datepicker/src/date-picker.ts`  
`ui-date-picker` — calendar popover (CVA; value is an ISO `YYYY-MM-DD` string). Backed by the CDK Overlay; closes on outside click / Escape. Keyboard: Enter, Space or ArrowDown on the field opens it with focus on the chosen day (or today). Arrow keys move by day and week (crossing months), PageUp/PageDown by month, Home/End to the month's ends; Enter picks. The month and year grids (opened from the heading) work the same way: one tab stop, Arrow keys move (Up/Down by a row of three), Home/End to the first/last cell, PageUp/PageDown by a year (month grid) or a page of 12 years (year grid), Enter or Space picks; opening a grid focuses the month or year in view. Tab stays inside the popover; Escape closes it and returns to the field.  
- Inputs: `placeholder` = 'Select a date'; `size`: UiSize = 'md'; `radius`: boolean = this.config.radius; `min`: string | null = null; `max`: string | null = null
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiDateRangePicker (component, `ui-date-range-picker`)
File: `datepicker/src/date-range-picker.ts`  
`ui-date-range-picker` — inline range selection (CVA; value is `{ start, end }` ISO strings).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiDateRange` (date-range-picker.ts)

## dialog

### UiBottomSheet (component, `ui-bottom-sheet`)
File: `dialog/src/bottom-sheet.ts`  
`ui-bottom-sheet` — a panel anchored to the bottom of the screen that the user drags between resting heights, the mobile answer to a sidebar. <p>Heights are `snaps`: fractions of the room it has (the viewport, less `offset` below it for a toolbar and `topInset` above it for a header). `snap` is the index it rests at, two-way; a first snap of 0 is closed. Drag the header anywhere, or flick it — a fast release moves one snap in that direction. Dragging the body moves the sheet too when that's the only sensible reading: pulling down with the content already at its top, or pushing up while there's a taller snap to reach. Otherwise the content scrolls as usual. Anything marked `data-sheet-nodrag` keeps its drags.</p> <h4>Touch events for the finger</h4> <p>A drag that the browser could read as a scroll never becomes a pointer event, so the finger is followed with touch events, which arrive complete. Pointer events serve the mouse and pen only, and are ignored once a touch has been seen so one finger isn't read as two drags.</p> <p>It's non-modal by default: what's above stays usable, which is the point on an editor, so opening it does not move focus and Tab can leave it. Set `backdrop` to make it modal while open: the page dims and a backdrop tap closes it, it is marked `aria-modal`, focus moves into it (to an element marked `cdkFocusInitial`, else the first focusable one, the handle), and Tab is trapped inside (CDK `FocusTrap`). Escape closes it while focus is inside; closing either way sends focus back to where it came from. The handle is a button that steps through the snaps, and ↑/↓ on it do the same. When a field inside gains focus on a touch screen, the sheet rises to its tallest snap (turn that off with `expandOnFocus`), and while an on-screen keyboard is up the sheet rests on top of it rather than behind it.</p> <p>Positioned `fixed`; keep it out of transformed ancestors.</p>  
- Inputs: `snaps`: readonly number[] = [0; `title` = ''; `offset` = 0; `topInset` = 0; `backdrop` = false; `closable` = true; `hasHeader` = false; `expandOnFocus` = true; `glass` = false (0.41.2, see-through over a map; Flutter `glass`); `glassStrength`: 'clear' | 'frosted' = 'clear' (0.41.3; Flutter `UiGlassStrength`)
- Two-way: `snap` = 0
- Outputs: `heightChange`: number; `coverChange`: number
- Methods: `close()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiConfirmDialog (component, `ui-confirm-dialog`)
File: `dialog/src/confirm-dialog.ts`  
`ui-confirm-dialog` — a focused confirm/cancel prompt built on `ui-modal`. Bind `[(open)]` and listen to `(confirm)` / `(cancel)`.  
- Inputs: `title` = 'Are you sure?'; `message` = ''; `confirmLabel` = 'Confirm'; `cancelLabel` = 'Cancel'; `destructive` = false
- Two-way: `open` = false
- Outputs: `confirm`: void; `cancel`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiDrawer (component, `ui-drawer`)
File: `dialog/src/drawer.ts`  
`ui-drawer` — edge-anchored sheet. Slides in from `side`, traps focus, locks scroll, and dismisses on Escape / backdrop click.  
- Inputs: `side`: UiDrawerSide = 'right'; `title`: string; `closeOnBackdrop` = true; `closeOnEscape` = true; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- Two-way: `open` = false
- Slots (0.41): default (the only part that scrolls), `[drawer-header]`, `[drawer-footer]` (Flutter `header` / `footer`, `showUiDrawer(headerBuilder:, footerBuilder:)`; Flutter-only `bodyBuilder(context, ScrollController)` for a paging list)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiDrawerSide` (drawer.ts)
### UiModal (component, `ui-modal`)
File: `dialog/src/modal.ts`  
`ui-modal` — centered dialog with backdrop. Traps focus (CDK a11y), locks body scroll while open, closes on Escape / backdrop click, and animates with the shared scale + backdrop-fade animations.  
- Inputs: `title`: string; `size`: 'sm' | 'md' | 'lg' | 'full' = 'md'; `closeOnBackdrop` = true; `closeOnEscape` = true; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- Two-way: `open` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- function `lockBodyScroll` (overlay-layer.ts)
- function `unlockBodyScroll` (overlay-layer.ts)
- function `detachLayer` (overlay-layer.ts)
### UiToastService (injectable)
File: `dialog/src/toast.ts`  
`UiToastService` — enqueue transient notifications. Render once with `<ui-toast-host />` near the app root.  
- Methods: `show(opts: UiToastOptions)`, `pause(id: number)`, `resume(id: number)`, `act(id: number)`, `dismiss(id: number)`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiToastHost (component, `ui-toast-host`)
File: `dialog/src/toast.ts`  
`ui-toast-host` — fixed renderer for queued toasts, in a corner or centred on the top or bottom edge. Toasts slide in from the edge they sit against and slide back out that way.  
- Inputs: `position`: UiToastPosition = 'bottom-right'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiToastTone` (toast.ts)
- type `UiToastPosition` (toast.ts)
- interface `UiToastOptions` (toast.ts)
- interface `UiToastAction` (toast.ts)
- interface `UiToast` (toast.ts)

### UiSnackbar (component, `ui-snackbar`)
File: `dialog/src/snackbar.ts`  
`ui-snackbar` — the notice itself: a compact inverted bar with a message and an optional link-style action ("Deleted “Name” · Undo"). Flutter: `UiSnackbar`.  
- Inputs: `message`: string (required); `title`: string; `actionLabel`: string
- Outputs: `action`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSnackbarService (injectable)
File: `dialog/src/snackbar.ts`  
`UiSnackbarService` — one short notice at a time; a new one replaces the current one. Flutter: `UiSnackbarController`.  
- Methods: `show(opts | message)`, `dismiss(id?)`, `act()`, `pause()`, `resume()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSnackbarHost (component, `ui-snackbar-host`)
File: `dialog/src/snackbar.ts`  
`ui-snackbar-host` — renders the service's notice centred at the bottom of the screen.  
- Inputs: `offset` = 0
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiSnackbarOptions` (snackbar.ts)
- interface `UiSnackbarAction` (snackbar.ts)
- interface `UiSnack` (snackbar.ts)

## divider

### UiDivider (component, `ui-divider`)
File: `divider/src/divider.ts`  
`ui-divider` — horizontal or vertical separator, optionally with a label.  
- Inputs: `orientation`: 'horizontal' | 'vertical' = 'horizontal'; `label`: string
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase


## feedback

### UiEmptyState (component, `ui-empty-state`)
File: `feedback/src/empty-state.ts`  
`ui-empty-state` — placeholder for empty content. Slots: `[empty-icon]`, `[empty-actions]`.  
- Inputs: `heading` = 'Nothing here yet'; `description`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiLoadingOverlay (component, `ui-loading-overlay`)
File: `feedback/src/loading-overlay.ts`  
`ui-loading-overlay` — covers its positioned parent with a dimmed, blurred veil + spinner while `loading` is true. Place inside a `position: relative` container.  
- Inputs: `loading` = false; `label` = 'Loading…'
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiResult (component, `ui-result`)
File: `feedback/src/result.ts`  
`ui-result` — full-page outcome state (success / error / 404 / 500).  
- Inputs: `status`: UiResultStatus = 'info'; `title` = ''; `subtitle`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiResultStatus` (result.ts)

## file-viewer

### UiAudioPlayer (component, `ui-audio-player`)
File: `file-viewer/src/audio-player.ts`  
`ui-audio-player` — themed audio controls (play, scrub, time, volume).  
- Inputs: `src`: string; `title`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiCodeViewer (component, `ui-code-viewer`)
File: `file-viewer/src/code-viewer.ts`  
`ui-code-viewer` — monospace source view with line numbers (content or fetched src).  
- Inputs: `src`: string; `content`: string; `language` = 'text'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiFileExplorer (component, `ui-file-explorer`)
File: `file-viewer/src/file-explorer.ts`  
`ui-file-explorer` — directory browser: breadcrumb path + list view, typed icons, open-into-viewer.  
- Inputs: `root`: UiFileNode
- Outputs: `open`: UiFileNode
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiFileNode` (file-explorer.ts)
### UiFileViewer (component, `ui-file-viewer`)
File: `file-viewer/src/file-viewer.ts`  
`ui-file-viewer` — detects a file's type from `kind`/extension and delegates to the matching sub-renderer. The PDF branch lazy-loads `pdfjs-dist` via `@defer` so it never ships unless a PDF is opened. Unsupported types fall back to metadata + a download link. Embed inline or inside `ui-window`.  
- Inputs: `src`: string; `name`: string; `kind`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- function `clampOffset` (gestures.ts)
- function `fitContain` (gestures.ts; Flutter `uiFitContain`)
### UiImageViewer (component, `ui-image-viewer`)
File: `file-viewer/src/image-viewer.ts`  
`ui-image-viewer` — zoom (buttons, wheel, pinch), pan (drag, wheel), fit/reset, and — when the host says there is somewhere to go — swipe between images. <p>Gestures are handled here rather than left to the browser, which is why the stage sets `touch-action: none`: a two-finger pinch that the browser claims first never reaches us, and the page would zoom instead of the image. Owning the gesture is what makes pinch work at all.</p> <p>It follows that navigation has to live here too. A gallery cannot listen for its own swipes over a stage that has already captured the pointer, so the viewer detects the gesture and the host moves: {@link hasPrevious}/{@link hasNext} say what exists, {@link previous}/{@link next} report the intent, and the list itself stays where it belongs — with whoever owns it.</p>  
- Inputs: `src`: string; `alt` = ''; `kind`: 'image' | 'video' = 'image'; `hasPrevious` = false; `hasNext` = false; `fill` = false (0.41.1)
- Outputs: `previous`: void; `next`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiMediaLightbox (component, `ui-media-lightbox`)
File: `file-viewer/src/media-lightbox.ts`  
`ui-media-lightbox` — photographs and clips at full screen, the way a phone's own gallery shows them: edge to edge, over everything, with the chrome floating on top and getting out of the way. <p>It is a native `<dialog>` opened with `showModal`, which buys three things that are otherwise fragile at this size: the top layer, so no ancestor's `overflow`, `transform` or z-index can clip or bury it — a lightbox nested inside a card or a tab panel is exactly where a `position: fixed` overlay goes wrong; a focus trap; and Escape, for free.</p> <p>The host owns the list and the position in it. {@link items} is what there is, {@link index} is where you are, and both a swipe and the arrows just move that number — so a photo deleted from under the lightbox, or a list that grows while it is open, needs nothing from here.</p> <p>Gestures are ours rather than the browser's (`touch-action: none` on the stage), because a pinch the browser claims first would zoom the page instead of the picture. Which is also why the clip uses our controls rather than the platform's: the native scrubber lives inside a shadow root whose drags are indistinguishable from a swipe across the picture, and scrubbing would jump to the next video.</p>  
- Inputs: `items`: readonly UiMediaItem[] = []; `label` = ''; `actions`: readonly UiMediaAction[] = []
- Two-way: `index` = 0; `open` = false
- Outputs: `closed`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiMediaItem` (media-lightbox.ts)
- interface `UiMediaAction` (media-lightbox.ts)
### UiTextViewer (component, `ui-text-viewer`)
File: `file-viewer/src/text-viewer.ts`  
`ui-text-viewer` — displays plain text from a `content` string or a fetched `src` URL.  
- Inputs: `src`: string; `content`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiVideoPlayer (component, `ui-video-player`)
File: `file-viewer/src/video-player.ts`  
`ui-video-player` — native `<video>` with themed controls (play, scrub, time, volume, speed, fullscreen).  
- Inputs: `src`: string; `poster`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## form

### UiAnchorPicker (component, `ui-anchor-picker`)
File: `form/src/anchor-picker.ts`  
`ui-anchor-picker` — the nine-dot grid for choosing a point of a box (a pivot, an alignment), as in Figma and Photoshop. The value is `{x, y}` in fractions of the box (0, 0.5, 1); a value between the dots shows no dot chosen. Arrow keys move the choice; each dot is named for screen readers.  
- Inputs: `label` = 'Point'
- Two-way: `value`: UiAnchor | null
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiAnchor` (anchor-picker.ts)
### UiCheckboxGroup (component, `ui-checkbox-group`)
File: `form/src/checkbox-group.ts`  
`ui-checkbox-group` — multi-select checkbox set (CVA; value is string[]). Set `selectAll` to prepend a master checkbox that ticks or clears every enabled option. It shows an indeterminate state while the selection is partial, and never touches disabled options — the consumer's disabled rules stay authoritative.  
- Inputs: `options`: UiCheckboxOption[] = []; `label`: string; `orientation`: 'vertical' | 'horizontal' = 'vertical'; `selectAll` = false; `selectAllLabel` = 'Select all'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiCheckboxOption` (checkbox-group.ts)
### UiCheckbox (component, `ui-checkbox`)
File: `form/src/checkbox.ts`  
`ui-checkbox` — boolean control (CVA) built on a native checkbox for a11y.  
- Inputs: `invalid` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiChipInput (component, `ui-chip-input`)
File: `form/src/chip-input.ts`  
`ui-chip-input` — tokenized text entry (CVA; value is string[]). Enter adds, Backspace removes.  
- Inputs: `placeholder` = 'Add tag…'; `label`: string; `invalid` = false; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiChoiceGrid (component, `ui-choice-grid`)
File: `form/src/choice-grid.ts`  
`ui-choice-grid` — pick one of many options shown as tiles: presets, templates, effects. A radio group underneath (CVA or `[(value)]`): arrow keys move through the tiles in reading order, only the chosen one is in the tab order, and Enter/Space choose. Each tile shows its label (and description); project `<ng-template #tile let-item let-selected="selected">` to draw a picture above it. `(picked)` fires on every choice, including choosing the selected tile again — for pickers where a choice is an action (add this) rather than a setting.  
- Inputs: `options`: readonly UiChoice[] = []; `label` = 'Choices'; `minTile` = '88px'
- Two-way: `value`: string | null = null
- Outputs: `picked`: UiChoice
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiChoice` (choice-grid.ts)
- interface `UiChoiceTileContext` (choice-grid.ts)
### UiColorPicker (component, `ui-color-picker`)
File: `form/src/color-picker.ts`  
`ui-color-picker` — native color well + hex field + preset swatches (CVA; value is hex).  
- Inputs: `radius`: boolean = this.config.radius; `swatches`: string[] = ['#1b3d59'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiEditableText (component, `ui-editable-text`)
File: `form/src/editable-text.ts`  
`ui-editable-text` — click-to-edit inline text (CVA). Enter commits, Escape cancels.  
- Inputs: `placeholder` = 'Empty'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiFileUpload (component, `ui-file-upload`)
File: `form/src/file-upload.ts`  
`ui-file-upload` — drag-and-drop / click dropzone. Emits `(filesSelected)`. Dropped files are checked against `accept` the same way the file dialog filters them; files that don't match go to `(rejected)`.  
- Inputs: `multiple` = false; `accept`: string; `acceptLabel`: string; `radius` = true; `disabled` = false
- Outputs: `filesSelected`: File[]; `rejected`: File[]
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- function `fileMatchesAccept` (file-upload.ts)
### UiFormField (component, `ui-form-field`)
File: `form/src/form-field.ts`  
`ui-form-field` — label + hint + error wrapper for any control. The projected control is wrapped by a `<label>`, and the label's `for` is pointed at the control's own text field (given an id if it has none). Without that, a wrapping label names its first labelable element, which in `ui-chip-input` or `ui-multi-select` is the first chip's remove button. A custom control can pick its labelable element (input, select, textarea, button) with a `data-ui-field-control` attribute.  
- Inputs: `label`: string; `hint`: string; `error`: string; `required` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiInput (component, `ui-input`)
File: `form/src/input.ts`  
`ui-input` — single-line text field. Implements ControlValueAccessor so it works with template-driven, reactive, and Signal Forms.  
- Inputs: `type`: 'text' | 'email' | 'url' | 'tel' | 'password' | 'search' = 'text'; `placeholder` = ''; `inputmode`: string; `autocomplete`: string; `name`: string; `size`: UiSize = 'md'; `invalid` = false; `radius`: boolean = this.config.radius; `dir`: UiTextDir | null = null (0.33)
- Slots: `[input-leading]`, `[input-trailing]` (0.33; Flutter `leading` / `trailing`, plus `dir` and `textStyle`)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiNumberLabel (directive, `[uiNumberLabel]`)
File: `form/src/number-input.ts`  
An icon to show in place of a `ui-number-input`'s text label: `<svg uiNumberLabel …/>` inside the input. It works like the label (drag it to scrub); keep `label` or `ariaLabel` set for screen readers.  
- Inputs: `min`: number; `max`: number; `step` = 1; `placeholder` = ''; `size`: UiSize = 'md'; `invalid` = false; `radius`: boolean = this.config.radius; `label` = ''; `ariaLabel` = ''; `suffix` = ''; `precision`: number | null = null; `steppers` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase  (as UiNumberInput.labelIcon)

### UiNumberInput (component, `ui-number-input`)
File: `form/src/number-input.ts`  
`ui-number-input` — numeric field with stepper buttons (CVA).  
- Inputs: `min`: number; `max`: number; `step` = 1; `placeholder` = ''; `size`: UiSize = 'md'; `invalid` = false; `radius`: boolean = this.config.radius; `label` = ''; `ariaLabel` = ''; `suffix` = ''; `precision`: number | null = null; `steppers` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiOtpInput (component, `ui-otp-input`)
File: `form/src/otp-input.ts`  
`ui-otp-input` — fixed-length one-time-code entry (CVA; value is a string). The value keeps every character in its cell's position: an empty cell before a filled one is a space, and empty cells at the end are dropped. So `1`,`2`,empty,`4` reads `"12 4"`, writing `"12 4"` back fills the same cells, and an untouched control is `''`. It also validates itself: a value that is not empty but has fewer than `length` filled cells (a code still being typed, or one with a hole) gives the error `{ otpIncomplete: { filled, length } }`. An empty value is valid, so add `Validators.required` to make the code mandatory.  
- Inputs: `length` = 6; `numeric` = true; `invalid` = false
- Methods: `validate(control: AbstractControl)`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiPasswordInput (component, `ui-password-input`)
File: `form/src/password-input.ts`  
`ui-password-input` — password field with show/hide toggle (CVA).  
- Inputs: `placeholder` = ''; `size`: UiSize = 'md'; `autocomplete`: string = 'current-password'; `name`: string; `invalid` = false; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiRadioGroup (component, `ui-radio-group`)
File: `form/src/radio-group.ts`  
`ui-radio-group` — single-choice control (CVA). Built on native radio inputs so keyboard interaction and group semantics are handled by the platform.  
- Inputs: `options`: UiRadioOption[] = []; `label`: string; `orientation`: 'vertical' | 'horizontal' = 'vertical'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiRadioOption` (radio-group.ts)
### UiRating (component, `ui-rating`)
File: `form/src/rating.ts`  
`ui-rating` — star rating (CVA). A radio group: one tab stop, arrow keys (and Home/End) move the rating, clicking the current star again clears it to 0.  
- Inputs: `max` = 5; `label` = 'Rating'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSearchInput (component, `ui-search-input`)
File: `form/src/search-input.ts`  
`ui-search-input` — search field with icon and clear button (CVA).  
- Inputs: `placeholder` = 'Search…'; `label`: string; `size`: UiSize = 'md'; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSelect (component, `ui-select`)
File: `form/src/select.ts`  
`ui-select` — single-choice dropdown (CVA) built on a native `<select>` for full keyboard/screen-reader support. For rich filtering use combobox instead.  
- Inputs: `options`: UiSelectOption[] = []; `placeholder`: string; `label`: string; `size`: UiSize = 'md'; `invalid` = false; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiSelectOption` (select.ts)
### UiSlider (component, `ui-slider`)
File: `form/src/slider.ts`  
`ui-slider` — themed range slider (CVA).  
- Inputs: `min` = 0; `max` = 100; `step` = 1; `label` = 'Slider'; `showValue` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSwitch (component, `ui-switch`)
File: `form/src/switch.ts`  
`ui-switch` — on/off toggle (CVA). Uses role="switch" on a native checkbox.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTextarea (component, `ui-textarea`)
File: `form/src/textarea.ts`  
`ui-textarea` — multi-line text field (CVA). `autosize` makes it grow with what is typed, from `rows` lines up to `maxRows`, and takes away the drag handle: a comment box people resize by hand is a box that was the wrong size.  
- Inputs: `placeholder` = ''; `rows` = 4; `autocomplete`: string; `name`: string; `invalid` = false; `radius`: boolean = this.config.radius; `autosize` = false; `maxRows` = 8; `dir`: UiTextDir | null = null (0.33)
- Slots: `[textarea-leading]`, `[textarea-trailing]`, on the last line (0.33; Flutter `leading` / `trailing`, plus `dir` and `textStyle`)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTimePicker (component, `ui-time-picker`)
File: `form/src/time-picker.ts`  
`ui-time-picker` — time field (CVA; value is `HH:MM`), built on a native time input.  
- Inputs: `size`: UiSize = 'md'; `step` = 60; `invalid` = false; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTokenInput (component, `ui-token-input`)
File: `form/src/token-input.ts`  
`ui-token-input` — rich text where some pieces are atomic tokens rendered as chips (CVA over `UiTokenRun[]`). Tokens behave like single characters: the caret skips them and one Backspace removes one. Ctrl/⌘+B and Ctrl/⌘+I toggle bold and italic; pasting always inserts plain text. Insert a token at the caret with {@link insertToken}; `tokenLabel` turns a token value into the text its chip shows.  
- Inputs: `placeholder` = ''; `label` = ''; `multiline` = true; `minHeight`: string | null = null; `radius`: boolean = this.config.radius; `tokenLabel`: (token: string) => string = (t) => t
- Outputs: `focusChange`: boolean; `tokenClick`: string
- Methods: `insertToken(token: string)`, `focus()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiTokenRun` (token-input.ts)
- function `normalizeRuns` (token-input.ts)

## form-builder

### FbCanvas (component, `ui-fb-canvas`)
File: `form-builder/src/builder-canvas.ts`  
`ui-fb-canvas` — the form as it's being built: page tabs, then each question as a card (a small preview of how it will look), with sections as drop zones. Selecting a card opens it in the inspector.  
- Outputs: `addAt`: UiFbDropTarget; `deleteRequest`: FbDeleteRequest; `picked`: string | null; `open`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `FbDeleteRequest` (builder-canvas.ts)
### FbValueInput (component, `ui-fb-value`)
File: `form-builder/src/builder-condition.ts`  
`ui-fb-value` — the right-hand side of a rule, shaped by what's being compared: an option list for choices, a date picker (or "today ± days") for dates, a number box for counts, or another question's answer.  
- Inputs: `subject`: UiFbRefOption | null = null; `op`: UiFbOperator = 'eq'; `operand`: UiFbOperand | undefined = undefined; `forId`: string | null = null; `label` = 'Value'; `constOnly` = false
- Outputs: `operandChange`: UiFbOperand
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbConditionEditor (component, `ui-fb-condition`)
File: `form-builder/src/builder-condition.ts`  
`ui-fb-condition` — builds "when …" rules as sentences: pick a question, how to compare, and a value. Rules combine with all/any, and one level of nested groups covers "A and (B or C)".  
- Inputs: `condition`: UiFbCondition | undefined = undefined; `forId`: string | null = null; `nested` = false
- Outputs: `conditionChange`: UiFbCondition; `removed`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- function `asGroup` (builder-condition.ts)
- function `tidy` (builder-condition.ts)
- type `FbDragPayload` (builder-dnd.ts)
- interface `FbDropLine` (builder-dnd.ts)
- interface `FbDropState` (builder-dnd.ts)
### FbOptionsEditor (component, `ui-fb-options`)
File: `form-builder/src/builder-editors.ts`  
`ui-fb-options` — the choices of a dropdown, radio or checkbox field. Stored values follow the labels until the form has answers; after that they're locked (old answers point at them) and removing an option archives it.  
- Inputs: `field`: UiFbField
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbChecksEditor (component, `ui-fb-checks`)
File: `form-builder/src/builder-editors.ts`  
`ui-fb-checks` — whether an answer is needed, and the checks it must pass, each with its own message (shown under the field by default).  
- Inputs: `field`: UiFbField
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbCalcEditor (component, `ui-fb-calc`)
File: `form-builder/src/builder-editors.ts`  
`ui-fb-calc` — how a calculated field works its value out: an operation and its inputs (other answers or fixed numbers).  
- Inputs: `field`: UiFbField
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- const `FIELD_ICONS` (builder-icons.ts)
- const `STATIC_ICONS` (builder-icons.ts)
- const `GROUP_ICON` (builder-icons.ts)
- const `REPEAT_ICON` (builder-icons.ts)
- const `FB_ICONS` (builder-icons.ts)
### FbInspector (component, `ui-fb-inspector`)
File: `form-builder/src/builder-inspector.ts`  
`ui-fb-inspector` — settings for whatever is selected: a field, section, text block, page, or (with nothing selected) the form itself.  
- Inputs: `showHead` = true
- Outputs: `deleteRequest`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbLogicOverview (component, `ui-fb-logic`)
File: `form-builder/src/builder-logic.ts`  
`ui-fb-logic` — every rule in the form, in plain words, grouped by the question or page it belongs to; plus anything that needs fixing.  
- Outputs: `open`: string
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbPalette (component, `ui-fb-palette`)
File: `form-builder/src/builder-palette.ts`  
`ui-fb-palette` — the list of things to add. Click to add (after the selection, or at `target`), or drag onto the canvas.  
- Inputs: `compact` = false; `target`: UiFbDropTarget | null = null
- Outputs: `added`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbPreview (component, `ui-fb-preview`)
File: `form-builder/src/builder-preview.ts`  
`ui-fb-preview` — fill the form in as people will, on a desktop or phone width, with the saved JSON alongside. Paste saved answers to try editing.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### FbSourceSettings (component, `ui-fb-source-settings`)
File: `form-builder/src/builder-source.ts`  
`ui-fb-source-settings` — where a dropdown or multi-select gets its options from a registered list: which list, its settings (each a fixed value or another question's answer, for lists that depend on each other), and a live preview to try it.  
- Inputs: `field`: UiFbField
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiFbRefOption` (builder-store.ts)
- function `sameForm` (builder-store.ts)
- const `FB_SHARED_STYLES` (builder-styles.ts)
- interface `UiFbCalcContext` (calc.ts)
- interface `UiFbCalcOpInfo` (calc.ts)
- const `UI_FB_CALC_OPS` (calc.ts)
- function `calcOpInfo` (calc.ts)
- function `evaluateCalc` (calc.ts)
- function `describeCalc` (calc.ts)
- interface `UiFbConditionContext` (conditions.ts)
- function `isEmptyValue` (conditions.ts)
- function `isoDate` (conditions.ts)
- function `addDays` (conditions.ts)
- function `resolveOperand` (conditions.ts)
- function `evaluateCondition` (conditions.ts)
- interface `UiFbDescribeContext` (conditions.ts)
- function `describeCondition` (conditions.ts)
- function `conditionComplete` (conditions.ts)
- function `fbUid` (definition.ts)
- function `fbSlug` (definition.ts)
- function `fbKeyValid` (definition.ts)
- function `createDefinition` (definition.ts)
- function `createPage` (definition.ts)
- function `createField` (definition.ts)
- function `createGroup` (definition.ts)
- function `createStatic` (definition.ts)
- interface `UiFbIndexEntry` (definition.ts)
- type `UiFbIndex` (definition.ts)
- function `indexDefinition` (definition.ts)
- function `allElements` (definition.ts)
- function `allFields` (definition.ts)
- function `elementName` (definition.ts)
- function `updateElement` (definition.ts)
- function `updatePage` (definition.ts)
- interface `UiFbDropTarget` (definition.ts)
- function `insertElement` (definition.ts)
- function `removeElement` (definition.ts)
- function `isInside` (definition.ts)
- function `canDrop` (definition.ts)
- function `moveElement` (definition.ts)
- function `duplicateElement` (definition.ts)
- function `uniqueKey` (definition.ts)
- function `renameKey` (definition.ts)
- function `conditionRefs` (definition.ts)
- function `calcRefs` (definition.ts)
- type `UiFbRefKind` (definition.ts)
- function `sourceRefs` (definition.ts)
- interface `UiFbReference` (definition.ts)
- function `referencesTo` (definition.ts)
- function `subtreeIds` (definition.ts)
- function `externalReferences` (definition.ts)
- function `removeReferences` (definition.ts)
- function `dependencyGraph` (definition.ts)
- function `findCycles` (definition.ts)
- interface `UiFbProblem` (definition.ts)
- function `lintDefinition` (definition.ts)
- function `migrateDefinition` (definition.ts)
- interface `UiFbDiff` (definition.ts)
- function `diffDefinitions` (definition.ts)
- type `UiFormMode` (engine.ts)
- interface `UiFormEngineOptions` (engine.ts)
- interface `UiFbInstance` (engine.ts)
- interface `UiFbInstanceState` (engine.ts)
- interface `UiFbRemovedRow` (engine.ts)
- interface `UiFbErrorItem` (engine.ts)
- function `requiredMessage` (engine.ts)
- const `addrOf` (engine.ts)
- function `coerceValue` (engine.ts)
- type `UiFbValueKind` (field-types.ts)
- type `UiFbPaletteCategory` (field-types.ts)
- interface `UiFbFieldTypeInfo` (field-types.ts)
- const `UI_FB_FIELD_TYPES` (field-types.ts)
- interface `UiFbStaticTypeInfo` (field-types.ts)
- const `UI_FB_STATIC_TYPES` (field-types.ts)
- function `fieldTypeInfo` (field-types.ts)
- function `valueKindOf` (field-types.ts)
- interface `UiFbOperatorInfo` (field-types.ts)
- function `operatorInfo` (field-types.ts)
- function `operatorsFor` (field-types.ts)
- function `typesCompatible` (field-types.ts)
### UiFormBuilder (component, `ui-form-builder`)
File: `form-builder/src/form-builder.ts`  
`ui-form-builder` — build forms by dragging fields onto a page, then add rules: show or require a question only when other answers say so, group questions into sections (that repeat, or depend on other sections), split the form into steps, and add checks with your own messages. Bind `[(definition)]`; it's plain JSON, ready to store and to hand to `ui-form-renderer`. Pass the `published` version and its `submissionCount` so the builder protects answers that already exist (archiving instead of deleting, locking saved values, remembering renamed keys).  
- Inputs: `published`: UiFormDefinition | null = null; `submissionCount` = 0; `validators`: readonly UiFbValidatorDef[] = []; `optionSources`: readonly UiFbOptionSourceDef[] = []; `globalSettings`: UiFormGlobalSettings | null = null
- Two-way: `definition`: UiFormDefinition = createDefinition()
- Methods: `select(id: string | null)`, `undo()`, `redo()`, `clearHistory()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiFormRenderer (component, `ui-form-renderer`)
File: `form-builder/src/form-renderer.ts`  
`ui-form-renderer` — fills in a form built with `ui-form-builder`. Give it a definition, and (to edit or view saved answers) the saved `data`. It emits `submitted` with JSON ready to store: `{ formId, revision, data, … }`.  
- Inputs: `definition`: UiFormDefinition; `data`: Record<string, unknown> | null = null; `mode`: UiFormMode | null = null; `validators`: readonly UiFbValidatorDef[] = []; `optionSources`: readonly UiFbOptionSourceDef[] = []; `globalSettings`: UiFormGlobalSettings | null = null; `uploader`: UiFbUploader | null = null; `showTitle` = true; `showActions` = true; `submitLabel`: string | null = null; `cancelLabel`: string | null = null; `busy` = false; `today`: (() => string) | null = null
- Outputs: `submitted`: UiFormSubmission; `cancelled`: void; `valueChange`: Record<string, unknown>; `dirtyChange`: boolean
- Methods: `reset()`, `submit()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- function `optionLabel` (format.ts)
- function `formatDate` (format.ts)
- function `formatValue` (format.ts)
### UiFormGlobalSettingsEditor (component, `ui-form-global-settings`)
File: `form-builder/src/global-settings-editor.ts`  
`ui-form-global-settings` — the app's form settings page: the lists every form can search (where to ask, how it pages, how to read the reply, with a test), and what new forms start with. Bind `[(settings)]` and store the JSON; pass it to `ui-form-builder` and `ui-form-renderer` as `globalSettings`. Requests go through the app's hook (`provideUiFormHttpSources`), which adds the login and limits which servers may be called. No secrets are stored here.  
- Inputs: `usage`: Record<string, number>
- Two-way: `settings`: UiFormGlobalSettings = createGlobalSettings()
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiFormGlobalSettings` (global-settings.ts)
- function `createGlobalSettings` (global-settings.ts)
- function `sourcesFromSettings` (global-settings.ts)
- interface `UiFbHttpSourceConfig` (http-sources.ts)
- type `UiFbSourceFetch` (http-sources.ts)
- interface `UiFbHttpSourcesOptions` (http-sources.ts)
- const `UI_FB_HTTP_SOURCES` (http-sources.ts)
- function `provideUiFormHttpSources` (http-sources.ts)
- function `sourceFetch` (http-sources.ts)
- function `readPath` (http-sources.ts)
- function `fillPattern` (http-sources.ts)
- function `originOf` (http-sources.ts)
- function `originAllowed` (http-sources.ts)
- function `sourceUrl` (http-sources.ts)
- function `readSourceReply` (http-sources.ts)
- function `httpOptionSource` (http-sources.ts)
- interface `UiFbSourceItem` (option-sources.ts)
- interface `UiFbChoice` (option-sources.ts)
- interface `UiFbSourceQuery` (option-sources.ts)
- interface `UiFbSourcePage` (option-sources.ts)
- interface `UiFbSourceParamSpec` (option-sources.ts)
- interface `UiFbOptionSourceDef` (option-sources.ts)
- const `UI_FB_OPTION_SOURCES` (option-sources.ts)
- function `provideUiFormOptionSources` (option-sources.ts)
- const `UI_FB_SOURCE_FIELD_TYPES` (option-sources.ts)
- function `isChoice` (option-sources.ts)
- function `optionValueOf` (option-sources.ts)
- function `toChoice` (option-sources.ts)
- function `sourceHasMore` (option-sources.ts)
### UiFbFieldView (component, `ui-fb-field`)
File: `form-builder/src/renderer-field.ts`  
`ui-fb-field` — one field of a `ui-form-renderer`: label, help, control and messages, laid out as the form (or the field) asks. Styles are global but all scoped under `.ui-fbf` so placements can reach into the library controls.  
- Inputs: `engine`: UiFormEngine; `field`: UiFbField; `row`: string | null = null; `idPrefix` = 'fb'; `uploader`: UiFbUploader | null = null
- Methods: `focus()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiFbUploader` (renderer-field.ts)
- const `UI_FB_SCHEMA_VERSION` (schema.ts)
- type `UiFbFieldType` (schema.ts)
- type `UiFbStaticType` (schema.ts)
- type `UiFbLabelPlacement` (schema.ts)
- type `UiFbErrorPlacement` (schema.ts)
- type `UiFbWidth` (schema.ts)
- type `UiFbOperator` (schema.ts)
- type `UiFbOperand` (schema.ts)
- interface `UiFbConditionRule` (schema.ts)
- interface `UiFbConditionGroup` (schema.ts)
- type `UiFbCondition` (schema.ts)
- type `UiFbToggle` (schema.ts)
- interface `UiFbVisibility` (schema.ts)
- interface `UiFbSetValue` (schema.ts)
- interface `UiFbValidatorRule` (schema.ts)
- type `UiFbCalcOp` (schema.ts)
- type `UiFbCalcArg` (schema.ts)
- interface `UiFbCalc` (schema.ts)
- interface `UiFbOption` (schema.ts)
- interface `UiFbLayout` (schema.ts)
- interface `UiFbFieldProps` (schema.ts)
- type `UiFbSourceParamValue` (schema.ts)
- interface `UiFbOptionSourceRef` (schema.ts)
- interface `UiFbField` (schema.ts)
- interface `UiFbRepeat` (schema.ts)
- interface `UiFbGroup` (schema.ts)
- interface `UiFbStatic` (schema.ts)
- type `UiFbElement` (schema.ts)
- interface `UiFbJump` (schema.ts)
- interface `UiFbPage` (schema.ts)
- interface `UiFbSettings` (schema.ts)
- interface `UiFormDefinition` (schema.ts)
- interface `UiFbFileValue` (schema.ts)
- interface `UiFormSubmission` (schema.ts)
- interface `UiFbChange` (schema.ts)
### FbSettingsFields (component, `ui-fb-settings-fields`)
File: `form-builder/src/settings-fields.ts`  
`ui-fb-settings-fields` — the form-wide options (where labels and errors go, when problems show, buttons and steps). Used for one form in the builder, and for the defaults of new forms in `ui-form-global-settings`.  
- Inputs: `settings`: UiFbSettings
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiFbSourcePicker (component, `ui-fb-source-picker`)
File: `form-builder/src/source-picker.ts`  
`ui-fb-source-picker` — a searchable dropdown over an option source: type to search, scroll to load the next page, pick one (or several, as chips). Answers are `{ value, label }`. Used by the renderer for sourced fields and by the builder wherever a sourced value is picked (rules, previews).  
- Inputs: `source`: UiFbOptionSourceDef; `params`: Record<string, unknown>; `multiple` = false; `value`: unknown = null; `placeholder` = 'Search…'; `disabled` = false; `invalid` = false; `inputId` = ''; `ariaLabel` = ''
- Outputs: `valueChange`: UiFbChoice | UiFbChoice[] | null
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiFbValidatorResult` (validators.ts)
- interface `UiFbValidatorContext` (validators.ts)
- interface `UiFbParamSpec` (validators.ts)
- interface `UiFbValidatorDef` (validators.ts)
- const `UI_FB_VALIDATORS` (validators.ts)
- function `provideUiFormValidators` (validators.ts)
- function `resolveDateParam` (validators.ts)
- function `describeDateParam` (validators.ts)
- const `UI_FB_PATTERN_PRESETS` (validators.ts)
- const `UI_FB_BUILTIN_VALIDATORS` (validators.ts)
- const `UI_FB_IMPLICIT_VALIDATOR` (validators.ts)
- function `validatorsFor` (validators.ts)
- function `formatMessage` (validators.ts)
- function `comparisonWords` (validators.ts)
- function `todayIso` (validators.ts)

## fx

### UiCursor (component, `ui-cursor`)
File: `fx/src/cursor.ts`  
`ui-cursor` — custom cursor: a precise dot plus a lagging ring that grows over interactive elements. Mount once near the app root. Hidden on touch devices and when reduced motion is requested. While it is actually drawing it puts `ui-cursor-on` on `<html>`; hide the native cursor with that, never unconditionally, or users it hides itself from are left with no cursor at all: html.ui-cursor-on, html.ui-cursor-on * { cursor: none; }  
- Inputs: `interactiveSelector` = 'a
- [ ] Flutter port (not applicable: touch has no cursor; UiMagnetic gives touch feedback instead)  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiDriftRow (component, `ui-drift-row`)
File: `fx/src/drift-row.ts`  
`ui-drift-row` — a horizontal rail that gently auto-scrolls ("drifts") on its own yet stays fully scrollable, swipeable and draggable by the user. Project any content (cards, media, chips) straight inside: <ui-drift-row [speed]="26" direction="auto" gap="1.4rem"> <article class="card">…</article> <article class="card">…</article> </ui-drift-row> Behaviour: - Drifts toward a random side by default (`direction="auto"`), or a fixed side with `direction="left" | "right"`, ping-ponging at each end. - Pauses the drift while the user hovers, grabs/drags, swipes or wheels the rail, then resumes after `resumeDelay` ms of stillness. - Click-drag to scroll on desktop (a real click still fires if you don't drag); native touch swipe on mobile. - Honors `prefers-reduced-motion`: no auto-drift, but still scrollable. Self-contained — no global CSS required.  
- Inputs: `speed` = 26; `direction`: UiDriftDirection = 'auto'; `gap` = '1.5rem'; `pauseOnHover` = true; `resumeDelay` = 1800; `fade` = true; `interactive` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiDriftDirection` (drift-row.ts)
### UiGlyphField (component, `ui-glyph-field`)
File: `fx/src/glyph-field.ts`  
`ui-glyph-field` — animated binary/glyph field rendered to a canvas. A reusable, asset-free take on the portfolio's binary-face background: a grid of flickering glyphs lit by a drifting intensity field, tinted along the brand ramp (ember → blood → rose). Use as a fixed page backdrop (`fixed`) or contained within a positioned parent. Honors `prefers-reduced-motion`.  
- Inputs: `fixed` = false; `opacity` = 0.55; `chars` = '01'; `cell` = 16; `speed` = 1; `colors`: [string, string, string] = ['#5a2832'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiGrain (component, `ui-grain`)
File: `fx/src/grain.ts`  
`ui-grain` — animated film-grain overlay. Mount once near the app root (fixed, non-interactive).  
- Inputs: `opacity` = 0.06
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiIntroLoader (component, `ui-intro-loader`)
File: `fx/src/intro-loader.ts`  
`ui-intro-loader` — full-screen intro veil that wipes away after `duration` (or when `[(open)]` is set false). Project a logo/wordmark as content.  
- Inputs: `duration` = 1400
- Two-way: `open` = true
- Outputs: `done`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiMagnetic (directive, `[uiMagnetic]`)
File: `fx/src/magnetic.ts`  
`uiMagnetic` — the host gently pulls toward the cursor on hover and springs back on leave (a signature "dramatic" micro-interaction). Self-contained; disabled on touch / reduced-motion. <a uiMagnetic [magneticStrength]="0.4">…</a>  
- Inputs: `magneticStrength` = 0.35; `magneticRadius` = 0
- [x] Flutter port (press tilt on touch, hover pull with a mouse)  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiMarquee (component, `ui-marquee`)
File: `fx/src/marquee.ts`  
`ui-marquee` — infinite horizontal scroller with edge fade; pauses on hover.  
- Inputs: `items`: string[] = []; `duration` = 38; `gap` = '3rem'; `reverse` = false; `separator` = '✦'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiReveal (directive, `[uiReveal]`)
File: `fx/src/reveal.ts`  
`uiReveal` — reveals the host as it scrolls into view (IntersectionObserver). Self-contained (applies its own inline transitions; no global CSS needed). Honors `prefers-reduced-motion`. <div uiReveal>…</div> <div uiReveal="blur" [revealDelay]="120">…</div>  
- Inputs: `uiReveal`: UiRevealMode = 'up'; `revealDelay` = 0; `revealThreshold` = 0.18; `revealOnce` = true; `duration` = 900
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiRevealMode` (reveal.ts)
### UiScrollProgress (component, `ui-scroll-progress`)
File: `fx/src/scroll-progress.ts`  
`ui-scroll-progress` — fixed top bar tracking page scroll, using the brand gradient + glow.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSectionLabel (component, `ui-section-label`)
File: `fx/src/section-label.ts`  
`ui-section-label` — section marker: eyebrow (accent bar + small caps) or the editorial bracket `[ 00 · INDEX ]`; `auto` = bracket on Dark Orange.  
- Inputs: `index`: string = ''; `label`: string; `variant`: UiSectionLabelVariant = 'auto'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSplitText (directive, `[uiSplitText]`)
File: `fx/src/split-text.ts`  
`uiSplitText` — splits the host's text into per-character spans and animates them in with a stagger (Web Animations API; no global keyframes needed). Best on a single line/heading. Honors `prefers-reduced-motion`. <h1 uiSplitText>Mohamed</h1>  
- Inputs: `stagger` = 35; `base` = 120; `duration` = 900
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


### UiWaveFooter (component, `ui-wave-footer`)
File: `fx/src/sea.ts`  
`ui-wave-footer` — stacked wave bands pinned to the bottom of the nearest positioned container; each drifts sideways (the tide), alternating direction.  
- Inputs: `layers`: 2 | 3 = 3; `height` = 120; `opacity` = 0.5
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiOceanHero (component, `ui-ocean-hero`)
File: `fx/src/sea.ts`  
`ui-ocean-hero` — full-bleed sea backdrop: the theme hero gradient, optional photo wash, slow diagonal light sweep.  
- Inputs: `src`: string | null = null; `shimmer` = true; `fill` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiCoralDecor (component, `ui-coral-decor`)
File: `fx/src/sea.ts`  
`ui-coral-decor` — coral on a sand mound tucked into a corner; floats gently.  
- Inputs: `corner`: UiDecorCorner = 'bl'; `scale` = 1; `opacity` = 0.9
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiPalmDecor (component, `ui-palm-decor`)
File: `fx/src/sea.ts`  
`ui-palm-decor` — two palm silhouettes leaning out of a corner; floats gently.  
- Inputs: `corner`: UiDecorCorner = 'bl'; `scale` = 1; `opacity` = 0.9
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSunrise (component, `ui-sunrise`)
File: `fx/src/sea.ts`  
`ui-sunrise` — coral sun with a sand glow behind a logo slot; rises on mount, then pulses.  
- Inputs: `size` = 120
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSeaSurface (component, `ui-sea-surface`)
File: `fx/src/sea.ts`  
`ui-sea-surface` — a sea region in one element: scoped theme (maldives), background, waves and corner decor.  
- Inputs: `theme`: string | null = 'maldives'; `waves` = true; `waveLayers` = 3; `waveHeight` = 120; `waveOpacity` = 0.5; `coral`, `palm`: UiDecorCorner | null = null; `decorScale` = 1
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTide (directive, `[uiTide]`)
File: `fx/src/sea.ts`  
`[uiTide]` — staggered fade + 8px slide-up for list items (ui-slide-up-enter).  
- Inputs: `uiTide` (index) = 0; `tideDelay` = 0; `tideStep` = 60
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### fx.css `.ui-pulse`, `.ui-gradient-text`, `.ui-glow` (utility classes)
File: `styles/fx.css`, `styles/theme-animations.css`  
Flutter twins: `UiPulse`, `UiGradientText`, `UiGlow`, with the maldives signature motion (tide, shimmer) only.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- types `UiWaveLayers`, `UiDecorCorner`, `UiSeaShape`, `UiSeaTone` (sea.ts, sea-shapes.ts)

## layout

### UiAspectRatio (component, `ui-aspect-ratio`)
File: `layout/src/aspect-ratio.ts`  
`ui-aspect-ratio` — constrains projected content to a fixed width:height ratio.  
- Inputs: `ratio` = '16 / 9'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiContainer (component, `ui-container`)
File: `layout/src/container.ts`  
`ui-container` — centered, max-width content wrapper with responsive padding.  
- Inputs: `size`: 'sm' | 'md' | 'lg' | 'xl' | 'full' = 'lg'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiGrid (component, `ui-grid`)
File: `layout/src/grid.ts`  
`ui-grid` — CSS grid with a fixed column count and token-based gap.  
- Inputs: `columns`: number | string = 12; `min`: string; `gap`: Gap = 4
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiPanelSection (component, `ui-panel-section`)
File: `layout/src/panel-section.ts`  
`ui-panel-section` — a compact, collapsible titled group for inspector and settings panels. Unlike an accordion it's built for controls: dense spacing, full-contrast content, and a slot for actions in the header (`[panel-actions]`), such as an Add button.  
- Inputs: `title`: string; `collapsible` = true; `badge`: string | number | null = null
- Two-way: `open` = true
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiResizeHandle (component, `ui-resize-handle`)
File: `layout/src/resize-handle.ts`  
`ui-resize-handle` — a draggable edge that sets the size of the panel next to it. Put it on the panel's inner edge and bind `[(size)]` (pixels). `edge` says where the handle sits relative to the panel it sizes: a bottom panel's handle is on its `top`, so dragging up makes it bigger. Releasing near one of `snaps` settles on it. Double-click cycles through the snaps; arrow keys resize by 16px (Shift: 64px); Home/End go to min/max.  
- Inputs: `min` = 0; `max` = 10000; `snaps`: readonly number[] = []; `edge`: 'top' | 'bottom' | 'left' | 'right' = 'top'; `label` = 'Resize'; `snapDistance` = 28
- Two-way: `size` = 240
- Outputs: `resizeEnd`: number
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiScrollArea (component, `ui-scroll-area`)
File: `layout/src/scroll-area.ts`  
`ui-scroll-area` — themed, thin-scrollbar scroll container with a fixed max height.  
- Inputs: `maxHeight` = '240px'; `axis`: 'y' | 'x' | 'both' = 'y'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSidebarLayout (component, `ui-sidebar-layout`)
File: `layout/src/sidebar-layout.ts`  
`ui-sidebar-layout` — responsive application shell. A fixed sidebar beside a scrolling main column on desktop; below `breakpoint` the sidebar becomes an off-canvas drawer toggled by a built-in hamburger, over a dimmed backdrop. Project the nav into `[sidebar]`, the top-bar content into `[header]`, and the page into the default slot: <ui-sidebar-layout [breakpoint]="860"> <my-nav sidebar></my-nav> <h1 header>Page title</h1> <router-outlet></router-outlet> </ui-sidebar-layout> Bind `[(open)]` to drive the mobile drawer yourself (e.g. close it on navigation), or call `close()`. The breakpoint is driven by `matchMedia`, not a hardcoded CSS `@media`, so it stays configurable per app.  
- Inputs: `breakpoint` = 860; `sidebarWidth` = '248px'; `mainLandmark` = true; `bar` = true (0.37); `fill` = false (0.37)
- Two-way: `open` = false
- Methods: `toggle()`, `close()`; readonly `compact` (Flutter `UiSidebarLayout.of(context).compact`)
- Strings: `sidebarToggle`, `sidebarClose`, `sidebarLabel`; RTL: sidebar on the start side
- Slots (0.41): `[sidebar-header]`, `[sidebar-footer]` fixed around the scrolling `[sidebar]` (Flutter `sidebarHeader` / `sidebarFooter`)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSpacer (component, `ui-spacer`)
File: `layout/src/spacer.ts`  
`ui-spacer` — flexible gap that pushes siblings apart inside a flex layout.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSplitter (component, `ui-splitter`)
File: `layout/src/splitter.ts`  
`ui-splitter` — two resizable panes with a draggable divider. Project two elements with `[split-a]` and `[split-b]`. The divider is a separator whose `aria-orientation` is the direction of the line itself: side-by-side panes (`orientation="horizontal"`) are split by a vertical line.  
- Inputs: `orientation`: 'horizontal' | 'vertical' = 'horizontal'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiStack (component, `ui-stack`)
File: `layout/src/stack.ts`  
`ui-stack` — flexbox row/column with token gap and alignment.  
- Inputs: `direction`: 'row' | 'column' = 'column'; `gap`: Gap = 3; `align`: 'start' | 'center' | 'end' | 'stretch' = 'stretch'; `justify`: 'start' | 'center' | 'end' | 'space-between' = 'start'; `wrap` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## link

### UiBlockquote (component, `ui-blockquote`)
File: `link/src/blockquote.ts`  
`ui-blockquote` — quotation block with optional citation.  
- Inputs: `cite`: string
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiInlineCode (component, `ui-inline-code`)
File: `link/src/inline-code.ts`  
`ui-inline-code` — inline code token.  
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiKbd (component, `ui-kbd`)
File: `link/src/kbd.ts`  
`ui-kbd` — keyboard key hint.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiLink (component, `ui-link`)
File: `link/src/link.ts`  
`ui-link` — themed anchor. External links get safe rel + a visual marker.  
- Inputs: `href`: string; `external` = false; `tone`: 'primary' | 'muted' | 'plain' = 'primary'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## list

### UiList (component, `ui-list`)
File: `list/src/list.ts`  
`ui-list` — semantic list container. Project `ui-list-item` children.  
- Inputs: `bordered` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiListItem (component, `ui-list-item`)
File: `list/src/list.ts`  
`ui-list-item` — a row in `ui-list`. Optional `[item-leading]` / `[item-trailing]` slots.  
- Inputs: `interactive` = false; `selected` = false; `disabled` = false
- Outputs: `activate`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## media

### UiCarousel (component, `ui-carousel`)
File: `media/src/carousel.ts`  
`ui-carousel` — image slideshow with arrows, dots, a finger-following swipe and optional autoplay. Anything projected into it is laid over the slides (a title on a gradient, a counter), and a swipe that starts on it still turns the slide. A swipe here is the carousel's own: touches that start inside it don't reach gesture handlers further up the page, so a page-level swipe between screens never fires from a photo.  
- Inputs: `slides`: UiCarouselSlide[] = []; `autoplay` = 0; `dots` = true; `arrows` = true
- Two-way: `index` = 0
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiCarouselSlide` (carousel.ts)
### UiDeviceFrame (component, `ui-device-frame`)
File: `media/src/device-frame.ts`  
`ui-device-frame` — a phone-shaped frame whose screen is exactly `width` × `height` CSS pixels, scaled to fit the space it's given. What you project renders at true phone size (so a 390px-wide page lays out as it would on a phone) and is scaled down only visually. `scale` is readable from a template reference, for overlays that have to line up with the screen.  
- Inputs: `width` = 390; `height` = 844; `bezel` = true; `island` = true; `maxScale` = 1
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiGallery (component, `ui-gallery`)
File: `media/src/gallery.ts`  
`ui-gallery` — responsive thumbnail grid with a lightbox (prev/next, Esc to close). The lightbox is a modal dialog: Tab stays inside it, and closing returns focus to the thumbnail that opened it.  
- Inputs: `images`: UiGalleryImage[] = []; `minThumb` = '120px'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiGalleryImage` (gallery.ts)
### UiImagePicker (component, `ui-image-picker`)
File: `media/src/image-picker.ts`  
`ui-image-picker` — a grid of image tiles to choose from: search results, stock art, uploads. Tap or Enter picks (`pick`). One tile can show as busy while its choice is being fetched. When `hasMore` is on, scrolling near the end asks for the next page (`more`) — there is no "Load more" button to reach for with a thumb. Thumbnails that fail to load show the label on a plain tile rather than a broken-image glyph. Tiles sit on a faint checkerboard so white or transparent art is visible. With `dragType` set, tiles can be dragged: the item's `id` is the drag data under that type.  
- Inputs: `items`: UiImagePickerItem[] = []; `busyId`: string | null = null; `loading` = false; `hasMore` = false; `minThumb` = '96px'; `captions` = false; `emptyText` = ''; `dragType`: string | null = null
- Outputs: `pick`: UiImagePickerItem; `more`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiImagePickerItem` (image-picker.ts)

## navigation

### UiAnchorNav (component, `ui-anchor-nav`)
File: `navigation/src/anchor-nav.ts`  
`ui-anchor-nav` — scrollspy navigation: highlights the section in view and scrolls to it on click. The sections are looked up by id once, just after init; sections added later are not watched.  
- Inputs: `items`: UiAnchorItem[] = []; `offset` = 80
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiAnchorItem` (anchor-nav.ts)
### UiBottomNav (component, `ui-bottom-nav`)
File: `navigation/src/bottom-nav.ts`  
`ui-bottom-nav` — mobile-style bottom navigation bar (glass-capable). A `<nav>` of buttons; the active one carries `aria-current="page"`. (It used to claim `role="tablist"` without tab panels or arrow-key handling, which told screen readers it was something it was not.)  
- Inputs: `items`: UiBottomNavItem[] = []; `label`: string; `glass`: boolean = this.config.glass; `iconSize`: number = 22
- Two-way: `active`: string = ''
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiBottomNavItem` (bottom-nav.ts)
### UiBreadcrumbs (component, `ui-breadcrumbs`)
File: `navigation/src/breadcrumbs.ts`  
`ui-breadcrumbs` — hierarchical trail. Emits `(navigate)` for items without href.  
- Inputs: `items`: UiBreadcrumb[] = []; `separator` = '/'
- Outputs: `navigate`: UiBreadcrumb
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiBreadcrumb` (breadcrumbs.ts)
### UiMenubar (component, `ui-menubar`)
File: `navigation/src/menubar.ts`  
`ui-menubar` — application-style horizontal menu bar with dropdown menus (one open at a time). <p>Keyboard: ArrowLeft/Right move between the top items (and between open menus); ArrowDown, Enter or Space open a menu and focus its first item; inside a menu ArrowUp/Down, Home and End move between items, Escape closes it and returns focus to its top item, and Tab closes it.</p>  
- Inputs: `menus`: UiMenubarMenu[] = []
- Outputs: `select`: UiMenubarItem
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiMenubarItem` (menubar.ts)
- interface `UiMenubarMenu` (menubar.ts)
### UiNavbar (component, `ui-navbar`)
File: `navigation/src/navbar.ts`  
`ui-navbar` — top navigation surface (glass-capable). Slots: `[navbar-brand]`, default (center/links), `[navbar-actions]`.  
- Inputs: `sticky` = false; `label`: string; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiPagination (component, `ui-pagination`)
File: `navigation/src/pagination.ts`  
`ui-pagination` — page navigation with truncation and prev/next.  
- Inputs: `total` = 1; `siblings` = 1; `label` = 'Pagination'
- Two-way: `page` = 1
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiSideNav (component, `ui-side-nav`)
File: `navigation/src/side-nav.ts`  
`ui-side-nav` — vertical, grouped navigation rail (docs/app sidebar). Bind `[(active)]` to the selected value and listen to `(navigate)`. Router- agnostic: map the emitted item to a route yourself. Give items an `href` to render them as links (crawlable, open-in-new-tab) while still routing through `(navigate)` on a plain click.  
- Inputs: `groups`: UiSideNavGroup[] = []; `label` = 'Sidebar'
- Two-way: `active`: string = ''
- Outputs: `navigate`: UiSideNavItem
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiSideNavItem` (side-nav.ts)
- interface `UiSideNavGroup` (side-nav.ts)
### UiStepper (component, `ui-stepper`)
File: `navigation/src/stepper.ts`  
`ui-stepper` — horizontal progress through ordered steps.  
- Inputs: `steps`: UiStep[] = []; `active` = 0
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiStep` (stepper.ts)

## overlay

### UiBackdrop (component, `ui-backdrop`)
File: `overlay/src/backdrop.ts`  
`ui-backdrop` — full-viewport scrim behind overlays. Emits `(backdropClick)`. Render conditionally with `@if`; it animates via the shared backdrop fade.  
- Inputs: `blur` = false
- Outputs: `backdropClick`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiClickOutside (directive, `[uiClickOutside]`)
File: `overlay/src/click-outside.ts`  
`uiClickOutside` — emits when a pointer/focus event occurs outside the host element. Used by popovers, dropdowns, and menus to dismiss on outside click.  
- Outputs: `uiClickOutside`: PointerEvent
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase  (Flutter: use `TapRegion` directly; the overlays here use it for outside taps)

### UiContextMenuPanel (component, `ui-context-menu-panel`)
File: `overlay/src/context-menu.ts`  
Internal panel rendered in the context-menu overlay.  
- Methods: `focusFirst()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiContextMenu (directive, `[uiContextMenu]`)
File: `overlay/src/context-menu.ts`  
`uiContextMenu` — opens a menu at the pointer on right-click (CDK Overlay). Bind the items and listen to `(contextSelect)`.  
- Inputs: `uiContextMenu`: UiMenuItem[] = []
- Outputs: `contextSelect`: UiMenuItem
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiMenu (component, `ui-menu`)
File: `overlay/src/menu.ts`  
`ui-menu` — dropdown menu anchored to a trigger (CDK Overlay). Project the trigger with `[menu-trigger]`; pass `items` and listen to `(select)`. Arrow keys move focus, Enter activates, Escape closes (WAI-ARIA menu). Choosing an item or pressing Escape puts focus back on the trigger; Tab closes the menu and moves on from the trigger.  
- Inputs: `items`: UiMenuItem[] = []; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius
- Two-way: `open` = false
- Outputs: `select`: UiMenuItem
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiMenuItem` (menu.ts)
### UiPopover (component, `ui-popover`)
File: `overlay/src/popover.ts`  
`ui-popover` — click-triggered floating panel anchored to its trigger via the CDK Overlay. Project the trigger with `[popover-trigger]` and the panel body as default content. Dismisses on outside click and Escape. Focus is not moved into the panel; if it is inside when Escape closes it, it goes back to the trigger. The panel is a `role="dialog"` named by `label` when set, and otherwise by the trigger's text (`aria-labelledby`).  
- Inputs: `placement`: UiPopoverPlacement = 'bottom-start'; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius; `label` = ''
- Two-way: `open` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiPopoverPlacement` (popover.ts)
### UiTooltipPanel (component, `ui-tooltip-panel`)
File: `overlay/src/tooltip.ts`  
Internal panel rendered inside the CDK overlay.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTooltip (directive, `[uiTooltip]`)
File: `overlay/src/tooltip.ts`  
`uiTooltip` — accessible hover/focus tooltip backed by the CDK Overlay. Sets `aria-describedby` on the host so screen readers announce it.  
- Inputs: `uiTooltip`: string; `uiTooltipPosition`: UiTooltipPosition = 'top'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiTooltipPosition` (tooltip.ts)

### UiHintPanel (component, `ui-hint-panel`)
File: `overlay/src/hint.ts`  
Internal callout rendered inside the CDK overlay (Flutter `UiHintBubble`).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiHint (directive, `[uiHint]`) (0.33)
File: `overlay/src/hint.ts`  
`uiHint` — a coachmark opened from code: a polite live region pointed at its host, never a dialog, never takes focus. Closes on a tap on it or its anchor, Escape, or a timeout.  
- Inputs: `uiHint`: string; `uiHintOpen`: boolean (model) = false; `uiHintPlacement`: UiHintPlacement = 'top'; `uiHintDuration` = 6000; `uiHintDismissible` = false
- Outputs: `uiHintClosed`: UiHintCloseReason
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- types `UiHintPlacement`, `UiHintCloseReason` (hint.ts)

## pdf-viewer

### UiPdfViewer (component, `ui-pdf-viewer`)
File: `pdf-viewer/src/pdf-viewer.ts`  
`ui-pdf-viewer` — renders a PDF with page navigation and zoom. `pdfjs-dist` is loaded via a dynamic import so it ships only when this component is used (its own secondary entry point; pair with `@defer` for full lazy loading). Override `workerSrc` to self-host the worker instead of the CDN default.  
- Inputs: `src`: string; `workerSrc`: string; `fill` = false (0.41.1)
- [x] Flutter port  - [x] widget tests  - [ ] golden/visual check (PDFium does not load under flutter test; check on device)  - [x] showcase


## progress

### UiMeter (component, `ui-meter`)
File: `progress/src/meter.ts`  
`ui-meter` — a measurement against a budget, e.g. file size against a limit. Unlike a progress bar it isn't a task finishing: it turns warning past `warnAt` and danger past `dangerAt`, and says so in its text, so the colour is never the only signal.  
- Inputs: `value` = 0; `max` = 100; `warnAt`: number | null = null; `dangerAt`: number | null = null; `label` = ''; `valueText` = ''; `warnText` = 'Getting large'; `dangerText` = 'Over the limit'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiProgressBar (component, `ui-progress-bar`)
File: `progress/src/progress-bar.ts`  
`ui-progress-bar` — determinate or indeterminate progress. Set `value` (0–100) for determinate; omit/null for indeterminate.  
- Inputs: `value`: number | null = null; `tone`: UiStatus = 'primary'; `label` = 'Progress'
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase


## sequencer

### UiScrubber (component, `ui-scrubber`)
File: `sequencer/src/scrubber.ts`  
`ui-scrubber` — a strip that slides under a playhead fixed at its centre, the way mobile video editors do it: the finger moves the content, never a tiny handle. Sections (`markers`) run along it as labelled segments, `lanes` draw layers as thin stacked lines (a flattened timeline), and `ticks` mark points of interest such as keyframes. Past `end`, the strip is shaded. <p>Holding still on it emits `longPress` — for opening the full timeline — and puts the playhead back.</p> <p>Drag sideways to scrub; a flick glides and slows. Pinch with two fingers to zoom (`zoom` is pixels per unit, two-way). With a mouse, drag or use the wheel. As a slider it takes ←/→ (Shift for bigger steps), PageUp/PageDown and Home/End.</p> <p>The finger is followed with touch events and the strip claims every direction (`touch-action: none`) — a sideways drag the browser could read as a swipe would otherwise never arrive as pointer events. Pointer events serve the mouse and pen.</p>  
- Inputs: `length` = 100; `markers`: readonly UiScrubberMarker[] = []; `ticks`: readonly UiScrubberTick[] = []; `lanes`: readonly UiScrubberLane[] = []; `end`: number | null = null; `label` = 'Position'; `valueText` = ''; `minZoom` = 0.02; `maxZoom` = 4
- Two-way: `value` = 0; `zoom` = 0.25
- Outputs: `settle`: number; `longPress`: void
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiScrubberMarker` (scrubber.ts)
- interface `UiScrubberLane` (scrubber.ts)
- interface `UiScrubberTick` (scrubber.ts)
### UiSequencer (component, `ui-sequencer`)
File: `sequencer/src/sequencer.ts`  
`ui-sequencer` — a timeline editor: one row per layer, a bar for the range each is active, diamonds for its keyframes, a draggable playhead and labelled markers along a ruler. Drag a bar to move it, its edges to trim it, a diamond to retime it (clamped to its bar). Bars, edges and diamonds snap to markers, the playhead and other bars' edges — hold Alt to place freely. Drag a row's grip to reorder. Everything is reported, nothing is mutated: the host owns the rows. Without labels (`showLabels` false) the rows are bars only, the way phone video editors show clips: a tap on a bar selects it and shows its name for a moment; holding a bar lifts it, and then it follows the finger both ways — along the timeline to move it, up or down to reorder. A plain swipe scrolls, two fingers pinch to zoom (Ctrl + wheel with a mouse), and the edges still trim. Keyboard: a focused bar moves with ←/→ (Shift for a larger step) and trims with [ and ]; a focused diamond retimes with ←/→, Delete removes it, and the context-menu key opens its menu.  
- Inputs: `rows`: readonly UiSequencerRow[] = []; `length` = 100; `markers`: readonly UiSequencerMarker[] = []; `title` = 'Layers'; `emptyText` = 'Nothing here yet'; `labelWidth` = 200; `rowHeight` = 30; `snapPixels` = 6; `keyStep` = 0.01; `endDraggable` = false; `endLabel` = 'Drag to change where it ends'; `reorderable` = true; `maxZoom` = 16; `showLabels` = true; `end`: number | null = null; `compact` = false
- Two-way: `zoom` = 1; `playhead` = 0; `selectedRowId`: string | null = null; `selectedKeyframeId`: string | null = null
- Outputs: `rangeChange`: UiSequencerRangeChange; `keyframeChange`: UiSequencerKeyframeChange; `keyframeMenu`: UiSequencerKeyframeRef; `muteToggle`: string; `lockToggle`: string; `scrub`: number
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiSequencerKeyframe` (sequencer.ts)
- interface `UiSequencerRow` (sequencer.ts)
- interface `UiSequencerMarker` (sequencer.ts)
- interface `UiSequencerRangeChange` (sequencer.ts)
- interface `UiSequencerKeyframeChange` (sequencer.ts)
- interface `UiSequencerKeyframeRef` (sequencer.ts)

## skeleton

### UiSkeleton (component, `ui-skeleton`)
File: `skeleton/src/skeleton.ts`  
`ui-skeleton` — content placeholder shown while data loads.  
- Inputs: `shape`: 'rect' | 'circle' | 'text' = 'rect'; `width`: string; `height`: string
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase


## spinner

### UiSpinner (component, `ui-spinner`)
File: `spinner/src/spinner.ts`  
`ui-spinner` — indeterminate activity indicator.  
- Inputs: `size`: UiSize = 'md'; `label` = 'Loading'
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase


## src

- const `UI_ANIM` (animations.ts)
- interface `UiConfig` (config.ts)
- const `UI_CONFIG` (config.ts)
- const `defaultUiConfig` (config.ts)
- function `provideUiConfig` (config.ts)
- function `injectUiConfig` (config.ts)
- type `UiSize` (types.ts)
- type `UiStatus` (types.ts)

## table

### UiTable (component, `ui-table`)
File: `table/src/table.ts`  
`ui-table` — accessible data table with click-to-sort headers and optional row selection. Pass `columns` + `data`; listen to `(selectionChange)`. (Virtual scroll / CDK table integration is a planned extension.)  
- Inputs: `columns`: UiColumn<T>[] = []; `data`: T[] = []; `selectable` = false; `actions`: UiRowAction<T>[] = []; `emptyText` = 'No data'; `radius`: boolean = this.config.radius
- Outputs: `selectionChange`: T[]
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiColumn` (table.ts)
- interface `UiRowAction` (table.ts)

## tabs

### UiTab (component, `ui-tab`)
File: `tabs/src/tabs.ts`  
`ui-tab` — a single tab + its panel. Provide a `label` and project the panel content. Inactive panels stay in the DOM but are hidden (`[hidden]`). An optional HugeIcons `icon` draws before the label. With `iconOnly` the label is not shown, but it is still the tab's accessible name and its tooltip, so a screen reader and a hovering mouse both get the words the icon stands for.  
- Inputs: `label`: string; `disabled` = false; `icon`: IconSvgObject | undefined = undefined; `iconOnly` = false
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiTabs (component, `ui-tabs`)
File: `tabs/src/tabs.ts`  
`ui-tabs` — WAI-ARIA tabs. Wraps `ui-tab` children; renders a tablist with roving tabindex and Arrow/Home/End keyboard navigation.  
- Inputs: `label`: string = 'Tabs'
- Two-way: `selectedIndex` = 0
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase


## text

### UiText (component, `ui-text`)
File: `text/src/text.ts`  
`ui-text` — the typography primitive and the ONLY text element in the library. Renders the correct semantic tag per variant (keeps a11y/SEO intact) and applies an optional `font` that falls back to the token. `as` overrides the tag while keeping the variant's look, e.g. a heading style on a `<p>` that stays out of the document outline, or an `h2` that looks like an `h4`. Styles are keyed on the variant class, not the tag. Projected content lives in a single `<ng-content>` (captured in the `#content` template) and is stamped into the chosen tag via `ngTemplateOutlet`. A naive "one `<ng-content>` per `@case`" template does NOT work — Angular only fills the last default slot, leaving every other variant empty.  
- Inputs: `variant`: TextVariant = 'body'; `as`: TextTag; `font`: string
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

- type `TextVariant` (text.ts)
- type `TextTag` (text.ts)

## theme

### UiThemeProvider (component, `ui-theme-provider`)
File: `theme/src/ui-theme-provider.ts`  
Scoped theme boundary. Wrap any subtree to override the theme for just that region — the token custom properties cascade to descendants. Uses `display: contents` so it never introduces layout of its own. <ui-theme-provider theme="light"> ... </ui-theme-provider>  
- Two-way: `theme`: UiTheme = 'dark'
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiThemeService (injectable)
File: `theme/src/ui-theme.service.ts`  
Global theme controller. Drives `data-theme` on the document root so the token overrides in `@zouriel/ui/styles/tokens.css` take effect app-wide. For scoped theming of a subtree, use {@link UiThemeProvider} instead.  
- Methods: `set(theme: UiTheme)`, `toggle()`
- [ ] Flutter port  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

- type `UiTheme` (ui-theme.service.ts)

## window

### UiDraggable (directive, `[uiDraggable]`)
File: `window/src/draggable.ts`  
`uiDraggable` — makes the host element draggable via pointer. Moves the host with a CSS transform and keeps a two-way `[(position)]`. Restrict the grab area with `uiDragHandle` (a child element). Reusable behavior directive.  
- Inputs: `uiDragHandle`: HTMLElement; `uiDraggableDisabled` = false
- Two-way: `position`: UiDragPosition
- Outputs: `dragStart`: UiDragEvent; `dragMove`: UiDragEvent; `dragEnd`: UiDragEvent
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- interface `UiDragPosition` (draggable.ts)
- interface `UiDragEvent` (draggable.ts)
### UiResizable (directive, `[uiResizable]`)
File: `window/src/resizable.ts`  
`uiResizable` — adds edge/corner resize handles (E, S, SE) to the host and resizes it in place. Emits `(resized)` with the new dimensions. The host should establish its own width/height (e.g. a sized box). Reusable behavior.  
- Inputs: `minWidth` = 80; `minHeight` = 48; `uiResizableDisabled` = false
- Outputs: `resized`: UiResizeEvent
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiResizeEdge` (resizable.ts)
- interface `UiResizeEvent` (resizable.ts)
### UiWindowManager (injectable)
File: `window/src/window-manager.ts`  
`UiWindowManager` — tracks open windows, focus order, and z-index stacking, and exposes bulk operations (minimize all, tile). Each `ui-window` registers itself on init.  
- Methods: `nextId()`, `register(handle: UiWindowHandle)`, `unregister(id: string)`, `bringToFront(id: string)`, `focus(id: string)`, `dock(id: string, side: UiDockSide)`, `minimizeAll()`, `restoreAll()`, `tile()`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

- type `UiDockSide` (window-manager.ts)
- interface `UiWindowBounds` (window-manager.ts)
- interface `UiWindowHandle` (window-manager.ts)
### UiWindow (component, `ui-window`)
File: `window/src/window.ts`  
`ui-window` — floating, draggable, resizable window shell ("a window inside the window"). Drag the title bar to move; drag near a screen edge to snap (left/right half, maximize). A drag always leaves at least 48px of the title bar on screen, so the window can be grabbed again. Resize from any edge/corner. Min/max/restore/ close chrome, focus-to-front z-index via {@link UiWindowManager}. Glass + radius + open animation. Hosts any content via `<ng-content>`. `[(open)]` controls whether it is on screen: Close sets it false (and emits `closed`), and the window unregisters from the manager until it is opened again.  
- Inputs: `title` = 'Window'; `draggable` = true; `resizable` = true; `glass`: boolean = this.config.glass; `radius`: boolean = this.config.radius; `initialX` = 80; `initialY` = 80; `initialWidth` = 440; `initialHeight` = 300
- Two-way: `open` = true
- Outputs: `closed`: void
- Methods: `dock(side: UiDockSide)`, `restore()`, `setBounds(b: UiWindowBounds)`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

## workflow

### UiWorkflowBuilder (component, `ui-workflow-builder`)
File: `workflow/src/workflow-builder.ts`  
Design automations and lifecycles; two-way definition, API, schema, settings, persist.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowPanel (component, `ui-workflow-panel`)
File: `workflow/src/panel.ts`  
A record's workflow as a vertical, horizontal or compact panel (the compact one replaces the removed record panel), or an edge drawer behind a rail of dots (hover peeks, tap opens; `[(open)]` is `open` + `onOpenChanged`). Record types with no lifecycle still show their manual workflows, tasks and history.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### WfRecordActions (component, `ui-wf-record-actions`)
File: `workflow/src/runtime.ts`  
A record's moves, manual workflows and tasks with their dialogs, used by the workflow panel (internal: not exported by the package).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### WfTaskInbox (component, `ui-wf-task-inbox`)
File: `workflow/src/runtime.ts`  
The approvals and tasks inside the tasks drawer, with the decide dialog (internal; was the public `UiWorkflowTasks` before 0.27.0).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### WfRunView (component, `ui-wf-run-view`)
File: `workflow/src/runtime.ts`  
One run over its workflow, with retry, skip (asking for the step's results, per stopped path) and cancel (confirmed, with remarks), shown in the workflow panel's Running section and the tasks drawer's Stopped workflows (internal; was the public `UiWorkflowRun` before 0.28.0).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowTasksDrawer (component, `ui-workflow-tasks-drawer`)
File: `workflow/src/tasks-drawer.ts`  
A "My tasks" button with the number open (red when one is overdue or a workflow stopped) that opens the tasks in a drawer, open or finished, each opening its decision; stopped workflows above them for people who may intervene. `[(open)]` is `open` + `onOpenChanged`; `scope: 'all'` lists everyone's tasks.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowPermissions (component, `ui-workflow-permissions`)
File: `workflow/src/permissions.ts`  
Who may make each move, start over, start each manual workflow and decide each task, edited on the published version and published as a new one; says what it did (records moved, draft steps skipped).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowAudit (component, `ui-workflow-audit`)
File: `workflow/src/runtime.ts`  
The audit log: filter, export, verify the chain.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowStateBadge (component, `ui-workflow-state-badge`)
File: `workflow/src/runtime.ts`  
A lifecycle state as a coloured chip.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowGlobalSettings (component, `ui-workflow-global-settings`)
File: `workflow/src/global-settings.ts`  
Working hours, defaults, channels, webhooks, audit, pausing.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiWorkflowHttpApi (class)
File: `workflow/src/api.ts`  
REST client for the engine (UiWorkflowApi).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiCanvasViewport (component, `ui-canvas-viewport`)
File: `canvas/src/viewport.ts`  
Pan/zoom surface with fit, minimap and zoom controls.  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [ ] showcase (used by the workflow page)

### UiFloatingPanel (component, `ui-floating-panel`) (0.34)
File: `layout/src/floating-panel.ts`  
`ui-floating-panel` — a non-modal raised card over the bottom or top of its positioned parent (over a map); safe-area aware, 16px gutter, up to 480px.  
- Inputs: `placement`: 'bottom' | 'top' = 'bottom'; `ariaLabel`; `glass` (0.41.2: the bottom sheet's see-through glass); `glassStrength` (0.41.3, as the sheet's); `radius`
- Outputs: `coverChange` (Flutter `onCoverChanged`, 0.39): px of the edge it covers
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiRowActions (component, `ui-row-actions`) (0.34)
File: `table/src/table.ts`  
`ui-row-actions` — a row's buttons space-2 apart at the end, wrapping when narrow.  
- Inputs: `align`: 'start' | 'end' = 'end'
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiHoldButton (component, `ui-hold-button`) (0.35)
File: `hold-button/src/hold-button.ts`  
Press and hold to confirm; a tap, quick Enter or assistive activation opens a confirm dialog.  
- Inputs: `hold` = 2000; `variant`; `size`: UiButtonSize; `block`; `disabled`; `ariaLabel`; `holdHint`; `confirmTitle`; `confirmMessage`; `confirmLabel`; `destructive`
- Outputs: `confirmed`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiProgressCircle (component, `ui-progress-circle`) (0.35 on the web)
File: `progress/src/progress-circle.ts`  
Round progress, determinate or turning; centre content slot (Flutter `child`).  
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiChatBubble (component, `ui-chat-bubble`) (0.35)
File: `chat-bubble/src/chat-bubble.ts`
A message: mine at the inline end in primary, theirs at the start on the raised surface; meta line.  
- Inputs: `mine` = false; `meta`; `ariaLabel`
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiMap (component, `ui-map`) (0.35)
File: `map/src/map.ts`  
OpenStreetMap map (Leaflet on the web, flutter_map here) with markers, a draggable pin, themed controls and dimmed dark tiles. Flutter: `package:zouriel_ui/map.dart`.  
- Inputs: `center`; `zoom`; `markers` (`semanticLabel` / web `ariaLabel`); `pin` (model); `pinMode`; `pinLabel`; `pinDraggable`; `pulse` (UiMapPulse, 0.39); `insets` (Flutter `viewInsets`, 0.39); `fill` (0.39); `tileUrl`; `tileUrlDark` (0.40); `tileSize` / `zoomOffset` (0.40); `locateControl` / `locating` / `locateOff` (0.40); `userLocation` (UiMapUserLocation, 0.40); `routes` (UiMapRoute, 0.42); `tileHeaders` (Flutter) / `tileReferrerPolicy` (web); `attribution`; `semanticLabel` (web `ariaLabel`); `tileProvider` (Flutter, including `UiMapBlankTiles` for tests)
- Outputs: `markerSelected`; `centerChanged`; `onPinChanged` (Flutter / web `pin` model); `locate` (Flutter `onLocate`, 0.40)
- Methods: `flyTo(point, zoom?)` (Flutter `UiMapState.flyTo`, 0.40); `fitPoints(points, { padding, maxZoom, animate })` (Flutter `UiMapState.fitPoints`, 0.42)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiGoogleButton (component, `ui-google-button`) (0.36)
File: `google-sign-in/src/google-button.ts` (entry point `@zouriel/ui/google-sign-in`)  
"Sign in with Google" drawn to Google's branding guidelines (official G, light/dark/neutral, rectangular/pill, 40 high). Flutter: `UiGoogleSignInButton`, paired with the `google_sign_in` package by the app.  
- Inputs: `text` (signIn | signUp | continueWith | signInShort); `theme` (auto | light | dark | neutral); `shape` (rectangular | pill); `loading`; `expand`; `disabled` (Flutter: `onPressed` null); `ariaLabel` (Flutter `semanticLabel`)
- Outputs: `pressed` (Flutter `onPressed`)
- [x] Flutter port  - [x] widget tests  - [x] golden/visual check  - [x] showcase

### UiGoogleSignIn (component, `ui-google-sign-in`) (0.36, web only)
File: `google-sign-in/src/google-sign-in.ts`  
Wraps Google Identity Services' own rendered button and emits the ID token (`credential`). Web only: on the web GIS is the only secret-free way to get an ID token; a Flutter app gets it from `google_sign_in` (`authenticate()` → `idToken`, `serverClientId` = the web client ID) behind `UiGoogleSignInButton`.  
- Inputs: `clientId`; `text`; `theme`; `shape`; `width`; `locale`; `nonce`
- Outputs: `credential`; `failed`
- [ ] Flutter port (not applicable: native sign-in comes from the google_sign_in plugin)  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase

### UiGoogleAuthorization (service, `@zouriel/ui/google-sign-in`) (0.37, web only)
File: `google-sign-in/src/google-authorization.ts`  
Asks the signed-in user for more Google scopes through Google Identity Services' token client (`google.accounts.oauth2.initTokenClient`, popup) and returns `{ accessToken, grantedScopes, expiresIn }`; rejects with `UiGoogleAuthorizationError` (`cancelled` | `popup_blocked` | `unavailable` | `failed`). Web only: a Flutter app asks for scopes with the `google_sign_in` package's `authorizationClient` (`authorizeScopes` / `authorizationForScopes`), which needs no library widget.  
- Methods: `requestAccessToken({ clientId, scopes, hint?, prompt? })`; `preload()`
- [ ] Flutter port (not applicable: scopes come from the google_sign_in plugin's authorizationClient)  - [ ] widget tests  - [ ] golden/visual check  - [ ] showcase
