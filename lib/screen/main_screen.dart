import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exp_timer/exp_data_loader.dart';
import 'package:flutter_exp_timer/log.dart';
import 'package:flutter_exp_timer/main.dart';
import 'package:flutter_exp_timer/screen/rect_select_screen.dart';
import 'package:flutter_exp_timer/screen/settings_screen.dart';
import 'package:flutter_exp_timer/server_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class MainScreen extends StatefulWidget {
  final ServerManager serverManager;

  const MainScreen({super.key, required this.serverManager});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  // 데이터 및 플레이어
  final ExpDataLoader _expDataLoader = ExpDataLoader();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 상태 변수
  bool isRunning = false;
  bool isInitializing = true;
  bool isRoiSet = false;
  bool isInitValueInserted = false;
  bool showMeso = false;

  // UI 관련 시간 설정
  Duration showAverage = Duration.zero;
  Duration updateInterval = const Duration(seconds: 1);
  Duration timerEndTime = Duration.zero;
  Duration _elapsedTime = Duration.zero;

  // 경험치/레벨 관련 변수
  int initialExp = 0;
  double initialPercentage = 0.0;
  int initialLevel = 0;
  int initialMeso = 0;
  int lastExp = 0;
  double lastPercentage = 0.0;
  int lastLevel = 0;
  int totalExp = 0;
  double totalPercentage = 0.0;
  int totalMeso = 0;
  int averageExp = 0;
  double averagePercentage = 0.0;
  int averageMeso = 0;
  int expBeforeLevelUp = 0;
  double percentageBeforeLevelUp = 0.0;

  int storedExp = 0;
  double storedPercentage = 0.0;
  int storedMeso = 0;

  // ROI 영역
  Rect? levelRect;
  Rect? expRect;
  Rect? mesoRect;

  // 타이머 텍스트 및 숫자 포맷
  String timerText = "00:00:00";
  final numberFormat = NumberFormat("#,###");

  Timer? _timer;

  final HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.backquote,
    modifiers: [HotKeyModifier.capsLock],
    scope: HotKeyScope.system,
  );

  // ============================================================
  // HELPER METHODS
  // ============================================================
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// _calculateAverage: 평균값(경험치, 퍼센티지, 메소)을 계산합니다.
  void _calculateAverage() {
    if (showAverage == Duration.zero || _elapsedTime.inSeconds <= 0) return;
    averageExp =
        ((totalExp / _elapsedTime.inSeconds) * showAverage.inSeconds).floor();
    averagePercentage =
        (totalPercentage / _elapsedTime.inSeconds) * showAverage.inSeconds;
    averageMeso =
        ((totalMeso / _elapsedTime.inSeconds) * showAverage.inSeconds).floor();
  }

  /// _formatDuration: Duration을 HH:MM:SS 형식의 문자열로 변환합니다.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours.remainder(60));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // ============================================================
  // CONFIG 관련 메소드
  // ============================================================
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

  Future<void> _saveConfig() async {
    final file = await _getConfigFile();
    final Offset position = await windowManager.getPosition();
    Map<String, dynamic> config = {
      "position": {
        "x": position.dx,
        "y": position.dy,
      },
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
      "updateInterval": updateInterval.inSeconds,
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

      if (config["position"] != null && config["position"] is Map) {
        final pos = config["position"] as Map<String, dynamic>;
        final newPos = Offset(
          (pos["x"] ?? 0).toDouble(),
          (pos["y"] ?? 0).toDouble(),
        );
        safeLog("Setting window position to: $newPos");
        await windowManager.setPosition(newPos);
      }

      _safeSetState(() {
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
        updateInterval = Duration(seconds: config["updateInterval"] ?? 1);
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

  // ============================================================
  // 서버 통신 및 초기화 관련 메소드
  // ============================================================
  Future<void> _initializeApp() async {
    try {
      await _expDataLoader.loadExpData();
      await _loadConfig();
      await _handleServerInitialization();
    } catch (e, stack) {
      await safeLog("초기화 중 오류 발생: $e\n$stack");
      exit(1);
    } finally {
      _safeSetState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> _handleServerInitialization() async {
    _safeSetState(() {
      isInitializing = true;
    });
    try {
      safeLog("서버 헬스체크 시작");
      await _waitForServerReady();
      safeLog("서버 헬스체크 완료, ROI 전송 시작");
      if (levelRect != null && expRect != null) {
        await sendROIToServer();
        _safeSetState(() {
          isRoiSet = true;
        });
        safeLog("ROI Sent to Server");
      } else {
        safeLog("No ROI data, skipping ROI send");
      }
    } catch (e, stack) {
      await safeLog("Server initialization error: $e\nStackTrace: $stack");
      exit(1);
    } finally {
      _safeSetState(() {
        isInitializing = false;
      });
    }
  }

  Future<bool> checkServerReady() async {
    try {
      final response =
          await http.get(Uri.parse("http://127.0.0.1:5000/health"));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e, stack) {
        await safeLog(
            "예외 발생 during waitForServerReady: $e\nStackTrace: $stack");
        exit(1);
      }
    }
  }

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
        levelRect!.bottom,
      ],
      "exp": [
        expRect!.left,
        expRect!.top,
        expRect!.right,
        expRect!.bottom,
      ],
    };
    if (mesoRect != null) {
      roiData["meso"] = [
        mesoRect!.left,
        mesoRect!.top,
        mesoRect!.right,
        mesoRect!.bottom,
      ];
    }
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(roiData));
      if (response.statusCode == 200) {
        _safeSetState(() {
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

  // ============================================================
  // 데이터 업데이트: 서버에서 fetch한 데이터를 기반으로 일반 수치와 평균값을 동시에 업데이트
  // ============================================================
  Future<void> _updateData({required bool fetchData}) async {
    if (fetchData) {
      try {
        // EXP 데이터 fetch
        final expResponse = await http
            .get(Uri.parse('http://127.0.0.1:5000/extract_exp_and_level'));
        if (expResponse.statusCode != 200) {
          throw Exception("Failed to fetch EXP data");
        }
        final expData = json.decode(expResponse.body);
        int exp = expData['exp'];
        double percentage = expData['percentage'];
        int level = expData['level'];

        // Meso 데이터 fetch (선택적)
        Map<String, dynamic>? mesoData;
        if (showMeso) {
          final mesoResponse =
              await http.get(Uri.parse('http://127.0.0.1:5000/extract_meso'));
          if (mesoResponse.statusCode == 200) {
            mesoData = json.decode(mesoResponse.body);
          } else {
            throw Exception("Failed to fetch Meso data");
          }
        }

        _safeSetState(() {
          // EXP 데이터 업데이트
          if (initialLevel == 0) {
            initialLevel = level;
            initialExp = exp;
            initialPercentage = percentage;
            isInitValueInserted = true;
          } else {
            // 레벨 업
            if (level > lastLevel &&
                ((level - lastLevel) == 1 || (level - lastLevel) == 2)) {
              int levelUpExp = _expDataLoader.getExpForLevel(lastLevel);
              expBeforeLevelUp = levelUpExp - lastExp + totalExp;
              percentageBeforeLevelUp = 100 - lastPercentage + totalPercentage;
              initialExp = 0;
              initialPercentage = 0.0;
              lastLevel = level;
            }
            totalExp = exp - initialExp + expBeforeLevelUp + storedExp;
            totalPercentage = percentage -
                initialPercentage +
                percentageBeforeLevelUp +
                storedPercentage;
            lastExp = exp;
            lastPercentage = percentage;
            lastLevel = level;
          }
          // Meso 데이터 업데이트
          if (mesoData != null) {
            int meso = mesoData['meso'];
            if (initialMeso == 0) {
              initialMeso = meso;
            } else {
              totalMeso = meso - initialMeso + storedMeso;
            }
          }
          // 동시에 평균 계산 및 타이머 텍스트 업데이트
          _calculateAverage();
          timerText = _formatDuration(_elapsedTime);
        });
      } catch (e) {
        safeLog("[Server] Error updating data: $e");
      }
    } else {
      // fetchData가 false이면, 단순히 평균과 타이머 텍스트만 업데이트 (설정 화면 등)
      _safeSetState(() {
        _calculateAverage();
        timerText = _formatDuration(_elapsedTime);
      });
    }
  }

  // ============================================================
  // 타이머 관련 메소드
  // ============================================================
  Future<void> _startTimer() async {
    _safeSetState(() {
      isRunning = true;
    });

    // 초기 데이터 fetch 및 UI 업데이트
    await _updateData(fetchData: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _safeSetState(() {
        _elapsedTime += const Duration(seconds: 1);
        timerText = _formatDuration(_elapsedTime);
      });
      // updateInterval마다 서버 데이터를 fetch하여 업데이트
      if (_elapsedTime.inSeconds % updateInterval.inSeconds == 0) {
        await _updateData(fetchData: true);
      }
      if (timerEndTime != Duration.zero && _elapsedTime >= timerEndTime) {
        _audioPlayer.play(AssetSource('timer_alarm.mp3'));
        await _stopTimer();
      }
    });
  }

  Future<void> _stopTimer() async {
    // 타이머 종료 전 최신 데이터 fetch 및 업데이트
    await _updateData(fetchData: true);
    _safeSetState(() {
      isRunning = false;
      initialExp = 0;
      initialPercentage = 0;
      initialLevel = 0;
      initialMeso = 0;
      storedExp = totalExp;
      storedPercentage = totalPercentage;
      storedMeso = totalMeso;
    });
    _timer?.cancel();
  }

  void _resetTimer() {
    _safeSetState(() {
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

      storedExp = 0;
      storedPercentage = 0;
      storedMeso = 0;

      timerText = _formatDuration(_elapsedTime);
    });
    _timer?.cancel();
  }

  // ============================================================
  // 네비게이션 및 기타 UI 이벤트
  // ============================================================
  void _openSettingsScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          isRunning: isRunning,
          updateInterval: updateInterval,
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
      _safeSetState(() {
        updateInterval = result['updateInterval'];
        timerEndTime = result['timerEndTime'];
        showAverage = result['showAverage'];
        showMeso = result['showMeso'];
      });
      // 설정 화면에서 돌아올 때는 fetch 없이 평균/타이머만 업데이트
      await _updateData(fetchData: false);
      _saveConfig();
    }
  }

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
      _safeSetState(() {
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
      _safeSetState(() {
        mesoRect = result['meso'];
      });
      _saveConfig();
      sendROIToServer();
    }
  }

  void _launchURL() async {
    final Uri url =
        Uri.parse("https://github.com/woogyeom/Flutter-Python-EXP-Tracker");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch $url";
    }
  }

  // ============================================================
  // Lifecycle & Window 이벤트
  // ============================================================
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
    _registerHotKey();
  }

  @override
  void dispose() {
    safeLog('dispose');
    windowManager.removeListener(this);
    _timer?.cancel();
    hotKeyManager.unregisterAll();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    safeLog("Closing app...");
    await widget.serverManager.shutdownServer();
    windowManager.close();
  }

  void _registerHotKey() async {
    await hotKeyManager.register(
      _hotKey,
      keyDownHandler: (hotKey) {
        if (isRunning) {
          _stopTimer();
        } else {
          if (!isRoiSet) {
            return;
          }
          _startTimer();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: isRunning
          ? CupertinoColors.darkBackgroundGray.withAlpha(150)
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
                  child: const Icon(
                    CupertinoIcons.info,
                    color: CupertinoColors.systemGrey6,
                    size: 24,
                  ),
                ),
                SizedBox(
                  width: 148,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          value: showMeso,
                          onChanged: (bool value) async {
                            _safeSetState(() {
                              showMeso = value;
                            });
                            _saveConfig();
                            _safeSetState(() {
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
                          activeThumbImage: const AssetImage('assets/meso.png'),
                          inactiveThumbImage:
                              const AssetImage('assets/meso.png'),
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    _resetTimer();
                  },
                  child: const Icon(
                    CupertinoIcons.restart,
                    color: CupertinoColors.systemGrey6,
                    size: 24,
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
                  onPressed: () async {
                    await _saveConfig();
                    await widget.serverManager.shutdownServer();
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
                                ? null
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
                                      _startTimer();
                                    }
                                  },
                            color: isInitializing
                                ? CupertinoColors.systemGrey
                                : !isRoiSet
                                    ? CupertinoColors.systemGrey
                                    : isRunning
                                        ? CupertinoColors.systemRed
                                        : (_elapsedTime == Duration.zero)
                                            ? CupertinoColors.systemGreen
                                            : CupertinoColors.systemYellow,
                            borderRadius: BorderRadius.circular(12),
                            child: isInitializing
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white)
                                : Icon(
                                    !isRoiSet
                                        ? CupertinoIcons.crop
                                        : isRunning
                                            ? CupertinoIcons.pause_fill
                                            : CupertinoIcons.play_arrow_solid,
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
                  // 경험치 UI
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            !isInitValueInserted
                                ? '? [?.??%]'
                                : '${numberFormat.format(totalExp)} [${totalPercentage.toStringAsFixed(2)}%]',
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
                              !isInitValueInserted
                                  ? '? [?.??%] / ${showAverage.inMinutes}분'
                                  : '${numberFormat.format(averageExp)} [${averagePercentage.toStringAsFixed(2)}%] / ${showAverage.inMinutes}분',
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
                  // 메소 UI
                  if (showMeso)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              !isInitValueInserted
                                  ? '???? 메소'
                                  : '${numberFormat.format(totalMeso)} 메소',
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
                                !isInitValueInserted
                                    ? '???? 메소 / ${showAverage.inMinutes}분'
                                    : '${numberFormat.format(averageMeso)} 메소 / ${showAverage.inMinutes}분',
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
