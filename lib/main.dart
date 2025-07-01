import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter_exp_timer/screen/main_screen.dart';
import 'package:flutter_exp_timer/server_manager.dart'; // 서버 매니저 불러오기
import 'package:flutter_exp_timer/log.dart'; // safeLog를 사용하기 위함
import 'package:hotkey_manager/hotkey_manager.dart';

const String appVersion = "1.8.0";
const Size appSize = Size(400, 200);

void main() {
  // FlutterError를 잡아주는 콜백
  FlutterError.onError = (FlutterErrorDetails details) {
    safeLog("FlutterError: ${details.exceptionAsString()}");
    // 디버그 콘솔에 기본 정보도 찍기
    FlutterError.dumpErrorToConsole(details);
  };

  // runZonedGuarded로 모든 Dart 비동기 예외를 잡음
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();

    ServerManager serverManager = ServerManager();
    await serverManager.startServer();

    WindowOptions windowOptions = WindowOptions(
      size: appSize,
      center: true,
      skipTaskbar: false,
      backgroundColor: CupertinoColors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.setAspectRatio(2);
    //await windowManager.setMaximumSize(appSize);
    //await windowManager.setMinimumSize(const Size(200, 100));

    await windowManager.setResizable(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMaximizable(false);
    await windowManager.setOpacity(1.0);
    await windowManager.setTitle('Tracker');

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      safeLog("앱이 실행됩니다.");

      runApp(MyApp(serverManager: serverManager));
    });
  }, (error, stackTrace) {
    // 이곳에서 전역 예외 처리
    safeLog("Unhandled error: $error\nStack: $stackTrace");
  });
}

class MyApp extends StatelessWidget {
  final ServerManager serverManager;

  const MyApp({super.key, required this.serverManager});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      // debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
      ),
      home: MainScreen(serverManager: serverManager),
    );
  }
}
