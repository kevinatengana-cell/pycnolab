import 'dart:io';
import 'package:http/http.dart' as http;

class ExportExcelResult {
  final File file;
  final String fileName;
  const ExportExcelResult({required this.file, required this.fileName});
}

/// À intégrer dans PythonEngineService existant.
Future<ExportExcelResult> exporterClasseurTraction({
  required String baseUrl,
  required String inputPath,
  String? outputPath,
  double l0Mm = 20.0,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/essais/traction/exporter-excel'),
    headers: {'Content-Type': 'application/json'},
    body: '{"input_path":"${_jsonEscape(inputPath)}",'
        '"output_path":${outputPath == null ? 'null' : '"${_jsonEscape(outputPath)}"'},'
        '"l0_mm":$l0Mm}',
  );
  if (response.statusCode != 200) {
    throw Exception('Export Excel échoué (${response.statusCode}) : ${response.body}');
  }
  final path = outputPath ?? '${File(inputPath).parent.path}${Platform.pathSeparator}RAPPORT_TRACTION.xlsx';
  final file = File(path)..writeAsBytesSync(response.bodyBytes);
  return ExportExcelResult(file: file, fileName: file.uri.pathSegments.last);
}

String _jsonEscape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n');
