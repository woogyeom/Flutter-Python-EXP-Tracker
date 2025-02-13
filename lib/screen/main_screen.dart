import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exp_timer/log.dart';
import 'package:flutter_exp_timer/main.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:flutter_exp_timer/exp_data_loader.dart';
import 'package:flutter_exp_timer/screen/settings_screen.dart';
import 'package:flutter_exp_timer/screen/rect_select_screen.dart';
import 'package:flutter_exp_timer/server_manager.dart';

class MainScreen extends StatefulWidget {
  final ServerManager serverManager;

  const MainScreen({super.key, required this.serverManager});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  ExpDataLoader expDataLoader = ExpDataLoader();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRunning = false;
  Duration showAverage = Duration.zero;
  bool isServerRunning = false;
  bool isErrorShown = false;
  bool isRoiSet = false;
  bool isConfigLoaded = false;
  bool showMeso = false;

  String timerText = "00:00:00";
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  int initialExp = 0;
  double initialPercentage = 0.00;
  int initialLevel = 0;
  int initialMeso = 0;
  int lastExp = 0;
  double lastPercentage = 0.00;
  int lastLevel = 0;
  int totalExp = 0;
  double totalPercentage = 0.00;
  int totalMeso = 0;
  int averageExp = 0;
  double averagePercentage = 0.00;
  int averageMeso = 0;

  int expBeforeLevelUp = 0;
  double percentageBeforeLevelUp = 0.00;

  Duration timerEndTime = Duration.zero;

  Rect? levelRect;
  Rect? expRect;
  Rect? mesoRect;

  final numberFormat = NumberFormat("#,###");

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    expDataLoader.loadExpData();
    _audioPlayer.setVolume(0.5);
    _loadConfig();
  }

  @override
  void dispose() {
    log('dispose');
    windowManager.removeListener(this);
    super.dispose();
  }

  // _refreshUI: 상태 업데이트 후 화면 갱신을 위한 헬퍼 메소드
  void _refreshUI(VoidCallback updateFn) {
    setState(() {
      updateFn();
      // _elapsedTime로부터 timerText를 갱신
      timerText = _formatDuration(_elapsedTime);
      // 평균 EXP/Percentage 계산 (경과 시간이 있을 때)
      if (showAverage != Duration.zero && _elapsedTime.inSeconds > 0) {
        averageExp =
            ((totalExp / _elapsedTime.inSeconds) * showAverage.inSeconds)
                .floor();
        averagePercentage =
            (totalPercentage / _elapsedTime.inSeconds) * showAverage.inSeconds;
        averageMeso =
            ((totalMeso / _elapsedTime.inSeconds) * showAverage.inSeconds)
                .floor();
      }
    });
  }

  Future<File> _getConfigFile() async {
    const String configPath = "config/config.json";
    final Directory currentDir = Directory.current;
    final File configFile = File('${currentDir.path}/$configPath');

    if (!await configFile.parent.exists()) {
      await configFile.parent.create(recursive: true);
    }
    if (!await configFile.exists()) {
      await configFile.writeAsString("{}");
    }

    return configFile;
  }

  // 설정값을 JSON 파일로 저장
  Future<void> _saveConfig() async {
    final file = await _getConfigFile();
    Map<String, dynamic> config = {
      "levelRect": levelRect != null
          ? {
              "left": levelRect!.left,
              "top": levelRect!.top,
              "right": levelRect!.right,
              "bottom": levelRect!.bottom,
            }
          : null,
      "expRect": expRect != null
          ? {
              "left": expRect!.left,
              "top": expRect!.top,
              "right": expRect!.right,
              "bottom": expRect!.bottom,
            }
          : null,
      "mesoRect": mesoRect != null
          ? {
              "left": mesoRect!.left,
              "top": mesoRect!.top,
              "right": mesoRect!.right,
              "bottom": mesoRect!.bottom,
            }
          : null,
      "timerEndTime": timerEndTime.inSeconds,
      "volume": _audioPlayer.volume,
      "showAverage": showAverage.inSeconds,
      // "showMeso": showMeso,
    };
    try {
      await file.writeAsString(jsonEncode(config));
      // log("Config saved: ${jsonEncode(config)}");
    } catch (e) {
      log("Error saving config: $e");
    }
  }

  Future<void> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        String content = await file.readAsString();
        Map<String, dynamic> config = jsonDecode(content);

        // config가 비어있으면 추가 처리 없이 isConfigLoaded만 true로 설정하고 반환
        if (config.isEmpty) {
          log("Empty config, skipping further config load.");
          _refreshUI(() {
            isConfigLoaded = true;
          });
          return;
        }

        _refreshUI(() {
          if (config["levelRect"] != null) {
            Map<String, dynamic> rect = config["levelRect"];
            levelRect = Rect.fromLTRB(
              rect["left"],
              rect["top"],
              rect["right"],
              rect["bottom"],
            );
          }
          if (config["expRect"] != null) {
            Map<String, dynamic> rect = config["expRect"];
            expRect = Rect.fromLTRB(
              rect["left"],
              rect["top"],
              rect["right"],
              rect["bottom"],
            );
          }
          if (config["mesoRect"] != null) {
            Map<String, dynamic> rect = config["mesoRect"];
            mesoRect = Rect.fromLTRB(
              rect["left"],
              rect["top"],
              rect["right"],
              rect["bottom"],
            );
          }
          timerEndTime = Duration(seconds: config["timerEndTime"]);
          _audioPlayer.setVolume(config["volume"]);
          showAverage = Duration(seconds: config["showAverage"]);
          // showMeso = config["showMeso"];
          // if (showMeso) windowManager.setSize(Size(appSize.width, 250));
          isConfigLoaded = true;
        });
        log("Config loaded: $config");

        // levelRect와 expRect가 모두 설정되어 있을 때만 ROI 전송
        if (levelRect != null && expRect != null) {
          await waitForServerReady();
          await sendROIToServer();
          log("ROI Sent to Server");
        } else {
          log("No ROI data");
        }
      }
    } catch (e) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(
              "서버와 연결 실패",
              style: GoogleFonts.notoSans(
                textStyle: const TextStyle(
                  color: CupertinoColors.black,
                  fontSize: 16,
                ),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  "확인",
                  style: GoogleFonts.notoSans(
                    textStyle: const TextStyle(
                      color: CupertinoColors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      log("Error loading config: $e");
    }
  }

  Future<bool> checkServerReady() async {
    try {
      final response =
          await http.get(Uri.parse("http://127.0.0.1:5000/health"));
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // log("서버 준비 상태 확인 중 오류 발생: $e");
    }
    return false;
  }

  Future<void> waitForServerReady({int timeoutSeconds = 30}) async {
    final startTime = DateTime.now();
    while (true) {
      if (await checkServerReady()) {
        log("서버 준비 완료");
        return;
      }
      // 타임아웃 처리
      if (DateTime.now().difference(startTime).inSeconds > timeoutSeconds) {
        throw Exception("Timeout: 서버가 준비되지 않았습니다.");
      }
      // 재시도 간격
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  Future<void> sendROIToServer() async {
    if (levelRect == null || expRect == null) {
      log("ROI 데이터가 설정되지 않았습니다.");
      return;
    }

    final url = Uri.parse("http://127.0.0.1:5000/set_roi");

    // 필수 ROI 데이터
    Map<String, dynamic> roiData = {
      "level": [
        levelRect!.left,
        levelRect!.top,
        levelRect!.right,
        levelRect!.bottom
      ],
      "exp": [expRect!.left, expRect!.top, expRect!.right, expRect!.bottom],
    };

    // mesoRect가 있으면 추가
    if (mesoRect != null) {
      roiData["meso"] = [
        mesoRect!.left,
        mesoRect!.top,
        mesoRect!.right,
        mesoRect!.bottom
      ];
    }

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(roiData),
      );

      if (response.statusCode == 200) {
        _refreshUI(() {
          isRoiSet = true;
        });
        log("ROI 데이터 성공적으로 서버에 전송됨: ${response.body}");
      } else {
        log("서버 오류: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      log("ROI 전송 중 오류 발생: $e");
    }
  }

  // FastAPI에서 경험치 데이터 가져오기
  Future<void> fetchAndDisplayExpData() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5000/extract_exp_and_level'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        int exp = data['exp'];
        double percentage = data['percentage'];
        int level = data['level'];

        _refreshUI(() {
          if (initialLevel == 0) {
            initialLevel = level;
            initialExp = exp; // 최초 경험치를 기준값으로 설정
            initialPercentage = percentage;
            log("초기값: initialExp=$initialExp, initialPercentage=$initialPercentage, initialLevel=$initialLevel | ");
            return;
          }

          // 레벨업 감지
          if (level > lastLevel &&
              ((level - lastLevel) == 1 || (level - lastLevel) == 2)) {
            log("Level Up Detected!");
            int levelUpExp = expDataLoader.getExpForLevel(lastLevel);

            expBeforeLevelUp = levelUpExp - lastExp + totalExp;
            percentageBeforeLevelUp = 100 - lastPercentage + totalPercentage;
            initialExp = 0; // 레벨업 후 새로운 기준값 설정
            initialPercentage = 0.00;
            lastLevel = level;
            log("초기값: initialExp=$initialExp, initialPercentage=$initialPercentage, initialLevel=$initialLevel | ");
            log("레벨업 전: expBeforeLevelUp=$expBeforeLevelUp, percentageBeforeLevelUp=$percentageBeforeLevelUp");
          }

          // 경험치 증가량을 계산
          totalExp = exp - initialExp + expBeforeLevelUp;
          totalPercentage =
              percentage - initialPercentage + percentageBeforeLevelUp;

          lastExp = exp;
          lastPercentage = percentage;
          lastLevel = level;

          log("최근값: lastExp=$lastExp, lastPercentage=$lastPercentage, lastLevel=$lastLevel | "
              "누적값: totalExp=$totalExp, totalPercentage=$totalPercentage | ");
        });
      } else {
        throw Exception("Failed to fetch EXP data");
      }
    } catch (e) {
      log("[Server] Error fetching EXP data: $e");
    }
  }

  // FastAPI에서 메소 데이터 가져오기
  Future<void> fetchAndDisplayMesoData() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/extract_meso'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int meso = data['meso'];

        _refreshUI(() {
          if (initialMeso == 0) {
            initialMeso = meso; // 타이머 시작 시 초기값 설정
            log("  초기 메소: $initialMeso");
            return;
          }

          totalMeso = meso - initialMeso; // 초기값과 비교하여 증가량 계산
        });

        log("  누적 메소: $totalMeso");
      } else {
        throw Exception("Failed to fetch Meso data");
      }
    } catch (e) {
      log("[Server] Error fetching Meso data: $e");
    }
  }

  // 타이머 시작
  Future<void> _startTimer() async {
    _refreshUI(() {
      isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _refreshUI(() {
        _elapsedTime += const Duration(seconds: 1);
      });

      fetchAndDisplayExpData();

      if (showMeso) fetchAndDisplayMesoData();

      if (timerEndTime != Duration.zero && _elapsedTime >= timerEndTime) {
        _audioPlayer.play(AssetSource('timer_alarm.mp3'));
        _stopTimer();
      }
    });
  }

  // 타이머 멈추기
  Future<void> _stopTimer() async {
    _refreshUI(() {
      isRunning = false;
    });
    _timer?.cancel();
  }

  // 타이머 초기화
  void _resetTimer() {
    _refreshUI(() {
      isRunning = false;
      _elapsedTime = Duration.zero;
      initialExp = 0;
      initialPercentage = 0;
      initialLevel = 0;
      initialMeso = 0;
      lastExp = 0;
      lastPercentage = 0;
      totalExp = 0;
      totalPercentage = 0;
      totalMeso = 0;
      averageExp = 0;
      averagePercentage = 0;
      averageMeso = 0;
      expBeforeLevelUp = 0;
      percentageBeforeLevelUp = 0;
    });
    _timer?.cancel();
  }

  // 시간 포맷
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours.remainder(60));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // 설정 화면 열기
  void _openSettingsScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          isRunning: isRunning,
          timerEndTime: timerEndTime,
          showAverage: showAverage,
          audioPlayer: _audioPlayer,
          showMeso: showMeso,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (result != null) {
      _refreshUI(() {
        timerEndTime = result['timerEndTime'];
        showAverage = result['showAverage'];
        showMeso = result['showMeso'];
      });
      _saveConfig(); // 변경된 설정 저장
    }
  }

  // 영역 선택 스크린 열기
  Future<void> _openRectSelectScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RectSelectScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (result != null) {
      _refreshUI(() {
        levelRect = result['level'];
        expRect = result['exp'];
      });
      setState(() {
        isRoiSet = true;
      });
      _saveConfig(); // ROI 정보 저장
      sendROIToServer();
    }
  }

  // 메소용 Rect 선택 스크린 열기 (옵셔널)
  Future<void> _openMesoRectSelectScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        // 같은 RectSelectScreen을 사용하되, 추가 파라미터를 전달해 "메소" 용도임을 알림 (스크린 내에서 분기 처리 가능)
        pageBuilder: (context, animation, secondaryAnimation) =>
            RectSelectScreen(isMeso: true),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (result != null) {
      _refreshUI(() {
        mesoRect = result['meso'];
      });
      _saveConfig();
      sendROIToServer();
    }
  }

  // 깃허브 링크 열기
  void _launchURL() async {
    final Uri url =
        Uri.parse("https://github.com/woogyeom/Flutter-Python-EXP-Tracker");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch $url";
    }
  }

  @override
  void onWindowClose() async {
    log("Closing app...");
    await widget.serverManager.shutdownServer(); // 서버 종료 후
    windowManager.close(); // 앱 종료
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: isRunning
          ? CupertinoColors.darkBackgroundGray.withAlpha(200)
          : CupertinoColors.darkBackgroundGray,
      child: DragToMoveArea(
        child: Column(
          children: [
            // 상단 버튼 Row
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _launchURL,
                  child: const Icon(
                    CupertinoIcons.info,
                    color: CupertinoColors.systemGrey6,
                    size: 24,
                  ),
                ),
                SizedBox(
                  width: 192,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          value: showMeso,
                          onChanged: (bool value) async {
                            _refreshUI(() {
                              showMeso = value;
                            });
                            _saveConfig();
                            setState(() {
                              if (showMeso) {
                                windowManager.setSize(Size(appSize.width, 250));
                              } else {
                                windowManager.setSize(appSize);
                              }
                            });
                            if (value) {
                              await _openMesoRectSelectScreen();
                            }
                          },
                          inactiveThumbColor: CupertinoColors.inactiveGray,
                          inactiveTrackColor: CupertinoColors.inactiveGray,
                          activeTrackColor: CupertinoColors.activeBlue,
                          thumbColor: CupertinoColors.activeBlue,
                          activeThumbImage: AssetImage('assets/meso.png'),
                          inactiveThumbImage: AssetImage('assets/meso.png'),
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await _openRectSelectScreen();
                  },
                  child: const Icon(
                    CupertinoIcons.crop,
                    color: CupertinoColors.systemGrey6,
                    size: 24,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openSettingsScreen,
                  child: const Icon(
                    CupertinoIcons.gear_solid,
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
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            // 타이머와 텍스트 영역
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 타이머
                  Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (!isConfigLoaded) {
                                return;
                              }
                              if (!isRoiSet) {
                                _openRectSelectScreen();
                                return;
                              }
                              if (!isRunning && _elapsedTime == Duration.zero) {
                                _startTimer();
                              } else if (isRunning) {
                                _stopTimer();
                              } else {
                                _resetTimer();
                              }
                            },
                            color: !isRoiSet
                                ? CupertinoColors.systemGrey
                                : isRunning
                                    ? CupertinoColors.systemRed
                                    : _elapsedTime == Duration.zero
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemBlue,
                            borderRadius: BorderRadius.circular(12),
                            child: !isConfigLoaded
                                ? const CupertinoActivityIndicator()
                                : Icon(
                                    !isRoiSet
                                        ? CupertinoIcons.crop
                                        : isRunning
                                            ? CupertinoIcons.stop_fill
                                            : _elapsedTime == Duration.zero
                                                ? CupertinoIcons
                                                    .play_arrow_solid
                                                : CupertinoIcons.restart,
                                    color: CupertinoColors.white,
                                    size: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          timerText,
                          style: GoogleFonts.notoSans(
                            textStyle: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 48,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // EXP 텍스트 영역 (동적 크기 적용)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 메인 EXP 텍스트
                          Text(
                            '${numberFormat.format(totalExp)} [${totalPercentage.toStringAsFixed(2)}%]',
                            style: GoogleFonts.notoSans(
                              textStyle: const TextStyle(
                                height: 1.2,
                                color: CupertinoColors.systemYellow,
                                fontWeight: FontWeight.w400,
                                fontSize: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 평균 EXP 텍스트 (메인보다 2:1 작게)
                          if (showAverage != Duration.zero)
                            Text(
                              '${numberFormat.format(averageExp)} [${averagePercentage.toStringAsFixed(2)}%] / ${showAverage.inMinutes}분',
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  height: 1.2,
                                  color: CupertinoColors.systemYellow,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 메소 영역 (동적 크기 적용)
                  if (showMeso)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 메인 메소 텍스트
                            Text(
                              '${numberFormat.format(totalMeso)} 메소',
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  height: 1.2,
                                  color: CupertinoColors.systemYellow,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // 평균 메소 텍스트 (메인보다 2:1 작게)
                            if (showMeso && showAverage != Duration.zero)
                              Text(
                                '${numberFormat.format(averageMeso)} 메소 / ${showAverage.inMinutes}분',
                                style: GoogleFonts.notoSans(
                                  textStyle: const TextStyle(
                                    height: 1.2,
                                    color: CupertinoColors.systemYellow,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
