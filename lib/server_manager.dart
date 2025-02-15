import 'dart:io';
import 'package:flutter_exp_timer/log.dart';
import 'package:http/http.dart' as http;

class ServerManager {
  // FastAPI 서버 실행 (비동기)
  Future<void> startServer() async {
    String serverPath = "server/ocr_server.exe"; // FastAPI 서버 실행 파일 경로

    // 서버가 이미 실행 중인지 확인
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:5000'));
      if (response.statusCode == 200) {
        safeLog("FastAPI 서버가 이미 실행 중입니다.");
        return;
      }
    } catch (e) {
      safeLog("FastAPI 서버가 실행 중이 아닙니다. 실행을 시작합니다...");
    }

    // FastAPI 서버 실행
    try {
      // Process.run("cmd", ["/c", "start", serverPath]); // cmd 창에서 실행
      Process.start(serverPath, [], mode: ProcessStartMode.detached);
      safeLog("FastAPI 서버가 콘솔 창에서 실행되었습니다.");
    } catch (e) {
      safeLog("FastAPI 서버 실행 중 오류 발생: $e");
    }
  }

  // FastAPI 서버 종료 (정상 종료 엔드포인트 호출)
  Future<void> shutdownServer() async {
    try {
      safeLog("Shutting down FastAPI server via shutdown endpoint...");
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/shutdown'));
      safeLog("Shutdown response: ${response.body}");
    } catch (e) {
      safeLog("Error shutting down the server: $e");
    }
  }
}
