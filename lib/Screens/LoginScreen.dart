import 'package:flutter/material.dart';
import 'package:talk_messenger/Screens/PhoneAuthScreen.dart';
import 'package:talk_messenger/Screens/EmailAuthScreen.dart';

// ─── Cores do tema gradiente (roxo) — mesmas do Homescreen ────────────────
class _TalkColors {
  static const Color gradientStart = Color(0xFF8A5CF5);
  static const Color gradientEnd = Color(0xFF6539E8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // --- LOGO (imagem PNG com fundo transparente) ---
              Image.asset(
                'assets/images/logo_talk.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              // -----------------------

              const SizedBox(height: 24),
              const Text(
                "Talk",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Messenger",
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                "O jeito simples de conversar",
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Spacer(),

              _buildButton(
                text: "Entrar com Telefone",
                icon: Icons.phone_android,
                isOutlined: false,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                ),
              ),
              const SizedBox(height: 16),

              _buildButton(
                text: "Entrar com Email",
                icon: Icons.email_outlined,
                isOutlined: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Ao continuar você aceita os Termos de Uso",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required IconData icon,
    required bool isOutlined,
    required VoidCallback onPressed,
  }) {
    if (isOutlined) {
      // Botão "Entrar com Email": contorno gradiente, fundo branco, texto/ícone roxo.
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: _TalkColors.brandGradient,
          ),
          padding: const EdgeInsets.all(2), // espessura da borda gradiente
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            child: TextButton.icon(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: Icon(icon, color: _TalkColors.gradientEnd),
              label: Text(
                text,
                style: const TextStyle(
                  color: _TalkColors.gradientEnd,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Botão "Entrar com Telefone": preenchido com gradiente, texto branco.
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: _TalkColors.brandGradient,
        ),
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: const Icon(icon, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
