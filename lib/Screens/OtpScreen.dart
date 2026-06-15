import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Screens/Homescreen.dart';
import 'package:talk_messenger/Screens/ProfileSetupScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({Key? key, required this.phone}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String _error = '';
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendSeconds > 0) _resendSeconds--;
      });
      return _resendSeconds > 0;
    });
  }

  String get _otp =>
      _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Digite o código completo');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.verifyOTP(
        phone: '+55${widget.phone}',
        token: _otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final onboarded = prefs.getBool('onboarded') ?? false;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => onboarded
                ? const Homescreen()
                : const ProfileSetupScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = 'Código inválido ou expirado.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Verificar número',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Digite o código enviado para +55 ${widget.phone}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildOtpBox(i)),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: _resendSeconds == 0 ? () {} : null,
                child: Text(
                  _resendSeconds > 0
                      ? 'Reenviar código em $_resendSeconds s'
                      : 'Reenviar código',
                  style: TextStyle(
                    color: _resendSeconds == 0
                        ? const Color(0xFF0A84FF)
                        : Colors.grey,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verificar',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int i) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0A84FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF0A84FF), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) {
            _focusNodes[i + 1].requestFocus();
          } else if (val.isEmpty && i > 0) {
            _focusNodes[i - 1].requestFocus();
          }
          if (i == 5 && val.isNotEmpty) _verifyOtp();
        },
      ),
    );
  }
}
