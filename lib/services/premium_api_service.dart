import 'dart:convert';

import 'package:http/http.dart' as http;

import 'huepop_config.dart';

class PremiumApiException implements Exception {
  const PremiumApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PremiumAccount {
  const PremiumAccount({required this.id, required this.email, this.displayName});
  final int id;
  final String email;
  final String? displayName;
  factory PremiumAccount.fromJson(Map<String, dynamic> json) => PremiumAccount(
    id: (json['id'] as num?)?.toInt() ?? 0,
    email: (json['email'] ?? '').toString(),
    displayName: json['display_name']?.toString(),
  );
}

class PremiumAuthResult {
  const PremiumAuthResult({required this.token, required this.account, required this.premium});
  final String token;
  final PremiumAccount account;
  final bool premium;
}

class PremiumApiService {
  const PremiumApiService();

  Future<Map<String, dynamic>> _request(String endpoint, {String method = 'GET', String? token, Map<String, dynamic>? body}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final uri = HuePopConfig.premiumApi(endpoint);
    late http.Response response;
    try {
      response = method == 'POST'
          ? await http.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(const Duration(seconds: 25))
          : await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const PremiumApiException('HuePop could not reach the Premium service.');
    }
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300 || data['ok'] == false) {
      throw PremiumApiException((data['error'] ?? 'Premium service request failed.').toString());
    }
    return data;
  }

  Future<PremiumAuthResult> register({required String email, required String password, String? displayName}) async {
    final data = await _request('register.php', method: 'POST', body: {
      'email': email, 'password': password, 'display_name': displayName ?? '',
    });
    return PremiumAuthResult(
      token: (data['token'] ?? '').toString(),
      account: PremiumAccount.fromJson(Map<String, dynamic>.from(data['user'] as Map? ?? const {})),
      premium: data['premium'] == true,
    );
  }

  Future<PremiumAuthResult> login({required String email, required String password}) async {
    final data = await _request('login.php', method: 'POST', body: {'email': email, 'password': password});
    return PremiumAuthResult(
      token: (data['token'] ?? '').toString(),
      account: PremiumAccount.fromJson(Map<String, dynamic>.from(data['user'] as Map? ?? const {})),
      premium: data['premium'] == true,
    );
  }

  Future<PremiumAuthResult> me(String token) async {
    final data = await _request('me.php', token: token);
    return PremiumAuthResult(
      token: token,
      account: PremiumAccount.fromJson(Map<String, dynamic>.from(data['user'] as Map? ?? const {})),
      premium: data['premium'] == true,
    );
  }

  Future<bool> premiumStatus(String token) async {
    final data = await _request('premium-status.php', token: token);
    return data['premium'] == true;
  }

  Future<Uri> createCheckoutSession(String token) async {
    final data = await _request('create-checkout-session.php', method: 'POST', token: token, body: const {});
    if (data['already_premium'] == true) {
      throw const PremiumApiException('Your HuePop Premium access is already active.');
    }
    final uri = Uri.tryParse((data['checkout_url'] ?? '').toString());
    if (uri == null || !uri.hasScheme) {
      throw const PremiumApiException('HuePop could not open Stripe Checkout.');
    }
    return uri;
  }

  Future<void> logout(String token) async {
    await _request('logout.php', method: 'POST', token: token, body: const {});
  }
}