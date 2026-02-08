import 'package:flutter/material.dart';
import '../screens/home_modules_screen.dart';

class AccessControl {
  // Roles definidas no Banco de Dados (tabela app_cargos)
  static const String roleAdm = 'ADM';
  static const String roleLiderSep = 'LIDER_SEP';
  static const String roleLiderAba = 'LIDER_ABA';
  static const String roleSeparador = 'SEPARADOR';
  static const String roleAbastecedor = 'ABASTECEDOR';
  static const String roleWatchdog = 'WATCHDOG';
  static const String roleSilLove = 'SIL_LOVE';

  /// Determina a tela inicial com base nas roles do usuário
  static Widget getInitialScreen(List<String> roles, VoidCallback toggleTheme) {
    // Agora todos os usuários vão para a tela de seleção de módulos
    return HomeModulesScreen(userRoles: roles, toggleTheme: toggleTheme);
  }
  
  /// Exemplo de verificação granular para uso futuro em widgets
  static bool isAdmin(List<String> roles) {
    return roles.contains(roleAdm) || roles.contains(roleSilLove);
  }
}