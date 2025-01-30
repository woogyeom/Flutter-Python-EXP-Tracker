import 'dart:io';

class ServerManager {
  // FastAPI 서버 실행 (비동기)
  Future<void> startServer() async {
    try {
      print("Starting FastAPI server...");

      String executable = "ocr_server.exe";
      List<String> arguments = [];

      await Process.start(
        executable,
        arguments,
        mode: ProcessStartMode.detached, // 백그라운드 실행
      );

      print("FastAPI server started.");
    } catch (e) {
      print("Error starting the server: $e");
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
