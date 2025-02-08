import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter_exp_timer/screen/main_screen.dart';
import 'package:flutter_exp_timer/server_manager.dart'; // 서버 매니저 불러오기

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  ServerManager serverManager = ServerManager();
  await serverManager.startServer();

  WindowOptions windowOptions = WindowOptions(
    size: Size(400, 200),
    center: true,
    skipTaskbar: false,
    backgroundColor: CupertinoColors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.setResizable(false);
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setMaximizable(false);
  await windowManager.setOpacity(1.0);
  await windowManager.setTitle('Tracker');

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
  });

  runApp(MyApp(serverManager: serverManager));
}

class MyApp extends StatelessWidget {
  final ServerManager serverManager;

  const MyApp({super.key, required this.serverManager});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
      ),
      home: MainScreen(serverManager: serverManager),
    );
  }
}
