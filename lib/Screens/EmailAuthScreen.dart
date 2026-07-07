import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ProfileSetupScreen.dart';
import 'Homescreen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const _gradientStart = Color(0xFF8A5CF5);
  static const _gradientEnd = Color(0xFF6539E8);
  static const _gradient = LinearGradient(
    colors: [_gradientStart, _gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Detecta se é email ou username
  bool _isEmail(String input) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());

  // Busca email pelo username no Supabase
  Future<String?> _emailFromUsername(String username) async {
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('username', username.trim().toLowerCase())
          .maybeSingle();
      return data?['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Gera username único via função SQL
  Future<String> _generateUsername(String name, String email) async {
    // Base: parte do email antes do @, sem caracteres especiais
    final base = email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final result = await Supabase.instance.client
        .rpc('generate_unique_username', params: {'base_name': base});
    return result as String;
  }

  Future<void> _handleAuth() async {
    final input = _inputController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showSnack('Preencha todos os campos');
      return;
    }
    if (!_isLogin && _nameController.text.trim().isEmpty) {
      _showSnack('Digite seu nome');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        // ── Login: suporte a email OU username ────────────────────────
        String email;
        if (_isEmail(input)) {
          email = input;
        } else {
          final found = await _emailFromUsername(input);
          if (found == null) {
            _showSnack('Username não encontrado');
            return;
          }
          email = found;
        }

        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.user == null) throw Exception('Usuário não encontrado');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Homescreen()),
        );
      } else {
        // ── Cadastro: gera username automaticamente ───────────────────
        if (!_isEmail(input)) {
          _showSnack('No cadastro, use um email válido');
          return;
        }

        final res = await supabase.auth.signUp(
          email: input,
          password: password,
        );
        final user = res.user;
        if (user == null) throw Exception('Erro ao criar conta');

        final name = _nameController.text.trim();
        final username = await _generateUsername(name, input);

        await supabase.from('users').upsert({
          'id': user.id,
          'email': input,
          'name': name,
          'username': username,
          'username_changed_at': null,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        _showSnack('Username gerado: @$username');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      _showSnack('Erro: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _gradientEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: _gradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo_talk.png',
                      width: 90, height: 90),
                  const SizedBox(height: 16),
                  const Text(
                    'Talk Messenger',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Bem-vindo de volta!' : 'Crie sua conta',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _buildField(
                            controller: _nameController,
                            label: 'Nome completo',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildField(
                          controller: _inputController,
                          label: _isLogin
                              ? 'Email ou @username'
                              : 'Email',
                          icon: _isLogin
                              ? Icons.alternate_email
                              : Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _passwordController,
                          label: 'Senha',
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _gradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      _isLogin ? 'Entrar' : 'Criar conta',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? 'Não tem uma conta? '
                            : 'Já tem uma conta? ',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Cadastre-se' : 'Entrar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: _gradientStart, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _gradientStart, width: 1.5)),
      ),
    );
  }
}
