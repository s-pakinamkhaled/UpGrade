import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  String? _token;

  Future<bool> login(String email, String password) async {
    try {
      // Use form data for login
      final uri = Uri.parse('${_apiService.baseUrl}/auth/login');
      final request = http.MultipartRequest('POST', uri);
      request.fields['email'] = email;
      request.fields['password'] = password;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        if (_token != null) {
          _apiService.setToken(_token!);
          await _saveToken(_token!);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    try {
      await _apiService.post('/auth/register', {
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    if (_token != null) {
      _apiService.setToken(_token!);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }
}

