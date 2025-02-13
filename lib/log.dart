import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:synchronized/synchronized.dart';

final Lock _logLock = Lock();

/// 3일보다 오래된 로그 파일들을 삭제하는 함수
Future<void> _cleanupOldLogs() async {
  final directory = Directory("C:\\temp\\MaplelandEXPTracker");
  if (!await directory.exists()) return;
  final now = DateTime.now();
  final files = directory.listSync();
  for (var file in files) {
    if (file is File && file.path.contains("client_log_")) {
      // 파일명 형식: client_log_YYYY-MM-DD.txt
      final baseName = file.uri.pathSegments.last;
      final regex = RegExp(r'client_log_(\d{4}-\d{2}-\d{2})\.txt');
      final match = regex.firstMatch(baseName);
      if (match != null) {
        final fileDateStr = match.group(1);
        try {
          final fileDate = DateTime.parse(fileDateStr!);
          if (now.difference(fileDate).inDays > 3) {
            await file.delete();
          }
        } catch (e) {
          // 날짜 파싱 오류가 발생하면 무시합니다.
        }
      }
    }
  }
}

/// safeLog() 함수는 날짜별 로그 파일에 로그를 기록합니다.
Future<void> safeLog(String message) async {
  await _logLock.synchronized(() async {
    final now = DateTime.now();
    final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final logMessage = "$formattedDateTime - $message\n";

    final directory = Directory("C:\\temp\\MaplelandEXPTracker");
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 매일 다른 로그 파일 생성: client_log_YYYY-MM-DD.txt
    final logFileName =
        "client_log_${DateFormat('yyyy-MM-dd').format(now)}.txt";
    final filePath = "${directory.path}\\$logFileName";
    final file = File(filePath);

    // 로그 파일이 없으면 BOM과 함께 생성
    if (!await file.exists()) {
      await file.writeAsString('\uFEFF', encoding: utf8);
    } else {
      // 파일이 있으면 BOM이 포함되어 있는지 확인
      final bytes = await file.readAsBytes();
      if (bytes.length < 3 ||
          bytes[0] != 0xEF ||
          bytes[1] != 0xBB ||
          bytes[2] != 0xBF) {
        final newBytes = <int>[0xEF, 0xBB, 0xBF] + bytes;
        await file.writeAsBytes(newBytes, mode: FileMode.write);
      }
    }

    // 3일보다 오래된 로그 파일 삭제
    await _cleanupOldLogs();

    await file.writeAsString(logMessage, mode: FileMode.append, encoding: utf8);
    print(logMessage);
  });
}

/// 여러 개의 메시지를 하나의 로그 메시지로 합쳐서 기록
Future<void> logGroup(List<String> messages) async {
  final combinedMessage = messages.join(" | ");
  await safeLog(combinedMessage);
}
