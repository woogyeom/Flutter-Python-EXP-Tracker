import 'dart:convert';
import 'package:http/http.dart' as http;

class ExpFetcher {
  final String serverUrl;

  ExpFetcher(this.serverUrl);

  /// 서버에서 EXP 데이터 가져오기
  Future<Map<String, dynamic>> fetchExpData() async {
    try {
      // Python 서버에서 데이터 요청
      final response =
          await http.get(Uri.parse('$serverUrl/extract_exp_and_level')).timeout(
        Duration(seconds: 10), // 타임아웃 설정
        onTimeout: () {
          throw Exception("Request to server timed out");
        },
      );

      if (response.statusCode == 200) {
        // JSON 데이터 파싱
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey("exp")) {
          print("EXP data fetched successfully: $responseData");
          return {
            "exp": responseData["exp"],
            "percentage": responseData["percentage"] ?? 0.00,
            "level": responseData["level"] ?? 1
          };
        } else {
          print("No EXP data in response: $responseData");
          return {"error": "No EXP data in response"};
        }
      } else {
        print("Failed to fetch EXP data: ${response.statusCode}");
        return {"error": "Failed to fetch EXP data"};
      }
    } catch (e) {
      print("Error fetching EXP data: $e");
      return {"error": e.toString()};
    }
  }

  /// EXP 데이터를 UI에서 처리하기 위한 헬퍼 메서드
  Future<void> fetchAndDisplayExpData({
    required Function(int exp, double percentage, int level) onUpdate,
    required Function(String errorMessage) onError,
  }) async {
    try {
      final expData = await fetchExpData();
      if (expData.containsKey("error")) {
        onError(expData["error"]);
        return;
      }

      final expValue = expData['exp'] ?? 0;
      final expPercentage = expData['percentage'] ?? 0.00;
      final level = expData['level'] ?? 1;

      // 업데이트 콜백 호출
      onUpdate(expValue, expPercentage, level);
    } catch (e) {
      onError("Error fetching EXP data: $e");
    }
  }
}
