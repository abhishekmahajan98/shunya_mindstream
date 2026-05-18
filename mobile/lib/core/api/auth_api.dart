import '../models/profile.dart';
import 'api_client.dart';

class AuthApi {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final resp = await dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final resp = await dio.post('/api/auth/signup', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
    });
    return resp.data as Map<String, dynamic>;
  }

  static Future<Profile> me() async {
    final resp = await dio.get('/api/auth/me');
    return Profile.fromJson(resp.data['profile'] as Map<String, dynamic>);
  }
}
