import 'dart:io';
import 'package:http/http.dart' as http;

class ServerManager {
  // FastAPI 서버 실행 (비동기)
  Future<void> startServer() async {
    String serverPath = "server/ocr_server.exe"; // FastAPI 서버 실행 파일 경로

    // 서버가 이미 실행 중인지 확인
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000'));
      if (response.statusCode == 200) {
        print("FastAPI 서버가 이미 실행 중입니다.");
        return;
      }
    } catch (e) {
      print("FastAPI 서버가 실행 중이 아닙니다. 실행을 시작합니다...");
    }

    // FastAPI 서버 실행
    try {
      Process.run("cmd", ["/c", "start", serverPath]); // cmd 창에서 실행
      print("FastAPI 서버가 콘솔 창에서 실행되었습니다.");
    } catch (e) {
      print("FastAPI 서버 실행 중 오류 발생: $e");
    }
  }

  // FastAPI 서버 종료 (PID 없이 프로세스 이름으로 종료)
  void shutdownServer() {
    try {
      print("Shutting down FastAPI server...");

      // 🔹 실행된 프로세스를 이름으로 강제 종료
      String processName = "ocr_server.exe"; // 기본 실행 파일

      ProcessResult result =
          Process.runSync("taskkill", ["/F", "/IM", processName]);

      print("Taskkill result: ${result.stdout}");
      print("All server processes killed successfully.");
    } catch (e) {
      print("Error shutting down the server: $e");
    }
  }
}
