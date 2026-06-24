import 'dart:io';
import 'package:beam/core/transfer_server.dart';
import 'package:beam/core/transfer_client.dart';

void main() async {
  final server = TransferServer();
  await server.start(port: 9005);

  final client = TransferClient();

  final testFile = File('test_dummy.txt');
  await testFile.writeAsString('Hello Beam!');

  print('Starting transfer 1');
  await client.sendFile('127.0.0.1', 9005, testFile);
  print('Transfer 1 done');

  print('Starting transfer 2');
  await client.sendFile('127.0.0.1', 9005, testFile);
  print('Transfer 2 done');

  await server.stop();
  await testFile.delete();
  print('All done successfully');
  exit(0);
}
