// lib/core/navigation/navigation_repository.dart
//
// Repository responsável exclusivamente pelo ESTADO da navegação principal
// do app (aba ativa). Não conhece Widgets, Icons ou qualquer detalhe visual.
// Isso permite:
//  - Trocar a UI da navbar sem tocar na lógica de estado.
//  - Testar a navegação isoladamente (unit test simples com ValueNotifier).
//  - Reutilizar o mesmo repositório em outras telas/composições futuras.

import 'package:flutter/foundation.dart';

/// Identifica cada aba principal do app de forma estável (não depende de
/// índice numérico "mágico" espalhado pelo código).
enum TalkNavTab { chats, calls, contacts, status, profile }

/// Fonte única de verdade para a aba atualmente selecionada.
///
/// Mantém um [ValueNotifier] interno para permitir reconstruções granulares
/// via [ValueListenableBuilder], preservando o [IndexedStack] e evitando
/// rebuilds desnecessários de toda a árvore (o que causaria reload de
/// imagens/feed ao trocar de aba).
class NavigationRepository {
  NavigationRepository({TalkNavTab initialTab = TalkNavTab.chats})
      : _currentTab = ValueNotifier<TalkNavTab>(initialTab);

  final ValueNotifier<TalkNavTab> _currentTab;

  /// Exponha o notifier para quem precisar "ouvir" mudanças de aba
  /// (ex.: a FloatingNavBar, ou a própria Homescreen para side-effects).
  ValueListenable<TalkNavTab> get currentTab => _currentTab;

  /// Aba atualmente selecionada.
  TalkNavTab get value => _currentTab.value;

  /// Índice numérico correspondente à aba atual — útil apenas na borda
  /// onde o Flutter exige um índice (ex.: IndexedStack).
  int get currentIndex => _currentTab.value.index;

  /// Troca a aba ativa. Não faz nada se a aba já for a atual, evitando
  /// notificações e rebuilds desnecessários.
  void changeTab(TalkNavTab tab) {
    if (_currentTab.value == tab) return;
    _currentTab.value = tab;
  }

  /// Libera os recursos do notifier. Deve ser chamado no dispose() do
  /// widget "dono" (Homescreen).
  void dispose() {
    _currentTab.dispose();
  }
}
