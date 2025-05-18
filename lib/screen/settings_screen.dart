import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_exp_timer/main.dart';

class SettingsScreen extends StatefulWidget {
  final bool isRunning;
  final Duration updateInterval;
  final Duration timerEndTime;
  final Duration showAverage;
  final AudioPlayer audioPlayer;
  final bool showMeso;
  final bool showExpectedTime;

  const SettingsScreen({
    Key? key,
    required this.isRunning,
    required this.updateInterval,
    required this.timerEndTime,
    required this.showAverage,
    required this.audioPlayer,
    required this.showMeso,
    required this.showExpectedTime,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WindowListener {
  int _selectedOption0 = 0;
  int _selectedOption1 = 0;
  int _selectedOption2 = 0;
  double currentVolume = 0.5;
  late AudioPlayer _audioPlayer;
  bool showMeso = false;
  bool showExpectedTime = false;

  @override
  void initState() {
    _selectedOption0 =
        _getSelectedUpdateIntervalFromDuration(widget.updateInterval);
    _selectedOption1 = _getSelectedOptionFromDuration(widget.timerEndTime);
    _selectedOption2 = _getSelectedOptionFromDuration(widget.showAverage);
    _audioPlayer = widget.audioPlayer;
    currentVolume = _audioPlayer.volume;
    showMeso = widget.showMeso;
    showExpectedTime = widget.showExpectedTime;

    windowManager.setSize(Size(appSize.width, 300));

    super.initState();
  }

  @override
  void dispose() {
    // SettingsScreen 나갈 때 원래 창 크기로 복원
    if (showMeso) windowManager.setSize(Size(appSize.width, 250));
    if (!showMeso) windowManager.setSize(appSize);
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 업데이트 주기 Duration 값을 각 옵션에 해당하는 정수로 변환합니다.
  int _getSelectedUpdateIntervalFromDuration(Duration duration) {
    if (duration == Duration(seconds: 1)) return 0;
    if (duration == const Duration(seconds: 5)) return 1;
    if (duration == const Duration(seconds: 15)) return 2;
    if (duration == const Duration(seconds: 30)) return 3;
    if (duration == const Duration(minutes: 1)) return 4;
    return 0;
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

  /// 선택된 옵션 값에 따라 업데이트 주기기 Duration을 반환합니다.
  Duration _durationFromSelectedUpdateInterval(int option) {
    switch (option) {
      case 1:
        return const Duration(seconds: 5);
      case 2:
        return const Duration(seconds: 15);
      case 3:
        return const Duration(seconds: 30);
      case 4:
        return const Duration(minutes: 1);
      default:
        return Duration(seconds: 1); // 무한 또는 없음
    }
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
    final selectedDuration0 =
        _durationFromSelectedUpdateInterval(_selectedOption0);
    final selectedDuration1 = _durationFromSelectedOption(_selectedOption1);
    final selectedDuration2 = _durationFromSelectedOption(_selectedOption2);
    Navigator.pop(context, {
      'updateInterval': selectedDuration0,
      'timerEndTime': selectedDuration1,
      'showAverage': selectedDuration2,
      'showMeso': showMeso,
      'showExpectedTime': showExpectedTime,
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
            const SizedBox(height: 14),
            // 상단 버튼 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  appVersion,
                  style: GoogleFonts.notoSans(
                    textStyle: const TextStyle(
                      color: CupertinoColors.systemGrey6,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PressableIcon(
                  icon: CupertinoIcons.arrow_uturn_left_circle_fill,
                  color: CupertinoColors.systemRed,
                  size: 24,
                  onPressed: _closeSettings,
                ),
                const SizedBox(width: 18),
              ],
            ),
            const SizedBox(height: 4),
            // 상단 버튼 영역을 제외한 나머지 공간을 Options 영역이 차지하도록 Expanded 사용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 업데이트 주기
                    Text(
                      "업데이트 주기",
                      style: GoogleFonts.notoSans(
                        textStyle: const TextStyle(
                          color: CupertinoColors.systemGrey6,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    CupertinoSegmentedControl<int>(
                      padding: const EdgeInsets.all(4),
                      unselectedColor: CupertinoColors.darkBackgroundGray,
                      groupValue: _selectedOption0,
                      children: {
                        0: _buildSegment("1초"),
                        1: _buildSegment("5초"),
                        2: _buildSegment("15초"),
                        3: _buildSegment("30초"),
                        4: _buildSegment("1분"),
                      },
                      onValueChanged: (int value) {
                        setState(() {
                          _selectedOption0 = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // 타이머 시간 옵션
                    Row(
                      children: [
                        Text(
                          "타이머 자동 정지",
                          style: GoogleFonts.notoSans(
                            textStyle: const TextStyle(
                              color: CupertinoColors.systemGrey6,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          type: MaterialType.transparency,
                          child: CustomCupertinoSlider(
                            value: currentVolume,
                            divisions: 10,
                            thumbRadius: 6.0,
                            onChanged: (double value) async {
                              setState(() {
                                currentVolume = value;
                              });
                              await _audioPlayer.setVolume(currentVolume);
                            },
                            audioPlayer: _audioPlayer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CupertinoSegmentedControl<int>(
                      padding: const EdgeInsets.all(4),
                      unselectedColor: CupertinoColors.darkBackgroundGray,
                      groupValue: _selectedOption1,
                      children: {
                        0: _buildSegment("안 함"),
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
                    // 평균 표시 옵션
                    Text(
                      "평균 표시",
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
                        0: _buildSegment("안 함"),
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
                    const SizedBox(height: 4),
                    // Add this new section
                    Row(
                      children: [
                        Text(
                          "N 시간 후 예상 시각 표시",
                          style: GoogleFonts.notoSans(
                            textStyle: const TextStyle(
                              color: CupertinoColors.systemGrey6,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.8,
                          child: CupertinoSwitch(
                            value: showExpectedTime,
                            activeTrackColor: CupertinoColors.systemBlue,
                            onChanged: (bool value) {
                              setState(() {
                                showExpectedTime = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Expanded(child: Container()),
                  ],
                ),
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

class PressableIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final VoidCallback onPressed;
  final Duration duration;
  final Color overlayColor;

  const PressableIcon({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 100),
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.1),
  }) : super(key: key);

  @override
  _PressableIconState createState() => _PressableIconState();
}

class _PressableIconState extends State<PressableIcon> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: widget.duration,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.color,
              size: widget.size,
            ),
            // 누를 때 회색 오버레이를 애니메이션으로 표시
            AnimatedOpacity(
              opacity: _isPressed ? 1.0 : 0.0,
              duration: widget.duration,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.overlayColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomCupertinoSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final double thumbRadius; // 원하는 thumb 크기를 반지름으로 지정
  final String label;
  final AudioPlayer audioPlayer;

  const CustomCupertinoSlider({
    Key? key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.thumbRadius = 10.0, // 기본 thumb 크기
    this.label = "",
    required this.audioPlayer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Material Slider에 SliderTheme를 적용해 thumb 크기와 색상 등 스타일을 지정합니다.
    return Row(
      children: [
        PressableIcon(
          icon: CupertinoIcons.play_circle_fill,
          color: CupertinoColors.systemBlue,
          size: 24,
          onPressed: () async {
            await audioPlayer.play(AssetSource('timer_alarm.mp3'));
          },
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 146, // 원하는 슬라이더 전체 너비
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              trackShape: NoPaddingTrackShape(), // 커스텀 트랙 모양 적용
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: thumbRadius * 2),
              activeTrackColor: CupertinoColors.systemBlue,
              inactiveTrackColor: CupertinoColors.systemGrey,
              thumbColor: CupertinoColors.systemBlue,
              overlayColor: CupertinoColors.systemBlue.withOpacity(0.3),
              tickMarkShape: const NoTickMarkShape(), // 틱마크를 숨김
              showValueIndicator: label == ""
                  ? ShowValueIndicator.never
                  : ShowValueIndicator.always,
            ),
            child: Slider(
              label: label,
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class NoPaddingTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2.0;
    // 좌우 패딩 없이 전체 width 사용
    final double trackLeft = offset.dx;
    final double trackWidth = parentBox.size.width;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class NoTickMarkShape extends SliderTickMarkShape {
  const NoTickMarkShape();

  @override
  Size getPreferredSize(
      {required SliderThemeData sliderTheme, bool? isEnabled}) {
    return Size.zero;
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Animation<double>? enableAnimation,
    Offset? thumbCenter,
    bool? isEnabled,
    TextDirection? textDirection,
  }) {
    // 아무것도 그리지 않음
  }
}
