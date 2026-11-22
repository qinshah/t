import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostty_dart/ghostty_dart.dart';
import 'package:t/features/terminal/services/image_demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('图片演示序列能被终端解析为图片动画', (tester) async {
    final sequence = await tester.runAsync(buildImageDemoSequence);
    expect(sequence, isNotNull);
    // 最后一帧传输完开始循环播放。
    expect(sequence, contains('\x1b_Ga=a,i=1,s=3,v=0'));

    final terminal = VtTerminal(cols: 80, rows: 24);
    addTearDown(terminal.dispose);
    terminal.write(utf8.encode(sequence!));

    final image = terminal.kittyImage(1);
    expect(image, isNotNull);
    expect(image!.width, 400);
    expect(image.height, 225);
    expect(image.hasPixels, isTrue);

    // 动画会随时间推进到下一帧。
    final generation = image.generation;
    terminal.tickKittyAnimations(0);
    expect(terminal.kittyImage(1)!.generation, isNot(generation));
  });
}
