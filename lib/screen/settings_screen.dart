import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_exp_timer/main.dart';
import 'package:window_manager/window_manager.dart';

class SettingsScreen extends StatefulWidget {
  final bool isRunning;
  final Duration updateInterval;
  final Duration timerEndTime;
  final Duration showAverage;
  final bool showMeso;
  final bool showExpectedTime;

  const SettingsScreen({
    Key? key,
    required this.isRunning,
    required this.updateInterval,
    required this.timerEndTime,
    required this.showAverage,
    required this.showMeso,
    required this.showExpectedTime,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WindowListener {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2;

  int _selectedOption0 = 0;
  int _selectedOption1 = 0;
  int _selectedOption2 = 0;
  double currentVolume = 0.5;
  bool showMeso = false;
  bool showExpectedTime = false;

  @override
  void initState() {
    super.initState();
    _selectedOption0 = _getSelectedUpdateIntervalFromDuration(widget.updateInterval);
    _selectedOption1 = _getSelectedOptionFromDuration(widget.timerEndTime);
    _selectedOption2 = _getSelectedOptionFromDuration(widget.showAverage);
    showMeso = widget.showMeso;
    showExpectedTime = widget.showExpectedTime;
  }

  @override
  void dispose() {
    _pageController.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  int _getSelectedUpdateIntervalFromDuration(Duration duration) {
    if (duration == const Duration(seconds: 1)) return 0;
    if (duration == const Duration(seconds: 5)) return 1;
    if (duration == const Duration(seconds: 15)) return 2;
    if (duration == const Duration(seconds: 30)) return 3;
    if (duration == const Duration(minutes: 1)) return 4;
    return 0;
  }

  int _getSelectedOptionFromDuration(Duration duration) {
    if (duration == Duration.zero) return 0;
    if (duration == const Duration(minutes: 5)) return 1;
    if (duration == const Duration(minutes: 15)) return 2;
    if (duration == const Duration(minutes: 30)) return 3;
    if (duration == const Duration(hours: 1)) return 4;
    return 0;
  }

  Duration _durationFromSelectedUpdateInterval(int option) {
    switch (option) {
      case 1: return const Duration(seconds: 5);
      case 2: return const Duration(seconds: 15);
      case 3: return const Duration(seconds: 30);
      case 4: return const Duration(minutes: 1);
      default: return const Duration(seconds: 1);
    }
  }

  Duration _durationFromSelectedOption(int option) {
    switch (option) {
      case 1: return const Duration(minutes: 5);
      case 2: return const Duration(minutes: 15);
      case 3: return const Duration(minutes: 30);
      case 4: return const Duration(hours: 1);
      default: return Duration.zero;
    }
  }

  Future<void> _closeSettings() async {
    final selectedDuration0 = _durationFromSelectedUpdateInterval(_selectedOption0);
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
    const Size settingsDesignSize = Size(400, 200);

    return CupertinoPageScaffold(
      backgroundColor: widget.isRunning ? CupertinoColors.darkBackgroundGray.withAlpha(200) : CupertinoColors.darkBackgroundGray,
      child: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: settingsDesignSize.width,
          height: settingsDesignSize.height,
          child: DragToMoveArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(appVersion, style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 16))),
                    const SizedBox(width: 8),
                    PressableIcon(icon: CupertinoIcons.arrow_uturn_left_circle_fill, color: CupertinoColors.systemRed, size: 24, onPressed: _closeSettings),
                    const SizedBox(width: 18),
                  ],
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) {
                      setState(() { _currentPage = page; });
                    },
                    children: [
                      _buildPageOne(),
                      _buildPageTwo(),
                    ],
                  ),
                ),
                _buildNavigationControls(),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPageOne() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("업데이트 주기", style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 14))),
          CupertinoSegmentedControl<int>( padding: const EdgeInsets.all(2), unselectedColor: CupertinoColors.darkBackgroundGray, groupValue: _selectedOption0, children: {0: _buildSegment("1초"), 1: _buildSegment("5초"), 2: _buildSegment("15초"), 3: _buildSegment("30초"), 4: _buildSegment("1분")}, onValueChanged: (int value) { setState(() { _selectedOption0 = value; }); }),
          const SizedBox(height: 2),
          Text("타이머 자동 정지", style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 14))),
          const SizedBox(height: 2),
          CupertinoSegmentedControl<int>(padding: const EdgeInsets.all(2), unselectedColor: CupertinoColors.darkBackgroundGray, groupValue: _selectedOption1, children: {0: _buildSegment("안 함"), 1: _buildSegment("5분"), 2: _buildSegment("15분"), 3: _buildSegment("30분"), 4: _buildSegment("1시간")}, onValueChanged: (int value) { setState(() { _selectedOption1 = value; }); }),
        ],
      ),
    );
  }

  Widget _buildPageTwo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("평균 표시", style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 14))),
          const SizedBox(height: 4),
          CupertinoSegmentedControl<int>(padding: const EdgeInsets.all(2), unselectedColor: CupertinoColors.darkBackgroundGray, groupValue: _selectedOption2, children: {0: _buildSegment("안 함"), 1: _buildSegment("5분"), 2: _buildSegment("15분"), 3: _buildSegment("30분"), 4: _buildSegment("1시간")}, onValueChanged: (int value) { setState(() { _selectedOption2 = value; }); }),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("N 시간 후 예상 시각 표시", style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 14))),
              const SizedBox(width: 8),
              Transform.scale(scale: 0.8, child: CupertinoSwitch(value: showExpectedTime, activeTrackColor: CupertinoColors.systemBlue, onChanged: (bool value) { setState(() { showExpectedTime = value; }); })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _currentPage == 0 ? null : () { _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
          child: Icon(CupertinoIcons.left_chevron, size: 20, color: _currentPage == 0 ? CupertinoColors.inactiveGray : CupertinoColors.white),
        ),
        ...List.generate(_totalPages, (index) {
          return Container(
            width: 8.0,
            height: 8.0,
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? CupertinoColors.activeBlue : CupertinoColors.inactiveGray),
          );
        }),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _currentPage == _totalPages - 1 ? null : () { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
          child: Icon(CupertinoIcons.right_chevron, size: 20, color: _currentPage == _totalPages - 1 ? CupertinoColors.inactiveGray : CupertinoColors.white),
        ),
      ],
    );
  }

  Widget _buildSegment(String text) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 60,
        child: Center(child: Text(text, style: GoogleFonts.notoSans(textStyle: const TextStyle(color: CupertinoColors.systemGrey6, fontSize: 14)))),
      ),
    );
  }
}

// --- 아래 PressableIcon, CustomCupertinoSlider 등의 클래스는 기존 코드와 동일합니다. ---
class PressableIcon extends StatefulWidget {
  final IconData icon; final Color? color; final double size; final VoidCallback onPressed; final Duration duration; final Color overlayColor;
  const PressableIcon({Key? key, required this.icon, required this.onPressed, this.color, this.size = 24.0, this.duration = const Duration(milliseconds: 100), this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.1)}) : super(key: key);
  @override _PressableIconState createState() => _PressableIconState();
}
class _PressableIconState extends State<PressableIcon> {
  bool _isPressed = false;
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) { setState(() { _isPressed = true; }); },
      onTapUp: (_) { setState(() { _isPressed = false; }); },
      onTapCancel: () { setState(() { _isPressed = false; }); },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: widget.duration,
        child: Stack(alignment: Alignment.center, children: [
          Icon(widget.icon, color: widget.color, size: widget.size),
          AnimatedOpacity(opacity: _isPressed ? 1.0 : 0.0, duration: widget.duration, child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.overlayColor))),
        ]),
      ),
    );
  }
}
class NoPaddingTrackShape extends RoundedRectSliderTrackShape {
  @override Rect getPreferredRect({required RenderBox parentBox, Offset offset = Offset.zero, required SliderThemeData sliderTheme, bool isEnabled = false, bool isDiscrete = false}) {
    final double trackHeight = sliderTheme.trackHeight ?? 2.0; final double trackLeft = offset.dx; final double trackWidth = parentBox.size.width; final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2; return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
class NoTickMarkShape extends SliderTickMarkShape {
  const NoTickMarkShape();
  @override Size getPreferredSize({required SliderThemeData sliderTheme, bool? isEnabled}) { return Size.zero; }
  @override void paint(PaintingContext context, Offset center, {required RenderBox parentBox, required SliderThemeData sliderTheme, Animation<double>? enableAnimation, Offset? thumbCenter, bool? isEnabled, TextDirection? textDirection}) {}
}