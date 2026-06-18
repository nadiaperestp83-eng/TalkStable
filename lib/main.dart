import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Provedor de Tema AMOLED ---
class ThemeProvider with ChangeNotifier {
  bool _isAmoled = false;
  bool get isAmoled => _isAmoled;

  void toggleTheme(bool value) {
    _isAmoled = value;
    notifyListeners();
  }
}

// --- Código Completo Corrigido ---
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const TalkMessengerApp(),
    ),
  );
}

class TalkMessengerApp extends StatelessWidget {
  const TalkMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // Tema AMOLED real: Fundo preto puro (0xFF000000)
          theme: themeProvider.isAmoled
              ? ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: Colors.black,
                  canvasColor: Colors.black, // Corrige o fundo de modais/popups
                  dialogBackgroundColor: Colors.black,
                  cardColor: const Color(0xFF121212),
                  primaryColor: Colors.blue,
                )
              : ThemeData.light(),
          home: const Homescreen(),
        );
      },
    );
  }
}

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  // Lógica corrigida para buscar e adicionar contato
  Future<void> addContact(String query, BuildContext context) async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      
      // Busca por email ou telefone
      var snapshot = await usersRef
          .where('email', isEqualTo: query)
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await usersRef
            .where('phoneNumber', isEqualTo: query)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        var userDoc = snapshot.docs.first;
        // Adiciona à coleção de contatos do usuário atual
        await FirebaseFirestore.instance
            .collection('users')
            .doc('currentUserUid') // Substitua pelo UID real
            .collection('contacts')
            .doc(userDoc.id)
            .set(userDoc.data());
            
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contato adicionado!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao adicionar: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conversas")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Exemplo de chamada da busca
            addContact("bruna@exemplo.com", context);
          },
          child: const Text("Buscar e Adicionar Bruna"),
        ),
      ),
    );
  }
}
