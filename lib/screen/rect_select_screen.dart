import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class RectSelectScreen extends StatefulWidget {
  final bool isMeso; // 메소 전용 모드 여부

  const RectSelectScreen({Key? key, this.isMeso = false}) : super(key: key);

  @override
  _RectSelectScreenState createState() => _RectSelectScreenState();
}

class _RectSelectScreenState extends State<RectSelectScreen> {
  Offset? startDrag;
  Offset? endDrag;
  Rect? levelRect;
  Rect? expRect;
  Rect? singleRect; // 메소 모드에서 단일 Rect를 저장

  // level/exp 모드에서만 사용됨
  int selectionStep = 0;

  Offset? _containerOffset; // 컨테이너 초기 위치
  Offset? _dragStartOffset;
  late Size _screenSize;
  final Size _containerSize = Size(300, 180);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setFullScreen();
      setState(() {
        _screenSize = MediaQuery.of(context).size;
        _setContainerToCenter();
      });
    });
  }

  void _setContainerToCenter() {
    _containerOffset = Offset(
      (_screenSize.width - _containerSize.width) / 2,
      (_screenSize.height - _containerSize.height) / 2,
    );
  }

  Future<void> _setFullScreen() async {
    await windowManager.setFullScreen(true);
  }

  Future<void> _exitFullScreen() async {
    await windowManager.setFullScreen(false);
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      startDrag = details.globalPosition;
      endDrag = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      endDrag = details.globalPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (startDrag != null && endDrag != null) {
      Rect rect = Rect.fromPoints(startDrag!, endDrag!);

      setState(() {
        if (widget.isMeso) {
          // 메소 모드: 단일 Rect 선택 후 바로 반환
          singleRect = rect;
          _returnSelection();
        } else {
          // 기본 모드: 첫번째 선택은 level, 두번째 선택은 exp
          if (selectionStep == 0) {
            levelRect = rect;
            selectionStep = 1;
          } else {
            expRect = rect;
            _returnSelection();
          }
        }
      });
    }
  }

  Future<void> _returnSelection() async {
    // 1. 현재 윈도우의 논리적 좌표 가져오기
    Rect windowLogicalBounds = await windowManager.getBounds();
    // 2. 현재 모니터의 devicePixelRatio 가져오기
    final double scale = View.of(context).devicePixelRatio;
    // 3. 윈도우 좌표를 물리적 좌표로 변환
    Rect windowPhysicalBounds = Rect.fromLTWH(
      windowLogicalBounds.left * scale,
      windowLogicalBounds.top * scale,
      windowLogicalBounds.width * scale,
      windowLogicalBounds.height * scale,
    );

    await _exitFullScreen();

    if (widget.isMeso) {
      // 메소 모드: 단일 Rect 변환
      Rect absoluteRect = Rect.fromLTRB(
        (singleRect!.left * scale) + windowPhysicalBounds.left,
        (singleRect!.top * scale) + windowPhysicalBounds.top,
        (singleRect!.right * scale) + windowPhysicalBounds.left,
        (singleRect!.bottom * scale) + windowPhysicalBounds.top,
      );
      Navigator.pop(context, {'meso': absoluteRect});
    } else {
      // 기본 모드: 레벨과 경험치 Rect 변환
      Rect absoluteLevelRect = Rect.fromLTRB(
        (levelRect!.left * scale) + windowPhysicalBounds.left,
        (levelRect!.top * scale) + windowPhysicalBounds.top,
        (levelRect!.right * scale) + windowPhysicalBounds.left,
        (levelRect!.bottom * scale) + windowPhysicalBounds.top,
      );

      Rect absoluteExpRect = Rect.fromLTRB(
        (expRect!.left * scale) + windowPhysicalBounds.left,
        (expRect!.top * scale) + windowPhysicalBounds.top,
        (expRect!.right * scale) + windowPhysicalBounds.left,
        (expRect!.bottom * scale) + windowPhysicalBounds.top,
      );
      Navigator.pop(
          context, {'level': absoluteLevelRect, 'exp': absoluteExpRect});
    }
  }

  /// 컨테이너 드래그 시작
  void _onContainerDragStart(DragStartDetails details) {
    _dragStartOffset = details.globalPosition - _containerOffset!;
  }

  /// 컨테이너 드래그 중
  void _onContainerDragUpdate(DragUpdateDetails details) {
    setState(() {
      double newDx = details.globalPosition.dx - _dragStartOffset!.dx;
      double newDy = details.globalPosition.dy - _dragStartOffset!.dy;
      _containerOffset = Offset(
        newDx.clamp(0, _screenSize.width - _containerSize.width),
        newDy.clamp(0, _screenSize.height - _containerSize.height),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    if (_containerOffset == null) {
      return SizedBox();
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.darkBackgroundGray.withAlpha(200),
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: [
              // 배경
              Container(color: CupertinoColors.transparent),
              // 선택된 영역 표시 (드래그 중인 영역)
              if (startDrag != null && endDrag != null)
                Positioned.fromRect(
                  rect: Rect.fromPoints(startDrag!, endDrag!),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isMeso
                            ? CupertinoColors.systemOrange
                            : (selectionStep == 0
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed),
                        width: 4,
                      ),
                      color: CupertinoColors.transparent,
                    ),
                  ),
                ),
              // 이미 선택한 영역 (기본 모드에서 레벨 영역)
              if (!widget.isMeso && levelRect != null)
                Positioned.fromRect(
                  rect: levelRect!,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: CupertinoColors.systemGreen, width: 4),
                      color: CupertinoColors.transparent,
                    ),
                  ),
                ),
              // 중앙 컨테이너 (설명용)
              Positioned(
                top: _containerOffset!.dy,
                left: _containerOffset!.dx,
                child: GestureDetector(
                  onPanStart: _onContainerDragStart,
                  onPanUpdate: _onContainerDragUpdate,
                  child: Container(
                    width: _containerSize.width,
                    height: _containerSize.height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CupertinoColors.darkBackgroundGray.withAlpha(170),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.systemBlue,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withAlpha(200),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(3, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.isMeso
                              ? "메소 영역 선택"
                              : (selectionStep == 0 ? "레벨 영역 선택" : "경험치 영역 선택"),
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Image.asset(widget.isMeso
                            ? 'assets/exp_rect_sample.png'
                            : (selectionStep == 0
                                ? 'assets/level_rect_sample.png'
                                : 'assets/exp_rect_sample.png')),
                        SizedBox(height: 8),
                        Text(
                          widget.isMeso
                              ? "메소 ROI 선택 (옵션)"
                              : (selectionStep == 0 ? "숫자만 포함되게" : "경험치 바까지"),
                          style: TextStyle(
                            color: CupertinoColors.systemYellow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
