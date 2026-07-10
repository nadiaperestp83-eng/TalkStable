// lib/widgets/floating_nav_bar.dart
//
// Widget 100% isolado e reutilizável: não conhece Homescreen, Supabase ou
// qualquer regra de negócio. Recebe um NavigationRepository (estado) e uma
// lista de itens (configuração visual) e apenas desenha a pílula flutuante.
//
// IMPORTANTE: este widget NÃO é usado via Scaffold.bottomNavigationBar.
// Ele deve ser posicionado manualmente com Stack + Positioned pela tela-mãe.

import 'package:flutter/material.dart';
import 'package:talk_messenger/core/navigation/navigation_repository.dart';

/// Configuração visual de um item da navbar. Puramente declarativo.
class TalkNavItem {
  final TalkNavTab tab;
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;

  const TalkNavItem({
    required this.tab,
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
  });
}

/// Pílula flutuante de navegação, inspirada em referência de design com
/// fundo branco, cantos totalmente arredondados e sombra suave.
///
/// Cor ativa: verde LINE (#06C755). Cor inativa: cinza suave.
class FloatingNavBar extends StatelessWidget {
  static const Color activeColor = Color(0xFF06C755);
  static const Color inactiveColor = Color(0xFF9AA0A6);
  static const Color pillBackground = Colors.white;

  final NavigationRepository repository;
  final List<TalkNavItem> items;

  /// Callback opcional para side-effects (ex.: recarregar perfil ao abrir
  /// a aba "Perfil"). A troca de estado em si já é feita internamente
  /// via repository.changeTab.
  final ValueChanged<TalkNavTab>? onTabSelected;

  const FloatingNavBar({
    Key? key,
    required this.repository,
    required this.items,
    this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TalkNavTab>(
      valueListenable: repository.currentTab,
      builder: (context, activeTab, _) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: pillBackground,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isSelected = item.tab == activeTab;
              return _FloatingNavItem(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  repository.changeTab(item.tab);
                  onTabSelected?.call(item.tab);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final TalkNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        isSelected ? FloatingNavBar.activeColor : FloatingNavBar.inactiveColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.filledIcon : item.outlineIcon,
                color: color,
                size: 23,
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
