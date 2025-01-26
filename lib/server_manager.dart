import 'dart:io';
import 'dart:convert';

class ServerManager {
  // 서버 시작
  void startServer() {
    try {
      Process.start('ocr_server.exe', [], mode: ProcessStartMode.detached)
          .then((process) {
        process.stdout.transform(utf8.decoder).listen((data) {
          print("stdout: $data");
        });
        process.stderr.transform(utf8.decoder).listen((data) {
          print("stderr: $data");
        });
      });

      print('Server started successfully');
    } catch (e) {
      print('Error starting the server: $e');
    }
  }

  // 모든 'ocr_server.exe' 프로세스 종료
  void shutdownServer() {
    try {
      print("server shutting down");

      // 'ocr_server.exe' 프로세스 목록 가져오기
      var result = Process.runSync('tasklist', []);
      var processList = result.stdout.toString();

      if (processList.contains('ocr_server.exe')) {
        // 'ocr_server.exe' 프로세스가 있으면 강제 종료
        var killResult =
            Process.runSync('taskkill', ['/F', '/IM', 'ocr_server.exe']);
        print('Taskkill result: ${killResult.stdout}');

        // 종료가 완료되었을 때 출력
        if (killResult.exitCode == 0) {
          print('Server processes killed successfully');
        } else {
          print('Failed to kill server processes');
        }
      } else {
        print('No matching server processes found.');
      }
    } catch (e) {
      print('Error running taskkill: $e');
    }
  }
}
