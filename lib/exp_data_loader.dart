import 'dart:convert';
import 'package:flutter/services.dart'; // assets에서 데이터를 불러오기 위한 패키지

class ExpDataLoader {
  // 레벨별 필요 경험치를 저장하는 변수
  Map<int, int> levelExpData = {};

  // JSON 파일을 불러와서 딕셔너리로 저장하는 함수
  Future<void> loadExpData() async {
    // assets 폴더에서 JSON 파일 불러오기
    final String response =
        await rootBundle.loadString('assets/level_up_exp.json');
    final data = json.decode(response);

    // 불러온 JSON 데이터를 Map으로 변환하여 levelExpData에 저장
    // 값들이 String 타입으로 들어올 수 있기 때문에 int로 변환
    levelExpData = Map<int, int>.from(data.map((key, value) {
      return MapEntry(int.parse(key), int.parse(value.toString()));
    }));
  }

  int getExpForLevel(int level) {
    if (levelExpData.containsKey(level)) {
      return levelExpData[level]!;
    } else {
      // 해당 레벨이 없으면 기본 값 또는 예외를 반환
      throw Exception("레벨 $level의 경험치 데이터가 없습니다.");
    }
  }
}
