import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/premium_api_service.dart';
import '../state/huepop_app_state.dart';

class DirectPremiumPage extends StatefulWidget {
  const DirectPremiumPage({super.key, required this.appState});
  final HuePopAppState appState;

  @override
  State<DirectPremiumPage> createState() => _DirectPremiumPageState();
}

class _DirectPremiumPageState extends State<DirectPremiumPage> {
  static const tokenKey = 'huepop.direct.token';
  static const emailKey = 'huepop.direct.email';

  final api = const PremiumApiService();
  String? token;
  String? email;
  bool busy = false;
  String? message;

  bool get signedIn => token != null && token!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    loadSession();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(tokenKey);
    email = prefs.getString(emailKey);
    if (mounted) setState(() {});
    if (signedIn) await refreshPremium(silent: true);
  }

  Future<void> saveSession(PremiumAuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, result.token);
    await prefs.setString(emailKey, result.account.email);
    token = result.token;
    email = result.account.email;
    await widget.appState.setPremiumPreview(result.premium);
  }

  Future<void> refreshPremium({bool silent = false}) async {
    if (!signedIn) return;
    if (!silent) setState(() { busy = true; message = null; });
    try {
      final active = await api.premiumStatus(token!);
      await widget.appState.setPremiumPreview(active);
      if (!silent && mounted) {
        setState(() => message = active
            ? 'HuePop Premium is active.'
            : 'Premium is not active yet. If you just paid, refresh again.');
      }
    } on PremiumApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  Future<void> auth(bool register) async {
    final mail = TextEditingController(text: email ?? '');
    final pass = TextEditingController();
    final name = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(register ? 'Create HuePop account' : 'Sign in to HuePop'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (register)
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: mail, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(register ? 'Create account' : 'Sign in')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { busy = true; message = null; });
    try {
      final result = register
          ? await api.register(email: mail.text.trim(), password: pass.text, displayName: name.text.trim())
          : await api.login(email: mail.text.trim(), password: pass.text);
      await saveSession(result);
      if (mounted) setState(() => message = 'Signed in successfully.');
    } on PremiumApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkout() async {
    if (!signedIn) {
      setState(() => message = 'Sign in before purchasing Premium.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final uri = await api.createCheckoutSession(token!);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => message = opened
          ? 'After payment, return to HuePop and tap Refresh Premium.'
          : 'Could not open Stripe Checkout.');
    } on PremiumApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    if (signedIn) {
      try { await api.logout(token!); } catch (_) {}
    }
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
    token = null;
    email = null;
    await widget.appState.setPremiumPreview(false);
    if (mounted) setState(() => message = 'Signed out.');
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.appState.premiumUnlocked;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Image.asset('assets/brand-image.png', width: 170, height: 46, alignment: Alignment.centerLeft),
        const SizedBox(height: 12),
        Text('HuePop Premium', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Card(
          color: const Color(0xFF211A33),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(premium ? Icons.verified : Icons.workspace_premium, color: const Color(0xFFFFBE3D), size: 52),
              const SizedBox(height: 12),
              Text(premium ? 'Premium is active' : 'Unlock HuePop Premium',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Text('Premium artwork • Offline downloads • Glitter • Stickers',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              if (signedIn) Text('Signed in as $email', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (!signedIn) ...[
                  FilledButton(onPressed: busy ? null : () => auth(true), child: const Text('Create account')),
                  OutlinedButton(onPressed: busy ? null : () => auth(false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Sign in')),
                ] else ...[
                  if (!premium) FilledButton(onPressed: busy ? null : checkout, child: const Text('Unlock with Stripe')),
                  OutlinedButton(onPressed: busy ? null : refreshPremium,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Refresh Premium')),
                  TextButton(onPressed: busy ? null : logout,
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: const Text('Sign out')),
                ],
              ]),
              if (busy) ...[const SizedBox(height: 14), const LinearProgressIndicator()],
              if (message != null) ...[const SizedBox(height: 12), Text(message!, style: const TextStyle(color: Colors.white70))],
            ]),
          ),
        ),
      ],
    );
  }
}
