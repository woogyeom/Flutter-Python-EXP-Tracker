import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  Duration showAverageExp = Duration.zero;
  bool isServerRunning = false;
  bool isErrorShown = false;
  bool isRoiSet = false;
  bool isConfigLoaded = false;

  String timerText = "00:00:00";
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  int initialExp = 0;
  double initialPercentage = 0.00;
  int lastExp = 0;
  double lastPercentage = 0.00;
  int lastLevel = 0;
  int totalExp = 0;
  double totalPercentage = 0.00;
  int averageExp = 0;
  double averagePercentage = 0.00;

  Duration timerEndTime = Duration.zero;

  Rect? levelRect;
  Rect? expRect;

  final numberFormat = NumberFormat("#,###");

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    expDataLoader.loadExpData();
    _loadConfig();

    _audioPlayer.setVolume(0.5);
  }

  @override
  void dispose() {
    print('dispose');
    windowManager.removeListener(this);
    super.dispose();
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
      "timerEndTime": timerEndTime.inSeconds,
      "volume": _audioPlayer.volume,
      "showAverageExp": showAverageExp.inSeconds,
    };
    try {
      await file.writeAsString(jsonEncode(config));
      print("Config saved: ${jsonEncode(config)}");
    } catch (e) {
      print("Error saving config: $e");
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
          print("Empty config, skipping further config load.");
          setState(() {
            isConfigLoaded = true;
          });
          return;
        }

        setState(() {
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
          timerEndTime = Duration(seconds: config["timerEndTime"]);
          _audioPlayer.setVolume(config["volume"]);
          showAverageExp = Duration(seconds: config["showAverageExp"]);
        });
        print("Config loaded: $config");

        // levelRect와 expRect가 모두 설정되어 있을 때만 ROI 전송
        if (levelRect != null && expRect != null) {
          await waitForServerReady();
          await sendROIToServer();
          print("ROI Sent to Server");
        } else {
          print("No ROI data");
        }

        setState(() {
          isConfigLoaded = true;
        });
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
      print("Error loading config: $e");
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
      // print("서버 준비 상태 확인 중 오류 발생: $e");
    }
    return false;
  }

  Future<void> waitForServerReady({int timeoutSeconds = 30}) async {
    final startTime = DateTime.now();
    while (true) {
      if (await checkServerReady()) {
        print("서버 준비 완료");
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
      print("ROI 데이터가 설정되지 않았습니다.");
      return;
    }

    final url = Uri.parse("http://127.0.0.1:5000/set_roi");

    final body = jsonEncode({
      "level": [
        levelRect!.left,
        levelRect!.top,
        levelRect!.right,
        levelRect!.bottom
      ],
      "exp": [expRect!.left, expRect!.top, expRect!.right, expRect!.bottom],
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        setState(() {
          isRoiSet = true;
        });
        print("ROI 데이터 성공적으로 서버에 전송됨: ${response.body}");
      } else {
        print("서버 오류: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("ROI 전송 중 오류 발생: $e");
    }
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

          if (level != lastLevel &&
              (level - lastLevel == 1 || level - lastLevel == 2)) {
            int levelUpExp = expDataLoader.getExpForLevel(lastLevel);

            print("Level Up Detected!");
            print("Previous Level: $lastLevel");
            print("New Level: $level");
            print("Last Exp: $lastExp");
            print("Exp Required for Last Level: $levelUpExp");
            print("Current Exp: $exp");

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
          if (showAverageExp != Duration.zero) {
            averageExp =
                ((totalExp / _elapsedTime.inSeconds) * showAverageExp.inSeconds)
                    .floor();
            averagePercentage = (totalPercentage / _elapsedTime.inSeconds) *
                showAverageExp.inSeconds;
          }
        });
      } else {
        throw Exception("Failed to fetch EXP data");
      }
    } catch (e) {
      print("[Server] Error fetching EXP data: $e");
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

      if (timerEndTime != Duration.zero && _elapsedTime >= timerEndTime) {
        _audioPlayer.play(AssetSource('timer_alarm.mp3'));
        _stopTimer();
      }
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
      lastLevel = 0;
      lastExp = 0;
      lastPercentage = 0.00;
      averageExp = 0;
      averagePercentage = 0.00;
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

  // 설정 화면 열기
  void _openSettingsScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          isRunning: isRunning,
          timerEndTime: timerEndTime,
          showAverageExp: showAverageExp,
          audioPlayer: _audioPlayer,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (result != null) {
      setState(() {
        timerEndTime = result['timerEndTime'];
        showAverageExp = result['showAverageExp'];
      });
      _saveConfig(); // 변경된 설정 저장
    }
  }

  // 영역 선택 스크린 열기
  void _openRectSelectScreen() async {
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
      setState(() {
        levelRect = result['level'];
        expRect = result['exp'];
      });
      _saveConfig(); // ROI 정보 저장
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
    print("Closing app...");
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
                const SizedBox(width: 192),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openRectSelectScreen,
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
                                initialExp = totalExp;
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
                  // EXP 텍스트 영역
                  Text(
                    '${numberFormat.format(totalExp)} [${totalPercentage.toStringAsFixed(2)}%]',
                    style: GoogleFonts.notoSans(
                      textStyle: const TextStyle(
                        color: CupertinoColors.systemYellow,
                        fontWeight: FontWeight.w400,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  if (showAverageExp != Duration.zero)
                    Text(
                      '${numberFormat.format(averageExp)} [${averagePercentage.toStringAsFixed(2)}%]',
                      style: GoogleFonts.notoSans(
                        textStyle: const TextStyle(
                          color: CupertinoColors.systemYellow,
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
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
