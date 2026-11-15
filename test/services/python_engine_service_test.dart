import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pycnolab/services/backend_api_endpoint.dart';
import 'package:pycnolab/services/python_engine_service.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain();
      request.response.statusCode = HttpStatus.ok;
      request.response.add(<int>[1, 2, 3]);
      await request.response.close();
    });
    BackendApiEndpoint.bindPort(server.port);
  });

  tearDown(() async {
    BackendApiEndpoint.clearPort();
    await server.close(force: true);
  });

  Future<String> exportTo(String fileName) async {
    final directory =
        await Directory.systemTemp.createTemp('pycnolab_export_test_');
    addTearDown(() => directory.delete(recursive: true));

    return PythonEngineService().exporterEssaiExcel(
      typeEssai: 'traction',
      cheminFichier: 'source.xlsx',
      cheminDestination: p.join(directory.path, fileName),
    );
  }

  test('adds the xlsx extension when the chosen name has none', () async {
    final savedPath = await exportTo('rapport');

    expect(savedPath, endsWith('${p.separator}rapport.xlsx'));
    expect(await File(savedPath).exists(), isTrue);
  });

  test('does not duplicate an existing xlsx extension', () async {
    final savedPath = await exportTo('rapport.xlsx');

    expect(savedPath, endsWith('${p.separator}rapport.xlsx'));
  });
}
