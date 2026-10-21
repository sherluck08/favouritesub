import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class VirtualAccountService {
  static String _defaultBase() => Api.base;

  static Future<Map<String, dynamic>> createVirtualAccount({
    required String vNum,
    required String generateType,
    String methodType = 'BVNMETHOD',
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse(
      '${baseUrl ?? _defaultBase()}/api/create-virtual-account/',
    );
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'v_num': vNum,
        'generatetype': generateType,
        'methodtype': methodType,
      }),
    );

    print(resp.statusCode);
    print(resp.body);
    print(vNum);
    print(generateType);
    print(methodType);

    Map<String, dynamic>? decoded;
    try {
      final body = (resp.body).trim();
      if (body.isNotEmpty && body.startsWith('{')) {
        decoded = jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final status = decoded != null && decoded['status'] != null
        ? decoded['status'].toString()
        : '';
    final msg = decoded != null
        ? (decoded['msg']?.toString() ?? decoded['message']?.toString() ?? '')
        : '';

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (status.toLowerCase() == 'successful' || status.isEmpty) {
        return {
          'status': 'successful',
          'msg': msg.isEmpty ? 'account generated  successfully' : msg,
        };
      }
      return {
        'status': 'failed',
        'msg': msg.isEmpty
            ? 'Unable to generate account, please contact admin'
            : msg,
      };
    }

    final fallbackMsg = msg.isEmpty ? 'Server error (${resp.statusCode})' : msg;
    return {'status': 'failed', 'msg': fallbackMsg};
  }

  static Future<Map<String, dynamic>> verifyAndGenerateVirtualAccount({
    required String vNum,
    required String generateType,
    required String fullName,

    String? baseUrl,
  }) async {
    final base = baseUrl ?? _defaultBase();

    return await createVirtualAccount(
      vNum: vNum,
      generateType: generateType,
      methodType: 'BVNMETHOD',
      baseUrl: base,
    );
  }
}
