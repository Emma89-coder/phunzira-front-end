// services/auth_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://your-server-ip:3000/api/auth';

  // Helper method to handle responses
  static dynamic _handleResponse(http.Response response) {
    try {
      return json.decode(response.body);
    } catch (e) {
      return {'message': 'Invalid response from server'};
    }
  }

  // Get auth headers for protected routes
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Register new user
  static Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 201) {
        // Store tokens if returned (auto-login)
        if (data['data']?['accessToken'] != null) {
          await _storeTokens(
            data['data']['accessToken'],
            data['data']['refreshToken'],
          );
        }
        return data;
      }

      // Return error message from server
      throw Exception(data['message'] ?? 'Registration failed');
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }

  // Login user
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        // Store tokens
        await _storeTokens(
          data['data']['accessToken'],
          data['data']['refreshToken'],
        );

        // Store user info
        if (data['data']['user'] != null) {
          await _storeUserInfo(data['data']['user']);
        }

        return data;
      }

      if (response.statusCode == 429) {
        throw Exception('Too many login attempts. Please try again later.');
      }

      throw Exception(data['message'] ?? 'Login failed');
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Refresh access token
  static Future<String?> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');

      if (refreshToken == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        final newAccessToken = data['data']['accessToken'];
        await prefs.setString('accessToken', newAccessToken);
        return newAccessToken;
      }

      // If refresh token is invalid, logout user
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
      }

      return null;
    } catch (e) {
      print('Refresh token error: $e');
      return null;
    }
  }

  // Logout from current device
  static Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      final headers = await _getAuthHeaders();

      if (refreshToken != null && headers['Authorization'] != 'Bearer null') {
        // Call logout endpoint
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: headers,
          body: json.encode({'refreshToken': refreshToken}),
        );
      }

      // Clear all local storage regardless of API call success
      await prefs.clear();
      return true;
    } catch (e) {
      print('Logout error: $e');
      // Still clear local storage on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return false;
    }
  }

  // Logout from all devices
  static Future<bool> logoutAll() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/logout-all'),
        headers: headers,
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        // Clear all local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return true;
      }

      throw Exception(data['message'] ?? 'Logout from all devices failed');
    } catch (e) {
      print('Logout all error: $e');
      return false;
    }
  }

  // Forgot password
  static Future<void> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 429) {
        throw Exception('Too many attempts. Please try again later.');
      }

      throw Exception(data['message'] ?? 'Failed to send reset email');
    } catch (e) {
      print('Forgot password error: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        return;
      }

      throw Exception(data['message'] ?? 'Failed to reset password');
    } catch (e) {
      print('Reset password error: $e');
      rethrow;
    }
  }

  // Change password (protected)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: headers,
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        return;
      }

      throw Exception(data['message'] ?? 'Failed to change password');
    } catch (e) {
      print('Change password error: $e');
      rethrow;
    }
  }

  // Verify email
  static Future<void> verifyEmail(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/verify-email/$token'),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 200) {
        return;
      }

      throw Exception(data['message'] ?? 'Email verification failed');
    } catch (e) {
      print('Verify email error: $e');
      rethrow;
    }
  }

  // Helper methods for token and user management
  static Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  static Future<void> _storeUserInfo(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user['id']?.toString() ?? '');
    await prefs.setString('username', user['username'] ?? '');
    await prefs.setString('email', user['email'] ?? '');
    await prefs.setString('role', user['role'] ?? 'learner');
    await prefs.setBool('isActive', user['is_active'] ?? true);
  }

  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString('userId') ?? '',
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'role': prefs.getString('role') ?? 'learner',
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final isActive = prefs.getBool('isActive') ?? true;
    return token != null && isActive;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  // Check if token is expired or about to expire
  static Future<bool> isTokenExpired() async {
    final token = await getAccessToken();
    if (token == null) return true;

    try {
      // Decode token without verification (client-side check only)
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );

      final expiry = payload['exp'];
      if (expiry == null) return true;

      // Check if token expires in less than 5 minutes
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      final now = DateTime.now();
      final timeUntilExpiry = expiryTime.difference(now);

      return timeUntilExpiry.inMinutes < 5;
    } catch (e) {
      return true;
    }
  }

  // Make authenticated API call with automatic token refresh
  static Future<http.Response> authenticatedRequest(
      String method,
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    // Check and refresh token if needed
    if (await isTokenExpired()) {
      await refreshToken();
    }

    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final requestHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?headers,
    };

    final url = Uri.parse('$baseUrl$endpoint');

    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(url, headers: requestHeaders);
      case 'POST':
        return await http.post(url, headers: requestHeaders, body: body);
      case 'PUT':
        return await http.put(url, headers: requestHeaders, body: body);
      case 'DELETE':
        return await http.delete(url, headers: requestHeaders);
      default:
        throw Exception('Unsupported method');
    }
  }
}