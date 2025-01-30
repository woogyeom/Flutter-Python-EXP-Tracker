import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

import 'screen/homescreen.dart';
import 'server_manager.dart'; // 서버 매니저 불러오기

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(400, 180),
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

  // ServerManager 인스턴스 생성 후 실행
  ServerManager serverManager = ServerManager();
  // serverManager.startServer();

  runApp(MyApp(serverManager: serverManager));
}

class MyApp extends StatelessWidget {
  final ServerManager serverManager;

  const MyApp({super.key, required this.serverManager});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
      ),
      home: HomeScreen(serverManager: serverManager),
    );
  }
}
