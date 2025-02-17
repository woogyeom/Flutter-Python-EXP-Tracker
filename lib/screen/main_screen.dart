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
  // 필드 선언
  ExpDataLoader expDataLoader = ExpDataLoader();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRunning = false;
  Duration showAverage = Duration.zero;
  bool isInitializing = true;
  bool isRoiSet = false;
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

  /// 안전한 setState: 위젯이 mount되어 있을 때만 상태 업데이트
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    safeLog("initState() 호출됨, 버전: $appVersion");
    windowManager.addListener(this);
    _audioPlayer.setVolume(0.5);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeLog("Post-frame callback 시작");
      _initializeApp();
    });
  }

  /// 앱 초기화: exp 데이터 로드와 config 로드를 순차적으로 실행
  Future<void> _initializeApp() async {
    try {
      // 1) exp 데이터 로드
      await expDataLoader.loadExpData();

      // 2) config 로드
      await _loadConfig(); // config 파일 읽고, levelRect/expRect 세팅

      // 3) 서버 헬스체크 & ROI 전송
      await _handleServerInitialization();
    } catch (e, stack) {
      await safeLog("초기화 중 오류 발생: $e\n$stack");
      exit(1); // 혹은 에러처리
    } finally {
      // 모든 초기화가 끝나면 로딩 상태 해제
      setState(() {
        isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    safeLog('dispose');
    windowManager.removeListener(this);
    _timer?.cancel();
    super.dispose();
  }

  /// _refreshUI: 안전하게 상태 업데이트하며 타이머 텍스트와 평균값 계산
  void _refreshUI(VoidCallback updateFn) {
    _safeSetState(() {
      updateFn();
      timerText = _formatDuration(_elapsedTime);
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

  /// _getConfigFile: config 파일 경로를 생성하고, 없으면 빈 파일("{}")로 생성
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

  /// _saveConfig: 현재 설정을 JSON 파일에 저장
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
      "timerEndTime": timerEndTime.inSeconds,
      "volume": _audioPlayer.volume,
      "showAverage": showAverage.inSeconds,
    };
    try {
      await file.writeAsString(jsonEncode(config));
    } catch (e) {
      safeLog("Error saving config: $e");
    }
  }

  /// _loadConfig: 설정 파일을 읽고, JSON 파싱 오류 발생 시 빈 파일로 재생성
  /// 그리고 config를 기반으로 상태 변수들을 업데이트 후,
  /// ROI 데이터가 있으면 서버 헬스 체크 및 ROI 전송을 진행.
  Future<void> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      String content = await file.readAsString();
      safeLog("Config 파일 내용: $content");
      Map<String, dynamic> config;
      try {
        config = jsonDecode(content);
      } catch (e) {
        safeLog("Invalid config format. Recreating config file.");
        await file.writeAsString("{}");
        config = {};
      }

      if (config.isEmpty) {
        safeLog("Empty config, skipping further config load.");
        return;
      }

      setState(() {
        // config를 읽어 상태값에 반영
        if (config["levelRect"] != null && config["levelRect"] is Map) {
          final rect = config["levelRect"] as Map<String, dynamic>;
          levelRect = Rect.fromLTRB(
            (rect["left"] ?? 0).toDouble(),
            (rect["top"] ?? 0).toDouble(),
            (rect["right"] ?? 0).toDouble(),
            (rect["bottom"] ?? 0).toDouble(),
          );
        }
        if (config["expRect"] != null && config["expRect"] is Map) {
          final rect = config["expRect"] as Map<String, dynamic>;
          expRect = Rect.fromLTRB(
            (rect["left"] ?? 0).toDouble(),
            (rect["top"] ?? 0).toDouble(),
            (rect["right"] ?? 0).toDouble(),
            (rect["bottom"] ?? 0).toDouble(),
          );
        }
        timerEndTime = Duration(seconds: config["timerEndTime"] ?? 0);
        _audioPlayer.setVolume(config["volume"] ?? 0.5);
        showAverage = Duration(seconds: config["showAverage"] ?? 0);
      });
      safeLog("Config loaded: $config");
    } catch (e) {
      await safeLog("Error loading config: $e");
      exit(1);
    }
  }

  /// _handleServerInitialization: 서버 헬스 체크와 ROI 전송을 순차적으로 실행
  Future<void> _handleServerInitialization() async {
    // 1) 초기화 시작: 로딩 상태로 전환
    setState(() {
      isInitializing = true;
    });

    try {
      safeLog("서버 헬스 체크 시작");
      await _waitForServerReady(); // /health 확인
      safeLog("서버 헬스 체크 완료, ROI 전송 시작");

      // 2) ROI가 있으면 서버에 전송
      if (levelRect != null && expRect != null) {
        await sendROIToServer();
        setState(() {
          isRoiSet = true; // 전송 성공 시점에 true
        });
        safeLog("ROI Sent to Server");
      } else {
        safeLog("No ROI data, skipping ROI send");
        // isRoiSet = false
      }
    } catch (e, stack) {
      await safeLog("Server initialization error: $e\nStackTrace: $stack");
      exit(1);
    } finally {
      // 3) 초기화 종료: 로딩 상태 해제
      setState(() {
        isInitializing = false;
      });
    }
  }

  /// checkServerReady: /health 엔드포인트를 호출하여 서버 준비 여부 확인
  Future<bool> checkServerReady() async {
    try {
      final response =
          await http.get(Uri.parse("http://127.0.0.1:5000/health"));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// _waitForServerReady: 일정 시간 동안 서버 준비 여부를 확인
  /// 타임아웃되면 로그를 남기고 앱 종료
  Future<void> _waitForServerReady({int timeoutSeconds = 30}) async {
    final startTime = DateTime.now();
    while (true) {
      try {
        if (await checkServerReady()) {
          safeLog("서버 준비 완료");
          return;
        }
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        if (elapsed > timeoutSeconds) {
          await safeLog("Timeout: 서버가 준비되지 않았습니다. ($elapsed 초 경과)");
          exit(1);
        }
        safeLog("서버 준비 대기 중... ($elapsed 초 경과)");
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e, stack) {
        // 혹시 checkServerReady()에서 예외가 발생한다면 여기서 잡힐 것
        await safeLog(
            "예외 발생 during waitForServerReady: $e\nStackTrace: $stack");
        // exit(1)을 할지, 계속 재시도할지는 상황에 맞게 결정
        exit(1);
      }
    }
  }

  /// sendROIToServer: ROI 데이터를 서버에 전송
  Future<void> sendROIToServer() async {
    if (levelRect == null || expRect == null) {
      safeLog("ROI 데이터가 설정되지 않았습니다.");
      return;
    }
    final url = Uri.parse("http://127.0.0.1:5000/set_roi");
    Map<String, dynamic> roiData = {
      "level": [
        levelRect!.left,
        levelRect!.top,
        levelRect!.right,
        levelRect!.bottom
      ],
      "exp": [expRect!.left, expRect!.top, expRect!.right, expRect!.bottom],
    };
    if (mesoRect != null) {
      roiData["meso"] = [
        mesoRect!.left,
        mesoRect!.top,
        mesoRect!.right,
        mesoRect!.bottom
      ];
    }
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(roiData));
      if (response.statusCode == 200) {
        _refreshUI(() {
          isRoiSet = true;
        });
        safeLog("ROI 데이터 성공적으로 서버에 전송됨: ${response.body}");
      } else {
        safeLog("서버 오류: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      safeLog("ROI 전송 중 오류 발생: $e");
    }
  }

  /// fetchAndDisplayExpData: 서버에서 경험치 데이터를 가져와 UI 업데이트
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
            initialExp = exp;
            initialPercentage = percentage;
            safeLog(
                "초기값: initialExp=$initialExp, initialPercentage=$initialPercentage, initialLevel=$initialLevel");
            return;
          }
          if (level > lastLevel &&
              ((level - lastLevel) == 1 || (level - lastLevel) == 2)) {
            safeLog("Level Up Detected!");
            int levelUpExp = expDataLoader.getExpForLevel(lastLevel);
            expBeforeLevelUp = levelUpExp - lastExp + totalExp;
            percentageBeforeLevelUp = 100 - lastPercentage + totalPercentage;
            initialExp = 0;
            initialPercentage = 0.00;
            lastLevel = level;
            safeLog(
                "레벨업 전: expBeforeLevelUp=$expBeforeLevelUp, percentageBeforeLevelUp=$percentageBeforeLevelUp");
          }
          totalExp = exp - initialExp + expBeforeLevelUp;
          totalPercentage =
              percentage - initialPercentage + percentageBeforeLevelUp;
          lastExp = exp;
          lastPercentage = percentage;
          lastLevel = level;
          safeLog(
              "최근값: lastExp=$lastExp, lastPercentage=$lastPercentage, lastLevel=$lastLevel | 누적값: totalExp=$totalExp, totalPercentage=${totalPercentage.toStringAsFixed(2)}");
        });
      } else {
        throw Exception("Failed to fetch EXP data");
      }
    } catch (e) {
      safeLog("[Server] Error fetching EXP data: $e");
    }
  }

  /// fetchAndDisplayMesoData: 서버에서 메소 데이터를 가져와 UI 업데이트
  Future<void> fetchAndDisplayMesoData() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/extract_meso'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int meso = data['meso'];
        _refreshUI(() {
          if (initialMeso == 0) {
            initialMeso = meso;
            safeLog("초기 메소: $initialMeso");
            return;
          }
          totalMeso = meso - initialMeso;
        });
        safeLog("누적 메소: $totalMeso");
      } else {
        throw Exception("Failed to fetch Meso data");
      }
    } catch (e) {
      safeLog("[Server] Error fetching Meso data: $e");
    }
  }

  /// _startTimer: 타이머 시작 및 주기적으로 EXP/메소 데이터 업데이트
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

  /// _stopTimer: 타이머 중지
  Future<void> _stopTimer() async {
    _refreshUI(() {
      isRunning = false;
    });
    _timer?.cancel();
  }

  /// _resetTimer: 타이머 및 관련 변수 초기화
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

  /// _formatDuration: Duration을 HH:MM:SS 형식으로 변환
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours.remainder(60));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  /// _openSettingsScreen: 설정 화면 열기
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
      _saveConfig();
    }
  }

  /// _openRectSelectScreen: 영역 선택 화면 열기 (ROI 설정)
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
      _safeSetState(() {
        isRoiSet = true;
      });
      _saveConfig();
      sendROIToServer();
    }
  }

  /// _openMesoRectSelectScreen: 메소 영역 선택 화면 열기
  Future<void> _openMesoRectSelectScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
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

  /// _launchURL: GitHub 링크 열기
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
    safeLog("Closing app...");
    await widget.serverManager.shutdownServer();
    windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    safeLog("build() 호출됨");
    return CupertinoPageScaffold(
      backgroundColor: isRunning
          ? CupertinoColors.darkBackgroundGray.withAlpha(200)
          : CupertinoColors.darkBackgroundGray,
      child: DragToMoveArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _launchURL,
                  child: const Icon(CupertinoIcons.info,
                      color: CupertinoColors.systemGrey6, size: 24),
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
                            _safeSetState(() {
                              // appSize는 main.dart에서 정의된 글로벌 변수라고 가정
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
                  child: const Icon(CupertinoIcons.crop,
                      color: CupertinoColors.systemGrey6, size: 24),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openSettingsScreen,
                  child: const Icon(CupertinoIcons.gear_solid,
                      color: CupertinoColors.systemGrey6, size: 24),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    widget.serverManager.shutdownServer();
                    windowManager.close();
                  },
                  child: const Icon(CupertinoIcons.xmark_circle_fill,
                      color: CupertinoColors.systemRed, size: 24),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: isInitializing
                                ? null // 초기화 중엔 버튼 비활성화
                                : () {
                                    if (!isRoiSet) {
                                      _openRectSelectScreen();
                                      return;
                                    }
                                    if (!isRunning &&
                                        _elapsedTime == Duration.zero) {
                                      _startTimer();
                                    } else if (isRunning) {
                                      _stopTimer();
                                    } else {
                                      _resetTimer();
                                    }
                                  },
                            color: isInitializing
                                ? CupertinoColors.systemGrey
                                : !isRoiSet
                                    ? CupertinoColors.systemGrey
                                    : isRunning
                                        ? CupertinoColors.systemRed
                                        : _elapsedTime == Duration.zero
                                            ? CupertinoColors.systemGreen
                                            : CupertinoColors.systemBlue,
                            borderRadius: BorderRadius.circular(12),
                            child: isInitializing
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white)
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                  if (showMeso)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
