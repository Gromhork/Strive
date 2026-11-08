import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../services/google_auth.dart';
import '../../main.dart';
import '../../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on FirebaseAuthException catch (e) {
      final code = (e.message ?? '').contains('CONFIGURATION_NOT_FOUND') ? 'configuration-not-found' : e.code;
      debugPrint('Auth error ${e.code}: ${e.message}');
      setState(() => _error = code == 'unknown' ? '${_message(code)}\n${e.message ?? ''}' : _message(code));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(String code) {
    final l = context.l10n;
    return switch (code) {
      'invalid-email' => l.authInvalidEmail,
      'user-not-found' || 'wrong-password' || 'invalid-credential' => l.authWrongCredentials,
      'email-already-in-use' => l.authEmailInUse,
      'weak-password' => l.authWeakPassword,
      'network-request-failed' => l.authNetwork,
      'operation-not-allowed' || 'configuration-not-found' => l.authNotEnabled,
      _ => '${l.authError} ($code)',
    };
  }

  Future<void> _submit() => _run(() async {
    final auth = FirebaseAuth.instance;
    if (_register) {
      await auth.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pw.text);
    } else {
      await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pw.text);
    }
  });

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = context.l10n.authEnterEmail);
      return;
    }
    await _run(() => FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim()));
    if (mounted && _error == null) toast(context, context.l10n.authResetSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StriveLogo(size: 76),
                  const SizedBox(height: 12),
                  Text(l.tagline, textAlign: TextAlign.center, style: t.bodyMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in Sport.values) Padding(padding: const EdgeInsets.all(4), child: SportBadge(s, size: 36)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password, prefixIcon: const Icon(Icons.lock_outline)),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _busy ? null : _reset, child: Text(l.forgotPassword)),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child:
                        _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_register ? l.register : l.login),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register ? l.haveAccount : l.noAccount),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.or, style: t.bodySmall)),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                      onPressed: _busy ? null : () => _run(() async => GoogleAuth.signIn()),
                      icon: Image.asset('assets/images/google.png', width: 20, height: 20),
                      label: Text(l.continueWithGoogle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => FirebaseAuth.instance.signInAnonymously()),
                    icon: const Icon(Icons.person_outline),
                    label: Text(l.continueAsGuest),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
