import 'dart:io';

import 'package:path/path.dart' as p;

Future<Directory> getUserProtocolDirectory() async {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null || localAppData.trim().isEmpty) {
    throw StateError('Windows ne fournit pas le dossier LOCALAPPDATA.');
  }

  final directory = Directory(
    p.join(localAppData, 'PycnoLab', 'data', 'protocoles'),
  );
  await directory.create(recursive: true);
  return directory;
}
