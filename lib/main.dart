import 'package:flutter/cupertino.dart';
import 'screen/homescreen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(400, 250),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.setResizable(false);
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setOpacity(1.0);
  await windowManager.setTitle('Tracker');

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        brightness: Brightness.light, // 밝은 모드 강제 설정
      ),
      home: HomeScreen(),
    );
  }
}
