import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'runtime_config_service.dart';

class StorageService {
  Future<String> uploadXFile({
    required XFile file,
    required String path,
  }) async {
    if (RuntimeConfigService.hasBackendBaseUrl) {
      return _uploadToBackend(file);
    }

    throw 'Medya yükleme için backend adresi ayarlı değil.';
  }

  Future<String> _uploadToBackend(XFile file) async {
    await AuthService().initialize();
    if (!AuthService().isLoggedIn) {
      throw 'Yükleme yapmak için giriş yapmalısın.';
    }

    final uri = Uri.parse(
      '${RuntimeConfigService.backendBaseUrl.replaceFirst(RegExp(r'/$'), '')}/api/uploads/media',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await AuthService().authorizedHeaders());
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'Yükleme başarısız oldu (${response.statusCode}).';
    }

    final payload = Map<String, dynamic>.from(json.decode(response.body));
    final url = (payload['url'] ?? '').toString();
    if (url.isEmpty) {
      throw 'Sunucu dosya URL\'si döndürmedi.';
    }
    return url;
  }
}
