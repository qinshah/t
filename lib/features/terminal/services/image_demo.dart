import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

/// 图片演示的帧数与尺寸。
///
/// 帧以 RGBA 原始字节传输（`f=32`），单帧 400×225×4 ≈ 360 KB，
/// 18 帧约 6.3 MB，默认的 10 MB 单屏存储上限放得下。
const int _frameCount = 18;
const int _frameWidth = 400;
const int _frameHeight = 225;
const int _frameGapMs = 55;

/// 图片在终端里占用的列数与行数。
const int _displayCols = 48;
const int _displayRows = 13;

/// Kitty 图形协议里的图片 ID。
const int _imageId = 1;

/// 生成一段可直接写入终端的 Kitty 动画序列。
///
/// 先用 [ui.PictureRecorder] 在离屏画布上渲染 [_frameCount] 帧，再把首帧
/// 作为图片、其余帧作为动画帧传输，最后让终端循环播放。整个过程不依赖
/// 系统图片工具，任何能跑 Flutter 的平台都能用。
Future<String> buildImageDemoSequence() async {
  final out = StringBuffer();

  for (var i = 0; i < _frameCount; i++) {
    final image = await _renderFrame(i);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) {
      throw StateError('第 $i 帧无法读取像素');
    }

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final keys = i == 0
        ? 'a=T,i=$_imageId,f=32,s=$_frameWidth,v=$_frameHeight,'
              'c=$_displayCols,r=$_displayRows,q=2'
        : 'a=f,i=$_imageId,f=32,s=$_frameWidth,v=$_frameHeight,'
              'z=$_frameGapMs,q=2';
    _writeKitty(out, keys, base64Encode(bytes));

    // 每帧之间让出事件循环，避免一次生成长时间占住 UI 线程。
    await Future<void>.delayed(Duration.zero);
  }

  // s=3 开始播放，v=0 表示无限循环。
  out.write('\x1b_Ga=a,i=$_imageId,s=3,v=0,q=2\x1b\\');
  return out.toString();
}

/// 把图片动画插入一个真实终端。
///
/// 只是往终端的输出流里写数据，不影响 PTY 和 Shell：插入后光标被移到
/// 图片下方，终端可以继续输入、输出和滚动。
Future<void> playImageDemo(VtTerminalController controller) async {
  final sequence = await buildImageDemoSequence();
  // 生成帧期间 Shell 通常已经打印完提示符，再留一点余量。
  await Future<void>.delayed(const Duration(milliseconds: 200));
  controller.write('\r\n$sequence${'\r\n' * _displayRows}');
}

/// 按 Kitty 协议分块写入一条传输指令（单块上限 4096 字节）。
void _writeKitty(StringBuffer out, String keys, String payload) {
  const chunkSize = 4096;
  if (payload.length <= chunkSize) {
    out.write('\x1b_G$keys;$payload\x1b\\');
    return;
  }

  var offset = 0;
  var first = true;
  while (offset < payload.length) {
    final end = math.min(offset + chunkSize, payload.length);
    final more = end < payload.length ? 'm=1' : 'm=0';
    final control = first ? '$keys,$more' : more;
    out.write('\x1b_G$control;${payload.substring(offset, end)}\x1b\\');
    first = false;
    offset = end;
  }
}

/// 渲染第 [index] 帧：流动的背景、旋转圆环与轨道圆点。
Future<ui.Image> _renderFrame(int index) async {
  final t = index / _frameCount;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final width = _frameWidth.toDouble();
  final height = _frameHeight.toDouble();
  final rect = ui.Rect.fromLTWH(0, 0, width, height);
  final center = ui.Offset(width / 2, height / 2);

  // 深色底 + 一条随时间横移的渐变光带。
  canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF0B0F14));
  canvas.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(-width + t * width * 3, 0),
        ui.Offset(t * width * 3, height),
        const [ui.Color(0x002DD4BF), ui.Color(0xFF2DD4BF), ui.Color(0x006366F1)],
        const [0.0, 0.55, 1.0],
      ),
  );

  // 中心旋转的圆环。
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(t * 2 * math.pi);
  canvas.drawArc(
    ui.Rect.fromCircle(center: ui.Offset.zero, radius: 54),
    0,
    math.pi * 1.35,
    false,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = ui.StrokeCap.round
      ..color = const ui.Color(0xFFE6FFFA),
  );
  canvas.restore();

  // 三颗环绕的圆点。
  const dotColors = [
    ui.Color(0xFF2DD4BF),
    ui.Color(0xFF6366F1),
    ui.Color(0xFFF472B6),
  ];
  for (var i = 0; i < dotColors.length; i++) {
    final phase = t * 2 * math.pi + i * 2 * math.pi / dotColors.length;
    canvas.drawCircle(
      ui.Offset(
        center.dx + math.cos(phase) * 82,
        center.dy + math.sin(phase) * 82,
      ),
      7,
      ui.Paint()..color = dotColors[i],
    );
  }

  _drawCenteredText(
    canvas,
    't',
    y: 66,
    fontSize: 64,
    weight: ui.FontWeight.w700,
  );
  _drawCenteredText(
    canvas,
    'Kitty graphics · animation',
    y: height - 46,
    fontSize: 14,
    color: const ui.Color(0xCCFFFFFF),
  );

  final picture = recorder.endRecording();
  try {
    return await picture.toImage(_frameWidth, _frameHeight);
  } finally {
    picture.dispose();
  }
}

/// 在整帧宽度内居中绘制一行文本。
void _drawCenteredText(
  ui.Canvas canvas,
  String text, {
  required double y,
  required double fontSize,
  ui.FontWeight weight = ui.FontWeight.normal,
  ui.Color color = const ui.Color(0xFFFFFFFF),
}) {
  final paragraph =
      (ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontSize: fontSize,
              fontWeight: weight,
            ),
          )..pushStyle(ui.TextStyle(color: color))..addText(text))
          .build()
        ..layout(ui.ParagraphConstraints(width: _frameWidth.toDouble()));
  canvas.drawParagraph(paragraph, ui.Offset(0, y));
}
