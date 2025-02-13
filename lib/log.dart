import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:synchronized/synchronized.dart';

final Lock _logLock = Lock();

Future<void> safeLog(String message) async {
  await _logLock.synchronized(() async {
    final DateTime now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final logMessage = "$formattedDate - $message\n";

    final directory = Directory("C:\\temp\\MaplelandEXPTracker");
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final filePath = "${directory.path}\\client_log.txt";
    final file = File(filePath);

    // 파일이 존재하면 BOM이 포함되어 있는지 확인하고, 없으면 BOM 추가
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.length < 3 ||
          bytes[0] != 0xEF ||
          bytes[1] != 0xBB ||
          bytes[2] != 0xBF) {
        final newBytes = <int>[0xEF, 0xBB, 0xBF] + bytes;
        await file.writeAsBytes(newBytes, mode: FileMode.write);
      }
    } else {
      // 파일이 없으면 BOM과 함께 생성
      await file.writeAsString('\uFEFF', encoding: utf8);
    }

    await file.writeAsString(logMessage, mode: FileMode.append, encoding: utf8);
    print(logMessage);
  });
}

Future<void> logGroup(List<String> messages) async {
  final combinedMessage = messages.join(" | ");
  await safeLog(combinedMessage);
}
