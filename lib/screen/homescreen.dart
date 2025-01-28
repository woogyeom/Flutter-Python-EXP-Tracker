import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:async';
import '../exp_data_loader.dart';
import '../ocr/ocr_util.dart';
import '../server_manager.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  bool isRunning = false;
  String timerText = "00:00";
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  ExpDataLoader expDataLoader = ExpDataLoader();

  bool isServerRunning = false;
  ServerManager serverManager = ServerManager();

  int initialExp = 0;
  double initialPercentage = 0.00;

  int lastExp = 0;
  double lastPercentage = 0.00;
  int lastLevel = 0;

  int totalExp = 0;
  double totalPercentage = 0.00;

  final expFetcher = ExpFetcher('http://127.0.0.1:5000');

  bool isErrorShown = false;

  // 서버 시작
  void _startServer() {
    serverManager.startServer();
    setState(() {
      isServerRunning = true;
    });
  }

  // 서버 종료
  void _shutdownServer() {
    serverManager.shutdownServer();
    setState(() {
      isServerRunning = false;
    });
  }

  @override
  void initState() {
    super.initState();
    expDataLoader.loadExpData();
    windowManager.addListener(this); // Add window manager listener
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this); // Remove window manager listener
  }

  // 경험치와 퍼센트를 가져오는 함수
  void fetchAndDisplayExpData() {
    expFetcher.fetchAndDisplayExpData(
      onUpdate: (exp, percentage, level) {
        setState(() {
          // 처음 한 번만 세팅
          if (lastLevel == 0) {
            lastLevel = level;
            lastExp = exp;
            lastPercentage = percentage;
            return;
          }

          if (level != lastLevel) {
            // 레벨 업 로직
            // 1) 이전 레벨의 남은 exp/퍼센트를 채워주고
            int levelUpExp = expDataLoader.getExpForLevel(lastLevel);
            totalExp += (levelUpExp - lastExp);
            totalPercentage += (100.0 - lastPercentage);

            // 2) 새 레벨에서 현재 exp/퍼센트를 추가
            totalExp += exp;
            totalPercentage += percentage;

            // 마지막으로 현재 레벨/경험치 정보를 갱신
            lastLevel = level;
            lastExp = exp;
            lastPercentage = percentage;
          } else {
            // 레벨 변화 없는 경우 = exp/퍼센트 증가분만 누적
            totalExp += (exp - lastExp);
            totalPercentage += (percentage - lastPercentage);

            lastExp = exp;
            lastPercentage = percentage;
          }
        });
      },
      onError: (errorMessage) {
        print("Error occurred: $errorMessage");
      },
    );
  }

  // 타이머 시작 함수
  Future<void> _startTimer() async {
    setState(() {
      isRunning = true;
    });

    await windowManager.setOpacity(0.7);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
        timerText = _formatDuration(_elapsedTime);
      });

      fetchAndDisplayExpData();
    });
  }

  // 타이머 멈추는 함수
  Future<void> _stopTimer() async {
    setState(() {
      isRunning = false;
      _timer?.cancel();
    });

    await windowManager.setOpacity(1.0);
  }

  // 타이머 리셋 함수
  void _clearTimerState() {
    _elapsedTime = Duration.zero;
    timerText = _formatDuration(_elapsedTime);
  }

  // 타이머 초기화
  void _resetTimer() {
    setState(() {
      isRunning = false;
      _timer?.cancel();
      _clearTimerState();
      totalExp = 0; // 경험치 리셋 (총 경험치 초기화)
      totalPercentage = 0.00; // 퍼센트 리셋 (총 퍼센트 초기화)
    });
  }

  // 시간 포맷
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void onWindowClose() {
    // 서버 종료 요청을 보내고, 창을 닫는 처리
    _shutdownServer();
    windowManager.close(); // 창을 닫습니다.
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.darkBackgroundGray,
      child: Stack(
        children: [
          DragToMoveArea(
            // 창을 이동할 수 있도록 추가
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // 가로로 중앙 정렬
                    children: [
                      SizedBox(
                        width: 100,
                        height: 50,
                        child: CupertinoButton(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          onPressed: () {
                            if (!isRunning && _elapsedTime == Duration.zero) {
                              initialExp = totalExp; // 시작 시 초기화 경험치
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
                            fontSize: 60,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '+ $totalExp [${totalPercentage.toStringAsFixed(2)}%]', // 경험치와 퍼센트 차이
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            color: CupertinoColors.systemYellow,
                            fontWeight: FontWeight.w400,
                            fontSize: 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 종료 버튼 추가 (우측 상단)
          Positioned(
            top: 8,
            right: 8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _shutdownServer();
                windowManager.close(); // 창을 닫는 처리
              },
              child: Icon(
                CupertinoIcons.clear_thick_circled,
                color: CupertinoColors.systemRed,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
