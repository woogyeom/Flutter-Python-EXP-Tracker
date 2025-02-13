import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

Future<void> log(String message) async {
  final DateTime now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  final logMessage = "$formattedDate - $message\n";

  final directory = Directory("C:\\temp\\MaplelandEXPTracker");
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final file = File("${directory.path}\\client_log.txt");

  // 파일이 없으면 BOM을 추가하여 새 파일 생성
  if (!await file.exists()) {
    // \uFEFF 는 UTF-8 BOM에 해당하는 유니코드 문자입니다.
    await file.writeAsString('\uFEFF', encoding: utf8);
  }

  // 로그 메시지를 파일에 추가
  await file.writeAsString(logMessage, mode: FileMode.append, encoding: utf8);

  // 콘솔에도 출력
  print(logMessage);
}
