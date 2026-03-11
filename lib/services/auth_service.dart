// services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  AuthException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

class AuthService {
  static const int _timeoutSeconds = 10;

  static String get baseUrl {
    const String defaultUrl = 'http://your-server-ip:3000/api/auth';

    if (kReleaseMode) {
      // Use production URL in release mode
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.yourdomain.com/api/auth',
      );
    }
    return defaultUrl; // Development URL
  }

  // Validation methods
  static void _validateEmail(String email) {
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw AuthException('Please enter a valid email address');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters');
    }
  }

  static void _validateUsername(String username) {
    if (username.length < 3) {
      throw AuthException('Username must be at least 3 characters');
    }
    if (username.length > 30) {
      throw AuthException('Username must be less than 30 characters');
    }
  }

  // HTTP request helper
  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = {
      'Content-Type': 'application/json',
      if (requiresAuth) ...await _getAuthHeaders(),
      ...?headers,
    };

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: requestHeaders)
              .timeout(const Duration(seconds: _timeoutSeconds));
          break;
        case 'POST':
          response = await http.post(url, headers: requestHeaders, body: body)
              .timeout(const Duration(seconds: _timeoutSeconds));
          break;
        case 'PUT':
          response = await http.put(url, headers: requestHeaders, body: body)
              .timeout(const Duration(seconds: _timeoutSeconds));
          break;
        case 'DELETE':
          response = await http.delete(url, headers: requestHeaders)
              .timeout(const Duration(seconds: _timeoutSeconds));
          break;
        default:
          throw AuthException('Unsupported HTTP method: $method');
      }

      // Handle rate limiting
      if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        throw AuthException(
          'Too many requests. Please try again ${retryAfter != null ? 'in $retryAfter seconds' : 'later'}.',
          statusCode: 429,
        );
      }

      return response;
    } on TimeoutException {
      throw AuthException('Connection timeout. Please check your internet and try again.');
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getAccessToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  static dynamic _handleResponse(http.Response response) {
    try {
      return json.decode(response.body);
    } catch (e) {
      return {'message': 'Invalid response from server'};
    }
  }

  // Register new user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    // Validate inputs
    _validateUsername(username);
    _validateEmail(email);
    _validatePassword(password);

    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/register',
        body: json.encode({
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = _handleResponse(response);

      if (response.statusCode == 201) {
        // Auto-login if tokens are returned
        if (data['data']?['accessToken'] != null) {
          await _storeTokens(
            data['data']['accessToken'],
            data['data']['refreshToken'] ?? '',
          );
          if (data['data']['user'] != null) {
            await _storeUserInfo(data['data']['user']);
          }
        }
        return data;
      }

      throw AuthException(
        data['message'] ?? 'Registration failed',
        statusCode: response.statusCode,
        data: data,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    _validatePassword(password);

    try {
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/login',
        body: json.encode({
          'email': email.trim().toLowerCase(),
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

      throw AuthException(
        data['message'] ?? 'Login failed',
        statusCode: response.statusCode,
        data: data,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  // Refresh access token
  static Future<String?> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');

      if (refreshToken == null) return null;

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/refresh-token',
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

      if (refreshToken != null) {
        // Try to logout from backend
        await _makeRequest(
          method: 'POST',
          endpoint: '/logout',
          body: json.encode({'refreshToken': refreshToken}),
          requiresAuth: true,
        );
      }

      // Clear all local storage
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

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final isActive = prefs.getBool('isActive') ?? true;

    if (token == null || !isActive) return false;

    // Check if token is expired
    final isExpired = await isTokenExpired();
    if (isExpired) {
      // Try to refresh
      final newToken = await refreshToken();
      return newToken != null;
    }

    return true;
  }

  // Token management methods
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

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

  // Token expiration check
  static Future<bool> isTokenExpired() async {
    final token = await getAccessToken();
    if (token == null) return true;

    try {
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

  // Get current user info
  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString('userId') ?? '',
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'role': prefs.getString('role') ?? 'learner',
    };
  }
}