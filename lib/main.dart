import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'package:talk_messenger/Screens/Homescreen.dart';
import 'package:talk_messenger/core/theme/app_theme.dart';

const String supabaseUrl = 'SUPABASE_URL_PLACEHOLDER';
const String supabaseAnonKey = 'SUPABASE_ANON_KEY_PLACEHOLDER';
const String smsDevKey = 'SMSDEV_KEY_PLACEHOLDER';
const String agoraAppId = 'AGORA_APP_ID_PLACEHOLDER';

// 'light' | 'amoled'
final ValueNotifier<String> themeNotifier = ValueNotifier<String>('light');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = prefs.getString('app_theme') ?? 'light';

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, themeKey, _) {
        final ThemeData activeTheme =
            themeKey == 'amoled' ? AppTheme.amoled : AppTheme.light;

        return MaterialApp(
          title: 'Talk Messenger',
          debugShowCheckedModeBanner: false,
          theme: activeTheme,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final session = supabase.auth.currentSession;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            session != null ? const Homescreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A84FF),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
