import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _submit({required bool register}) async {
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final pass = _password.text;
      register ? await _auth.register(email, pass) : await _auth.signIn(email, pass);
    } on FirebaseAuthException catch (e) {
      _show(_message(e.code));
    } catch (_) {
      _show('Não foi possível conectar. Verifique sua internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'A senha deve ter ao menos 6 caracteres.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      default:
        return 'E-mail ou senha incorretos.';
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_note, size: 72),
                const SizedBox(height: 8),
                Text('Bloco de Notas',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'E-mail', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Senha', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton(
                    onPressed: () => _submit(register: false),
                    child: const Text('Entrar'),
                  ),
                  TextButton(
                    onPressed: () => _submit(register: true),
                    child: const Text('Criar conta'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
