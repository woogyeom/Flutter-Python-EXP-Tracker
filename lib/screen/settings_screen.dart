import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

class SettingsScreen extends StatefulWidget {
  final bool isRunning;
  final Duration timerEndTime;
  final bool isAverage;

  const SettingsScreen({
    Key? key,
    required this.isRunning,
    required this.timerEndTime,
    required this.isAverage,
  }) : super(
          key: key,
        );

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WindowListener {
  int _selectedOption = 0;
  bool option1 = false;

  @override
  void initState() {
    super.initState();
    _setWindowSize();

    _selectedOption = _getSelectedOptionFromDuration(widget.timerEndTime);
    option1 = widget.isAverage;
  }

  int _getSelectedOptionFromDuration(Duration duration) {
    if (duration == Duration.zero) return 0; // 무한
    if (duration == Duration(minutes: 5)) return 1;
    if (duration == Duration(minutes: 15)) return 2;
    if (duration == Duration(minutes: 30)) return 3;
    if (duration == Duration(hours: 1)) return 4;
    return 0; // 기본값 (예외 처리)
  }

  Future<void> _setWindowSize() async {
    // 창 크기를 400x600으로 설정하고, 크기 변경을 제한할 수 있습니다.
    await windowManager.setSize(const Size(400, 200));
  }

  void _return() async {
    await windowManager.setSize(const Size(400, 200));

    Duration selectedDuration;
    switch (_selectedOption) {
      case 1:
        selectedDuration = Duration(minutes: 5);
        break;
      case 2:
        selectedDuration = Duration(minutes: 15);
        break;
      case 3:
        selectedDuration = Duration(minutes: 30);
        break;
      case 4:
        selectedDuration = Duration(hours: 1);
        break;
      default:
        selectedDuration = Duration.zero; // 무한(제한 없음)
    }

    Navigator.pop(
        context, {'timerEndTime': selectedDuration, 'isAverage': option1});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: widget.isRunning
          ? CupertinoColors.darkBackgroundGray.withAlpha(200)
          : CupertinoColors.darkBackgroundGray,
      child: DragToMoveArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),

            // 상단 닫기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _return();
                  },
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),

            // 옵션 리스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
                children: [
                  Text(
                    "타이머 시간",
                    style: GoogleFonts.notoSans(
                      textStyle: const TextStyle(
                        color: CupertinoColors.systemGrey6,
                        fontSize: 18, // 🔥 폰트 크기 증가
                      ),
                    ),
                  ),
                  CupertinoSegmentedControl<int>(
                    padding: EdgeInsets.all(8),
                    unselectedColor: CupertinoColors.darkBackgroundGray,
                    groupValue: _selectedOption, // 현재 선택된 값
                    children: {
                      0: Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox(
                          width: 60, // 🔥 개별 버튼 크기 고정
                          child: Center(
                            child: Text(
                              "무한",
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  color: CupertinoColors.systemGrey6,
                                  fontSize: 18, // 🔥 폰트 크기 증가
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      1: Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox(
                          width: 60,
                          child: Center(
                            child: Text(
                              "5분",
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  color: CupertinoColors.systemGrey6,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      2: Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox(
                          width: 60,
                          child: Center(
                            child: Text(
                              "15분",
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  color: CupertinoColors.systemGrey6,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      3: Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox(
                          width: 60,
                          child: Center(
                            child: Text(
                              "30분",
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  color: CupertinoColors.systemGrey6,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      4: Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox(
                          width: 60,
                          child: Center(
                            child: Text(
                              "1시간",
                              style: GoogleFonts.notoSans(
                                textStyle: const TextStyle(
                                  color: CupertinoColors.systemGrey6,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    },
                    onValueChanged: (int value) {
                      setState(() {
                        _selectedOption = value;
                      });
                    },
                  ),

                  SizedBox(height: 4),

                  // 옵션 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 200, // 🔥 텍스트 영역 크기 고정
                        child: Text(
                          '5분 평균 경험치 표시',
                          style: GoogleFonts.notoSans(
                            textStyle: const TextStyle(
                              color: CupertinoColors.systemGrey6,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: option1,
                        activeTrackColor: CupertinoColors.activeBlue,
                        inactiveTrackColor: CupertinoColors.systemGrey,
                        onChanged: (bool value) {
                          setState(() {
                            option1 = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
