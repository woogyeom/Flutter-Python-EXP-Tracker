import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

class SettingsScreen extends StatefulWidget {
  final bool isRunning;
  final Duration timerEndTime;
  final Duration showAverageExp;

  const SettingsScreen({
    Key? key,
    required this.isRunning,
    required this.timerEndTime,
    required this.showAverageExp,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WindowListener {
  int _selectedOption1 = 0;
  int _selectedOption2 = 0;

  @override
  void initState() {
    super.initState();
    _selectedOption1 = _getSelectedOptionFromDuration(widget.timerEndTime);
    _selectedOption2 = _getSelectedOptionFromDuration(widget.showAverageExp);
  }

  /// Duration 값을 각 옵션에 해당하는 정수로 변환합니다.
  int _getSelectedOptionFromDuration(Duration duration) {
    if (duration == Duration.zero) return 0; // 무한 또는 없음
    if (duration == const Duration(minutes: 5)) return 1;
    if (duration == const Duration(minutes: 15)) return 2;
    if (duration == const Duration(minutes: 30)) return 3;
    if (duration == const Duration(hours: 1)) return 4;
    return 0;
  }

  /// 선택된 옵션 값에 따라 Duration을 반환합니다.
  Duration _durationFromSelectedOption(int option) {
    switch (option) {
      case 1:
        return const Duration(minutes: 5);
      case 2:
        return const Duration(minutes: 15);
      case 3:
        return const Duration(minutes: 30);
      case 4:
        return const Duration(hours: 1);
      default:
        return Duration.zero; // 무한 또는 없음
    }
  }

  /// 설정 화면 종료 후, 선택된 옵션을 반환합니다.
  Future<void> _closeSettings() async {
    final selectedDuration1 = _durationFromSelectedOption(_selectedOption1);
    final selectedDuration2 = _durationFromSelectedOption(_selectedOption2);
    Navigator.pop(context, {
      'timerEndTime': selectedDuration1,
      'showAverageExp': selectedDuration2,
    });
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
            const SizedBox(height: 4),
            // 상단 버튼 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Ver 1.1.1",
                  style: GoogleFonts.notoSans(
                    textStyle: const TextStyle(
                      color: CupertinoColors.systemGrey6,
                      fontSize: 16,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _closeSettings,
                  child: const Icon(
                    CupertinoIcons.arrow_uturn_left_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            // 옵션 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타이머 시간 옵션
                  Text(
                    "타이머 시간",
                    style: GoogleFonts.notoSans(
                      textStyle: const TextStyle(
                        color: CupertinoColors.systemGrey6,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CupertinoSegmentedControl<int>(
                    padding: const EdgeInsets.all(4),
                    unselectedColor: CupertinoColors.darkBackgroundGray,
                    groupValue: _selectedOption1,
                    children: {
                      0: _buildSegment("무한"),
                      1: _buildSegment("5분"),
                      2: _buildSegment("15분"),
                      3: _buildSegment("30분"),
                      4: _buildSegment("1시간"),
                    },
                    onValueChanged: (int value) {
                      setState(() {
                        _selectedOption1 = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // 평균 경험치 표시 옵션
                  Text(
                    "평균 경험치 표시",
                    style: GoogleFonts.notoSans(
                      textStyle: const TextStyle(
                        color: CupertinoColors.systemGrey6,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CupertinoSegmentedControl<int>(
                    padding: const EdgeInsets.all(4),
                    unselectedColor: CupertinoColors.darkBackgroundGray,
                    groupValue: _selectedOption2,
                    children: {
                      0: _buildSegment("없음"),
                      1: _buildSegment("5분"),
                      2: _buildSegment("15분"),
                      3: _buildSegment("30분"),
                      4: _buildSegment("1시간"),
                    },
                    onValueChanged: (int value) {
                      setState(() {
                        _selectedOption2 = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CupertinoSegmentedControl에서 사용하는 개별 세그먼트 위젯 생성 메서드
  Widget _buildSegment(String text) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 60,
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.notoSans(
              textStyle: const TextStyle(
                color: CupertinoColors.systemGrey6,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
