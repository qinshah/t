import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ghostty_dart/ghostty_dart.dart' show VtCursorStyle;
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

import '../../settings/models/setting.dart';
import '../services/terminal_session.dart';

/// 终端面板：`VtTerminalView` 的薄封装。
///
/// 只按会话绑定控制器与焦点节点，不感知会话背后是本地 PTY 还是远程连接。
///
/// 字号由调用方传入，面板自身负责把 Ctrl 快捷键、Ctrl + 滚轮与双指
/// 缩放翻译成 [onFontSizeChanged] 回调；具体取值与持久化交给设置层。
class TerminalPanel extends StatefulWidget {
  /// 创建一个绑定到 [session] 的终端面板。
  ///
  /// 光标默认使用竖向条并带 160ms 缓动；调用方可以按标签覆盖样式与时长。
  const TerminalPanel({
    super.key,
    required this.session,
    this.fontSize = defaultTerminalFontSize,
    this.onFontSizeChanged,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.cursorStyle = VtCursorStyle.bar,
    this.cursorGlide = true,
    this.cursorGlideDuration = const Duration(milliseconds: 160),
    this.barCursorThicknessFraction = 1 / 5,
  });

  /// 面板要渲染的终端会话。
  final ITerminalSession session;

  /// 终端字号（逻辑像素）。
  final int fontSize;

  /// 手势缩放得到的目标字号；由调用方夹到允许范围并持久化。
  final ValueChanged<int>? onFontSizeChanged;

  /// Ctrl + `=` / 数字键盘 `+`：放大一级。
  final VoidCallback? onZoomIn;

  /// Ctrl + `-` / 数字键盘 `-`：缩小一级。
  final VoidCallback? onZoomOut;

  /// Ctrl + `0`：恢复默认字号。
  final VoidCallback? onZoomReset;

  /// 覆盖程序通过 DECSCUSR 请求的光标形状。
  final VtCursorStyle? cursorStyle;

  /// 光标跨单元格移动时是否缓动。
  final bool cursorGlide;

  /// 光标缓动时长；`Duration.zero` 表示直接跳转。
  final Duration cursorGlideDuration;

  /// 条状光标的宽度占单元格宽度的比例；上游默认 1/8，这里默认更粗的 1/5。
  final double barCursorThicknessFraction;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  /// Ctrl + 滚轮每累计多少逻辑像素缩放一级。
  ///
  /// 精确触控板一次手势会拆成很多个很小的 delta，按阈值累计可以避免
  /// 一下跳出好几级；普通鼠标滚轮一格通常就超过这个值。
  static const double _wheelPixelsPerStep = 40;

  /// 已在本次滚轮手势中累计的像素（向上为正）。
  double _wheelPixels = 0;

  /// Ctrl + 滚轮累计值的方向；换方向时先清零，反向调整才跟手。
  double _wheelDirection = 0;

  /// 按住 Ctrl 时忽略终端的指针事件，让滚轮只缩放、不滚动回看缓冲。
  bool _zoomModifierDown = false;

  /// 正在按下的触点位置；只在恰好两个触点时用于计算缩放比例。
  final Map<int, Offset> _touchPoints = <int, Offset>{};

  /// 双指缩放开始时的触点距离与字号。
  double? _pinchStartDistance;
  int? _pinchStartFontSize;

  /// 触控板缩放开始时的字号；`PointerPanZoom` 的 scale 是累计值。
  int? _panZoomStartFontSize;

  bool get _zoomModifierPressed => HardwareKeyboard.instance.isControlPressed;

  @override
  void initState() {
    super.initState();
    _zoomModifierDown = _zoomModifierPressed;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  /// 跟随 Ctrl 的按下/抬起来切换指针拦截。
  ///
  /// 返回 `false` 表示不消费事件，键盘输入照常交给终端。
  bool _onHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    final down = _zoomModifierPressed;
    if (down != _zoomModifierDown) {
      setState(() => _zoomModifierDown = down);
    }
    return false;
  }

  /// 终端键盘预处理：Ctrl + `0` / `-` / `=` 只在应用内缩放，不发给 Shell。
  KeyEventResult _onTerminalKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (!HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.numpadAdd:
        widget.onZoomIn?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        widget.onZoomOut?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        widget.onZoomReset?.call();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Ctrl + 滚轮按累计像素缩放；没有 Ctrl 时交给终端自己滚动。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // 有些平台把 Shift+滚轮转成横向滚动，两个方向都接受。
    final delta = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    _applyWheelDelta(delta);
  }

  /// 把滚轮/触控板滚动的像素换算成缩放级数。
  ///
  /// 未按住 Ctrl 时只清空累计值，滚动仍由终端处理。
  void _applyWheelDelta(double scrollDelta) {
    if (!_zoomModifierDown) {
      _wheelPixels = 0;
      _wheelDirection = 0;
      return;
    }
    if (scrollDelta == 0) return;

    // 向上滚动（delta 为负）放大，与终端习惯一致。
    final delta = -scrollDelta;
    final direction = delta.sign;
    if (direction != _wheelDirection) {
      _wheelDirection = direction;
      _wheelPixels = 0;
    }
    _wheelPixels += delta;
    while (_wheelPixels >= _wheelPixelsPerStep) {
      _wheelPixels -= _wheelPixelsPerStep;
      widget.onZoomIn?.call();
    }
    while (_wheelPixels <= -_wheelPixelsPerStep) {
      _wheelPixels += _wheelPixelsPerStep;
      widget.onZoomOut?.call();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _touchPoints[event.pointer] = event.localPosition;
    _startPinchIfReady();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_touchPoints.containsKey(event.pointer)) return;
    _touchPoints[event.pointer] = event.localPosition;
    final startDistance = _pinchStartDistance;
    final startFontSize = _pinchStartFontSize;
    if (_touchPoints.length != 2 ||
        startDistance == null ||
        startFontSize == null ||
        startDistance <= 0) {
      return;
    }
    final scale = _distanceBetweenTouchPoints() / startDistance;
    if ((scale - 1).abs() < 0.02) return;
    _applyScale(startFontSize, scale);
  }

  void _onPointerEnd(PointerEvent event) {
    _touchPoints.remove(event.pointer);
    _startPinchIfReady();
  }

  /// 触点数量回到 2 个时重新建立基准，否则清掉基准避免误缩放。
  void _startPinchIfReady() {
    if (_touchPoints.length == 2) {
      _pinchStartDistance = _distanceBetweenTouchPoints();
      _pinchStartFontSize = widget.fontSize;
    } else {
      _pinchStartDistance = null;
      _pinchStartFontSize = null;
    }
  }

  double _distanceBetweenTouchPoints() {
    final points = _touchPoints.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  /// 触控板捏合（macOS）走 PointerPanZoom；`scale` 是从手势开始的累计值。
  ///
  /// 同一个事件流里，双指滚动只有 [PointerPanZoomUpdateEvent.panDelta]，
  /// 捏合才改 `scale`。按住 Ctrl 时把滚动也当作缩放输入。
  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _panZoomStartFontSize = widget.fontSize;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if ((event.scale - 1).abs() >= 0.01) {
      final startFontSize = _panZoomStartFontSize;
      if (startFontSize != null) _applyScale(startFontSize, event.scale);
      return;
    }
    if (!_zoomModifierDown) return;
    final delta = event.localPanDelta.dy != 0
        ? event.localPanDelta.dy
        : event.localPanDelta.dx;
    _applyWheelDelta(delta);
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomStartFontSize = null;
  }

  /// 把「起始字号 × 缩放比例」吸附到整数级并限制在 4–64。
  void _applyScale(int startFontSize, double scale) {
    final target = (startFontSize * scale)
        .round()
        .clamp(minTerminalFontSize, maxTerminalFontSize)
        .toInt();
    if (target == widget.fontSize) return;
    widget.onFontSizeChanged?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.session.controller;
    // 配色可以在运行中切换，底色也要跟着控制器一起重建。
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Listener(
          // 子组件被忽略时仍要收到 Ctrl + 滚轮，因此这里使用 opaque。
          behavior: HitTestBehavior.opaque,
          onPointerSignal: _onPointerSignal,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: _onPanZoomUpdate,
          onPointerPanZoomEnd: _onPanZoomEnd,
          child: IgnorePointer(
            // 按住 Ctrl 时阻止终端收到滚轮：只缩放，不滚动回看缓冲。
            ignoring: _zoomModifierDown,
            child: ColoredBox(
              // 与终端自身的背景一致，避免首帧前闪一下 Scaffold 的底色。
              color: controller.theme.background,
              child: VtTerminalView(
                controller: controller,
                focusNode: widget.session.focusNode,
                // 所有标签常驻 widget 树（IndexedStack 保活），焦点只能由
                // provider 在切换标签时显式授予，否则多个终端会争夺初始焦点。
                autofocus: false,
                textStyle: TextStyle(fontSize: widget.fontSize.toDouble()),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                cursorStyle: widget.cursorStyle,
                cursorGlide: widget.cursorGlide,
                cursorGlideDuration: widget.cursorGlideDuration,
                barCursorThicknessFraction: widget.barCursorThicknessFraction,
                onKeyEvent: _onTerminalKey,
              ),
            ),
          ),
        );
      },
    );
  }
}
