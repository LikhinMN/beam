import 'dart:io';
import 'package:crypto/crypto.dart';

/// Computes the SHA256 checksum of a file.
/// Streams the file to avoid loading it entirely into memory.
Future<String> computeChecksum(File file) async {
  final stream = file.openRead();
  final digest = await sha256.bind(stream).single;
  return digest.toString();
}

/// Verifies that the file's SHA256 checksum matches the expected checksum.
Future<bool> verifyChecksum(File file, String expected) async {
  final checksum = await computeChecksum(file);
  return checksum == expected;
}
