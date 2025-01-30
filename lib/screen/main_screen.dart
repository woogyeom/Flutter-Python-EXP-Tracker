import 'package:flutter/cupertino.dart';

import 'dart:async';
import 'dart:convert';

import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_exp_timer/exp_data_loader.dart';
import 'package:flutter_exp_timer/screen/rect_select_screen.dart';
import 'package:flutter_exp_timer/server_manager.dart';

class MainScreen extends StatefulWidget {
  final ServerManager serverManager;

  const MainScreen({super.key, required this.serverManager});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  bool isRunning = false;
  String timerText = "00:00:00";
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool isServerRunning = false;

  int initialExp = 0;
  double initialPercentage = 0.00;

  int lastExp = 0;
  double lastPercentage = 0.00;
  int lastLevel = 0;

  int totalExp = 0;
  double totalPercentage = 0.00;

  bool isErrorShown = false;

  ExpDataLoader expDataLoader = ExpDataLoader();

  Rect? levelRect;
  Rect? expRect;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    widget.serverManager.startServer(); // 앱 실행 시 FastAPI 서버 실행
  }

  @override
  void dispose() {
    print('dispose');
    super.dispose();
    windowManager.removeListener(this);
  }

  // FastAPI에서 경험치 데이터 가져오기
  Future<void> fetchAndDisplayExpData() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5000/extract_exp_and_level'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          int exp = data['exp'];
          double percentage = data['percentage'];
          int level = data['level'];

          if (lastLevel == 0) {
            lastLevel = level;
            lastExp = exp;
            lastPercentage = percentage;
            return;
          }

          if (level != lastLevel) {
            int levelUpExp = expDataLoader.getExpForLevel(lastLevel);
            totalExp += (levelUpExp - lastExp);
            totalPercentage += (100.0 - lastPercentage);

            totalExp += exp;
            totalPercentage += percentage;

            lastLevel = level;
            lastExp = exp;
            lastPercentage = percentage;
          } else {
            totalExp += (exp - lastExp);
            totalPercentage += (percentage - lastPercentage);

            lastExp = exp;
            lastPercentage = percentage;
          }
        });
      } else {
        throw Exception("Failed to fetch EXP data");
      }
    } catch (e) {
      print("Error fetching EXP data: $e");
    }
  }

  // 타이머 시작
  Future<void> _startTimer() async {
    setState(() {
      isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
        timerText = _formatDuration(_elapsedTime);
      });

      fetchAndDisplayExpData();
    });
  }

  // 타이머 멈추기
  Future<void> _stopTimer() async {
    setState(() {
      isRunning = false;
      _timer?.cancel();
    });
  }

  // 타이머 초기화
  void _resetTimer() {
    setState(() {
      isRunning = false;
      _timer?.cancel();
      _elapsedTime = Duration.zero;
      timerText = _formatDuration(_elapsedTime);
      totalExp = 0;
      totalPercentage = 0.00;
    });
  }

  // 시간 포맷
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours.remainder(60));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // 영역 선택 스크린
  void _openRectSelectScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RectSelectScreen(),
        transitionDuration: Duration.zero, // ✅ 애니메이션 제거
        reverseTransitionDuration: Duration.zero, // ✅ 뒤로 가기 애니메이션 제거
      ),
    );

    if (result != null) {
      print("✅ result가 정상적으로 들어왔습니다: $result");
      print("🔹 levelRect: ${result['level']}");
      print("🔹 expRect: ${result['exp']}");
      setState(() {
        levelRect = result['level'];
        expRect = result['exp'];
      });
    }
  }

  @override
  void onWindowClose() {
    print("Closing app...");
    widget.serverManager.shutdownServer(); // 서버 종료 후
    windowManager.close(); // 앱 종료
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: isRunning
          ? CupertinoColors.darkBackgroundGray.withAlpha(200)
          : CupertinoColors.darkBackgroundGray,
      child: Stack(
        children: [
          DragToMoveArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 50,
                        child: CupertinoButton(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          onPressed: () {
                            if (!isRunning && _elapsedTime == Duration.zero) {
                              initialExp = totalExp;
                              _startTimer();
                            } else if (isRunning) {
                              _stopTimer();
                            } else {
                              _resetTimer();
                            }
                          },
                          color: isRunning
                              ? CupertinoColors.systemRed
                              : _elapsedTime == Duration.zero
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(16),
                          child: Text(
                            isRunning
                                ? '중단'
                                : _elapsedTime == Duration.zero
                                    ? '시작'
                                    : '초기화',
                            style: GoogleFonts.roboto(
                              textStyle: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        timerText,
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '+ $totalExp [${totalPercentage.toStringAsFixed(2)}%]',
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            color: CupertinoColors.systemYellow,
                            fontWeight: FontWeight.w400,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openRectSelectScreen,
                  child: Icon(
                    CupertinoIcons.desktopcomputer,
                    color: CupertinoColors.systemGrey6,
                    size: 24,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    widget.serverManager.shutdownServer();
                    windowManager.close();
                  },
                  child: Icon(
                    CupertinoIcons.clear_thick_circled,
                    color: CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
