import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/link_scope.dart';
import '../forms/text/text_core.dart';
import '../forms/text/text_dir.dart';
import '../theme/theme.dart';

/// How [UiChatWidget] renders its launcher: expanding pill, corner button, or draggable head.
enum UiChatLauncher { hover, floating, draggable }

/// Which horizontal side [UiChatWidget] docks to (logical: mirrors in RTL).
enum UiChatPosition { start, end }

/// One quick-reply chip in [UiChatActions].
class UiChatAction {
  const UiChatAction({required this.id, required this.label});
  final String id;
  final String label;
}

/// `ui-chat-actions`: wrapping row of quick-reply chips.
class UiChatActions extends StatelessWidget {
  const UiChatActions({
    super.key,
    this.actions = const [],
    this.disabled = false,
    this.onPick,
  });

  final List<UiChatAction> actions;
  final bool disabled;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Wrap(
      spacing: t.space2,
      runSpacing: t.space2,
      children: [
        for (final action in actions)
          UiInteractive(
            onTap: disabled ? null : () => onPick?.call(action.id),
            enabled: !disabled,
            semanticLabel: action.label,
            builder: (context, s) {
              final bg = s.hovered && !disabled
                  ? Color.lerp(t.surface, t.primary, 0.08)!
                  : t.surface;
              final border = s.hovered && !disabled
                  ? t.primary
                  : Color.lerp(t.border, t.primary, 0.45)!;
              return Opacity(
                opacity: disabled ? 0.5 : 1,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(t.radiusPill),
                    boxShadow: s.focused ? t.focusRing : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.label,
                        style: context.uiText.body.copyWith(
                          fontSize: t.fontSizeSm,
                          color: t.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// `ui-chat-typing`: three-dot typing indicator shaped like an incoming bubble, with a live region.
class UiChatTyping extends StatefulWidget {
  const UiChatTyping({super.key, this.label = 'Assistant is typing'});

  final String label;

  @override
  State<UiChatTyping> createState() => _UiChatTypingState();
}

class _UiChatTypingState extends State<UiChatTyping> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.uiAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final theme = context.uiTheme;
    final big = theme.radius(t.radiusLg);
    final small = theme.radius(t.radiusXs);
    final animate = context.uiAnimate;
    return Semantics(
      liveRegion: true,
      label: widget.label,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border.all(color: t.border),
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(big),
              topEnd: Radius.circular(big),
              bottomStart: Radius.circular(small),
              bottomEnd: Radius.circular(big),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  for (var i = 0; i < 3; i++) _dot(t, animate, i),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dot(UiTokens t, bool animate, int index) {
    double opacity = 0.6;
    double dy = 0;
    if (animate) {
      final phase = ((_controller.value - index * 0.125) % 1.0 + 1.0) % 1.0;
      if (phase < 0.6) {
        final wave = math.sin(phase / 0.6 * math.pi);
        opacity = 0.3 + 0.7 * wave;
        dy = -3.0 * wave;
      } else {
        opacity = 0.3;
      }
    }
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// `ui-chat-source`: a small citation chip/link to place inside or under an assistant bubble.
class UiChatSource extends StatelessWidget {
  const UiChatSource({super.key, required this.label, this.href, this.onTap});

  final String label;
  final String? href;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final interactive = onTap != null || href != null;
    final tap = onTap ?? (href != null ? () => UiLinkScope.maybeOf(context)?.navigate(href!) : null);

    Widget chip(bool hovered, bool focused) => Container(
          padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: hovered ? t.borderStrong : t.border),
            borderRadius: BorderRadius.circular(t.radiusPill),
            boxShadow: focused ? t.focusRing : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              UiIcon(HugeIcons.strokeRoundedLink01, size: 13, color: hovered ? t.text : t.textSecondary),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.body.copyWith(
                    fontSize: 12,
                    color: hovered ? t.text : t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );

    if (!interactive) {
      return Semantics(label: label, child: chip(false, false));
    }

    return UiInteractive(
      onTap: tap,
      link: href != null && onTap == null,
      semanticLabel: label,
      minTouchSize: Size.zero,
      builder: (context, s) => chip(s.hovered, s.focused),
    );
  }
}

/// `ui-chat-composer`: multiline auto-growing input (Enter sends, Shift+Enter newline) with
/// optional attach button and round 44px send button.
class UiChatComposer extends StatefulWidget {
  const UiChatComposer({
    super.key,
    this.attach = false,
    this.disabled = false,
    this.busy = false,
    this.placeholder = 'Ask a question…',
    this.inputLabel = 'Message',
    this.attachLabel = 'Attach a document',
    this.sendLabel = 'Send',
    this.onSend,
    this.onAttach,
  });

  final bool attach;
  final bool disabled;
  final bool busy;
  final String placeholder;
  final String inputLabel;
  final String attachLabel;
  final String sendLabel;
  final ValueChanged<String>? onSend;
  final VoidCallback? onAttach;

  @override
  State<UiChatComposer> createState() => _UiChatComposerState();
}

class _UiChatComposerState extends State<UiChatComposer> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'chat composer',
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
        final shift = HardwareKeyboard.instance.isShiftPressed;
        if (!shift) {
          _submit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _controller.removeListener(_onText);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  void _onText() {
    final next = _controller.text.trim().isNotEmpty;
    if (next != _hasText && mounted) setState(() => _hasText = next);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.disabled || widget.busy) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final inactive = widget.disabled || widget.busy;
    final canSend = !inactive && _hasText;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 20 / 15, color: t.text);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          if (widget.attach)
            UiInteractive(
              onTap: inactive ? null : widget.onAttach,
              enabled: !inactive,
              semanticLabel: widget.attachLabel,
              builder: (context, s) => Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.hovered && !inactive ? t.surfaceHover : null,
                  shape: BoxShape.circle,
                ),
                child: UiIcon(
                  HugeIcons.strokeRoundedAttachment01,
                  size: 22,
                  color: inactive ? t.textDisabled : t.icon,
                ),
              ),
            ),
          Expanded(
            child: UiFieldFrame(
              focused: _focused,
              enabled: !inactive,
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Semantics(
                label: widget.inputLabel,
                textField: true,
                multiline: true,
                child: UiFieldDirection(
                  dir: UiTextDir.auto,
                  controller: _controller,
                  child: Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      if (_controller.text.isEmpty)
                        IgnorePointer(
                          child: Text(
                            widget.placeholder,
                            style: style.copyWith(color: t.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      EditableText(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: style,
                        cursorColor: t.primary,
                        backgroundCursorColor: t.surface,
                        maxLines: 5,
                        minLines: 1,
                        readOnly: inactive,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          UiInteractive(
            onTap: canSend ? _submit : null,
            enabled: canSend,
            semanticLabel: widget.sendLabel,
            builder: (context, s) => Transform.scale(
              scaleX: isRtl ? -1 : 1,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canSend ? t.primary : t.surfaceSubtle,
                  shape: BoxShape.circle,
                  boxShadow: s.focused ? t.focusRing : null,
                ),
                child: UiIcon(
                  HugeIcons.strokeRoundedSent,
                  size: 22,
                  color: canSend ? t.primaryContrast : t.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `ui-chat-widget`: corner launcher (floating, hover pill, or draggable head) that opens a chat
/// panel with header, optional notice line, auto-scrolling message log, quick-actions slot, and
/// composer footer slot.
class UiChatWidget extends StatefulWidget {
  const UiChatWidget({
    super.key,
    required this.child,
    this.open = false,
    this.onOpenChanged,
    this.position = UiChatPosition.end,
    this.unread = 0,
    this.title = 'Assistant',
    this.subtitle,
    this.notice,
    this.launcherLabel = 'Open the assistant',
    this.closeLabel = 'Close the assistant',
    this.launcher = UiChatLauncher.floating,
    this.label = 'Ask the Assistant',
    this.hint = 'Questions, or help with an application',
    this.teaser,
    this.avatar,
    this.headerActions,
    this.quickActions,
    this.footer,
    this.onDismissed,
    this.onTeaserDismissed,
    this.onPositionChanged,
  });

  final Widget child;
  final bool open;
  final ValueChanged<bool>? onOpenChanged;
  final UiChatPosition position;
  final int unread;
  final String title;
  final String? subtitle;
  final String? notice;
  final String launcherLabel;
  final String closeLabel;
  final UiChatLauncher launcher;
  final String label;
  final String hint;
  final String? teaser;
  final Widget? avatar;
  final Widget? headerActions;
  final Widget? quickActions;
  final Widget? footer;
  final VoidCallback? onDismissed;
  final VoidCallback? onTeaserDismissed;
  final ValueChanged<Offset>? onPositionChanged;

  @override
  State<UiChatWidget> createState() => _UiChatWidgetState();
}

class _UiChatWidgetState extends State<UiChatWidget> {
  bool _teaserGone = false;
  bool _hidden = false;
  bool _dragging = false;
  Offset? _headOffset;
  final ScrollController _scroll = ScrollController();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'chat panel');
  final FocusNode _launcherFocus = FocusNode(debugLabel: 'chat launcher');

  @override
  void didUpdateWidget(UiChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _panelFocus.requestFocus();
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _launcherFocus.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _panelFocus.dispose();
    _launcherFocus.dispose();
    super.dispose();
  }

  Offset _resolvedHead(Size screen) {
    if (_headOffset != null) return _headOffset!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final onStart = widget.position == UiChatPosition.start;
    final onLeft = isRtl ? !onStart : onStart;
    final x = onLeft ? 16.0 : math.max(16.0, screen.width - 80);
    final y = math.max(16.0, screen.height - 80);
    return Offset(x, y);
  }

  void _setOpen(bool v) => widget.onOpenChanged?.call(v);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final isPhone = screen.width <= 600;
    final t = context.ui;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final atStart = widget.position == UiChatPosition.start;

    if (widget.open && isPhone) {
      return Positioned.fill(
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false)},
          child: _buildPanel(context, t, fullScreen: true, safePadding: media.padding),
        ),
      );
    }

    if (widget.launcher == UiChatLauncher.draggable) {
      final head = _resolvedHead(screen);
      final headOnLeft = head.dx + 32 < screen.width / 2;
      return Positioned.fill(
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false)},
          child: Stack(
            children: [
              if (widget.open)
                Positioned(
                  left: headOnLeft ? head.dx + 76 : null,
                  right: headOnLeft ? null : screen.width - head.dx + 12,
                  bottom: math.max(16.0, screen.height - head.dy - 64),
                  child: _buildPanel(context, t, fullScreen: false, safePadding: EdgeInsets.zero),
                ),
              if (!_hidden)
                AnimatedPositioned(
                  duration: _dragging || !context.uiAnimate ? Duration.zero : t.motionBase,
                  curve: t.easeDecelerate,
                  left: head.dx,
                  top: head.dy,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _dragging = true),
                    onPanUpdate: (d) {
                      final cur = _resolvedHead(screen);
                      setState(() {
                        _headOffset = Offset(
                          (cur.dx + d.delta.dx).clamp(8.0, math.max(8.0, screen.width - 72)),
                          (cur.dy + d.delta.dy).clamp(8.0, math.max(8.0, screen.height - 72)),
                        );
                      });
                    },
                    onPanEnd: (d) {
                      final cur = _resolvedHead(screen);
                      final dropCenter = Offset(screen.width / 2, screen.height - 56);
                      final headCenter = cur + const Offset(32, 32);
                      if ((headCenter - dropCenter).distance < 56) {
                        setState(() {
                          _dragging = false;
                          _hidden = true;
                        });
                        widget.onDismissed?.call();
                        return;
                      }
                      final vx = d.velocity.pixelsPerSecond.dx;
                      final rightEdge = math.max(16.0, screen.width - 80);
                      final x = vx.abs() > 300
                          ? (vx < 0 ? 16.0 : rightEdge)
                          : (headCenter.dx < screen.width / 2 ? 16.0 : rightEdge);
                      final y = cur.dy.clamp(16.0, math.max(16.0, screen.height - 80)).toDouble();
                      final snapped = Offset(x, y);
                      setState(() {
                        _dragging = false;
                        _headOffset = snapped;
                      });
                      widget.onPositionChanged?.call(snapped);
                    },
                    child: _buildLauncher(context, t),
                  ),
                ),
              if (_dragging)
                Positioned(
                  bottom: 28 + media.padding.bottom,
                  left: screen.width / 2 - 28,
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.danger.withValues(alpha: 0.14),
                      border: Border.all(color: t.danger),
                      shape: BoxShape.circle,
                    ),
                    child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 22, color: t.danger),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final alignEnd = atStart ? (isRtl ? Alignment.bottomRight : Alignment.bottomLeft) : (isRtl ? Alignment.bottomLeft : Alignment.bottomRight);
    final crossAlign = atStart ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false)},
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.space6 + media.padding.left,
            t.space6 + media.padding.top,
            t.space6 + media.padding.right,
            t.space6 + media.padding.bottom,
          ),
          child: Align(
            alignment: alignEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAlign,
              spacing: t.space3,
              children: [
                if (widget.open) _buildPanel(context, t, fullScreen: false, safePadding: EdgeInsets.zero),
                if (widget.teaser != null &&
                    widget.teaser!.isNotEmpty &&
                    widget.launcher == UiChatLauncher.floating &&
                    !widget.open &&
                    !_teaserGone)
                  _buildTeaser(context, t),
                if (!_hidden) _buildLauncher(context, t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeaser(BuildContext context, UiTokens t) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: EdgeInsets.all(t.space3),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(t.radiusLg),
          boxShadow: t.shadow2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space2,
          children: [
            Flexible(
              child: Text(widget.teaser!, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm)),
            ),
            UiInteractive(
              onTap: () {
                setState(() => _teaserGone = true);
                widget.onTeaserDismissed?.call();
              },
              semanticLabel: 'Dismiss',
              minTouchSize: const Size(28, 28),
              builder: (context, s) => SizedBox(
                width: 28,
                height: 28,
                child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 16, color: t.icon)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLauncher(BuildContext context, UiTokens t) {
    if (widget.launcher == UiChatLauncher.hover) {
      return UiInteractive(
        focusNode: _launcherFocus,
        onTap: () => _setOpen(!widget.open),
        semanticLabel: widget.launcherLabel,
        builder: (context, s) {
          final expanded = s.hovered || s.focused;
          return AnimatedContainer(
            duration: context.uiAnimate ? t.motionBase : Duration.zero,
            curve: t.easeStandard,
            height: 64,
            padding: EdgeInsetsDirectional.fromSTEB(17, 0, expanded ? 22 : 17, 0),
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [...(expanded ? t.shadow3 : t.shadow2), if (s.focused) ...t.focusRing],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: expanded ? t.space3 : 0,
              children: [
                UiIcon(
                  widget.open ? HugeIcons.strokeRoundedArrowDown01 : HugeIcons.strokeRoundedSparkles,
                  size: 30,
                  color: t.primaryContrast,
                ),
                if (expanded)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: context.uiText.label.copyWith(fontSize: t.fontSizeMd, color: t.primaryContrast),
                      ),
                      Text(
                        widget.hint,
                        style: context.uiText.body.copyWith(
                          fontSize: 12,
                          color: t.primaryContrast.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    return UiInteractive(
      focusNode: _launcherFocus,
      onTap: () => _setOpen(!widget.open),
      semanticLabel: widget.launcherLabel,
      builder: (context, s) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primary,
              shape: BoxShape.circle,
              boxShadow: [...(s.hovered ? t.shadow3 : t.shadow2), if (s.focused) ...t.focusRing],
            ),
            child: UiIcon(
              widget.open ? HugeIcons.strokeRoundedArrowDown01 : HugeIcons.strokeRoundedAiChat02,
              size: widget.open ? 30 : 32,
              color: t.primaryContrast,
            ),
          ),
          if (widget.unread > 0 && !widget.open)
            PositionedDirectional(
              top: -3,
              end: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(color: t.surface, width: 2),
                ),
                child: Text(
                  widget.unread > 99 ? '99+' : '${widget.unread}',
                  style: context.uiText.label.copyWith(fontSize: 11, color: t.accentContrast),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, UiTokens t, {required bool fullScreen, required EdgeInsets safePadding}) {
    final screen = MediaQuery.sizeOf(context);
    return Focus(
      focusNode: _panelFocus,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        label: widget.title,
        child: Container(
          width: fullScreen ? screen.width : 380,
          height: fullScreen ? screen.height : math.min(600, math.max(240, screen.height - 140)),
          decoration: BoxDecoration(
            color: t.surface,
            border: fullScreen ? null : Border.all(color: t.border),
            borderRadius: fullScreen ? BorderRadius.zero : BorderRadius.circular(t.radiusLg),
            boxShadow: fullScreen ? null : t.shadow3,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  t.space3,
                  14 + (fullScreen ? safePadding.top : 0),
                  t.space3,
                  14,
                ),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
                child: Row(
                  spacing: t.space3,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                      child: widget.avatar ??
                          UiIcon(HugeIcons.strokeRoundedSparkles, size: 26, color: t.primaryContrast),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: context.uiText.label.copyWith(fontSize: 16 * t.fontScale, color: t.text),
                            ),
                          ),
                          if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                            Text(
                              widget.subtitle!,
                              style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted),
                            ),
                        ],
                      ),
                    ),
                    if (widget.headerActions != null) widget.headerActions!,
                    UiInteractive(
                      onTap: () => _setOpen(false),
                      semanticLabel: widget.closeLabel,
                      builder: (context, s) => Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.hovered ? t.surfaceHover : null,
                          shape: BoxShape.circle,
                          boxShadow: s.focused ? t.focusRing : null,
                        ),
                        child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 20, color: t.icon),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.notice != null && widget.notice!.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space2),
                  decoration: BoxDecoration(
                    color: t.surfaceSubtle,
                    border: Border(bottom: BorderSide(color: t.borderSubtle)),
                  ),
                  child: Row(
                    spacing: t.space2,
                    children: [
                      UiIcon(HugeIcons.strokeRoundedInformationCircle, size: 15, color: t.info),
                      Expanded(
                        child: Text(
                          widget.notice!,
                          style: context.uiText.body.copyWith(fontSize: 12.5, color: t.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.all(t.space4),
                  child: widget.child,
                ),
              ),
              if (widget.quickActions != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(t.space4, 0, t.space4, t.space3),
                  child: widget.quickActions!,
                ),
              if (widget.footer != null)
                Padding(
                  padding: EdgeInsets.only(bottom: fullScreen ? safePadding.bottom : 0),
                  child: widget.footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
