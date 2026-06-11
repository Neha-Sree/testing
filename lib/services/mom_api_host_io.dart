import 'dart:io' show Platform;

/// Android emulator maps 10.0.2.2 to the host machine.
String momApiDefaultLoopbackHost() {
  if (Platform.isAndroid) {
    return '10.0.2.2';
  }
  return '127.0.0.1';
}
