import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class RectSelectScreen extends StatefulWidget {
  @override
  _RectSelectScreenState createState() => _RectSelectScreenState();
}

class _RectSelectScreenState extends State<RectSelectScreen> {
  Offset? startDrag;
  Offset? endDrag;
  Rect? levelRect;
  Rect? expRect;
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
        _screenSize = MediaQuery.of(context).size; // 업데이트된 화면 크기 적용
        _setContainerToCenter(); // 컨테이너 위치도 업데이트
      });
    });
  }

  void _setContainerToCenter() {
    _containerOffset = Offset(
      (_screenSize.width - _containerSize.width) / 2, // 가로 중앙 정렬
      (_screenSize.height - _containerSize.height) / 2, // 세로 중앙 정렬
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
        if (selectionStep == 0) {
          levelRect = rect;
          selectionStep = 1;
        } else {
          expRect = rect;
          _returnSelection();
        }
      });
    }
  }

  Future<void> _returnSelection() async {
    if (levelRect != null && expRect != null) {
      // 1. 현재 윈도우의 논리적 좌표 (예: top-left, width, height) 가져오기
      Rect windowLogicalBounds = await windowManager.getBounds();

      // 2. 현재 모니터의 devicePixelRatio (물리적/논리적) 가져오기
      //    (만약 다중 모니터 상황에서 올바른 값이 나오지 않는다면 플랫폼별 API를 통해 DPI 인식을 개선해야 합니다.)
      final double scale = View.of(context).devicePixelRatio;

      // 3. 윈도우의 좌표도 물리적 좌표로 변환
      Rect windowPhysicalBounds = Rect.fromLTWH(
        windowLogicalBounds.left * scale,
        windowLogicalBounds.top * scale,
        windowLogicalBounds.width * scale,
        windowLogicalBounds.height * scale,
      );

      // 4. 드래그로 얻은 ROI 좌표(논리적)를 물리적 좌표로 변환한 후, 윈도우의 물리적 좌표를 더합니다.
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

      await _exitFullScreen();

      // 이제 absoluteLevelRect, absoluteExpRect는 물리적 좌표이므로 서버에 전달하면 됨.
      Navigator.pop(
        context,
        {'level': absoluteLevelRect, 'exp': absoluteExpRect},
      );
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

      // 윈도우 화면을 벗어나지 않도록 제한
      _containerOffset = Offset(
        newDx.clamp(0, _screenSize.width - _containerSize.width),
        newDy.clamp(0, _screenSize.height - _containerSize.height),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size; // 현재 화면 크기 가져오기

    if (_containerOffset == null) {
      return SizedBox(); // 컨테이너 위치 설정 전에는 빈 위젯을 반환
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
              // 화면 전체 배경
              Container(color: CupertinoColors.transparent),
              if (levelRect != null)
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
              if (endDrag != null)
                Positioned.fromRect(
                  rect: Rect.fromPoints(startDrag!, endDrag!),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: selectionStep == 0
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                          width: 4),
                      color: CupertinoColors.transparent,
                    ),
                  ),
                ),

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
                      borderRadius: BorderRadius.circular(20), // 둥근 모서리
                      border: Border.all(
                        color: CupertinoColors.systemBlue, // 테두리 색상
                        width: 1, // 테두리 두께
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withAlpha(200), // 그림자 색상
                          blurRadius: 12, // 흐림 정도
                          spreadRadius: 2, // 그림자 퍼짐 정도
                          offset: Offset(3, 5), // 그림자의 위치
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          selectionStep == 0 ? "레벨 영역 선택" : "경험치 영역 선택",
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Image.asset(selectionStep == 0
                            ? 'assets/level_rect_sample.png'
                            : 'assets/exp_rect_sample.png'),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          selectionStep == 0 ? "숫자만 포함되게" : "경험치 바까지",
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
