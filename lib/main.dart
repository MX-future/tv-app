import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 media_kit 原生播放内核
  MediaKit.ensureInitialized();
  runApp(const TvApp());
}
