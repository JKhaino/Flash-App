import 'package:flutter/material.dart';
import '../../features/estoque/screens/pmp_screen.dart';
import '../../features/estoque/screens/mission_screen.dart';
import '../../features/estoque/screens/consulta_saldo_screen.dart';
import '../../features/estoque/screens/structure_explorer_screen.dart';
import '../../features/BI/screens/estoque_screen.dart';
import '../../features/BI/screens/faturamento_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../main.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback toggleTheme;
  final String module; // 'ESTOQUE' ou 'BI'

  const CustomDrawer({super.key, required this.toggleTheme, required this.module});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context); // Fecha o drawer
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const flashYellow = Color(0xFFFFD700);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[900],
            ),
            accountName: const Text(
              "Flash APP",
              style: TextStyle(fontWeight: FontWeight.bold, color: flashYellow),
            ),
            accountEmail: const Text("Somos o que construímos"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.asset('assets/images/icon.png'),
            ),
          ),
          if (module == 'ESTOQUE') ...[
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Gestão de PMP"),
              onTap: () => _navigate(context, PmpScreen(toggleTheme: toggleTheme)),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text("Minhas Missões"),
              onTap: () => _navigate(context, MissionScreen(toggleTheme: toggleTheme)),
            ),
          ],
          if (module == 'BI') ...[
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text("Dashboard Estoque"),
              onTap: () => _navigate(context, BiEstoqueScreen(toggleTheme: toggleTheme)),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text("Faturamento"),
              onTap: () => _navigate(context, FaturamentoScreen(toggleTheme: toggleTheme)),
            ),
          ],
          if (module == 'ESTOQUE') ...[
            const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: const Text("Consultar Saldo"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ConsultaSaldoScreen(toggleTheme: toggleTheme)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.engineering),
            title: const Text("Engenharia"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StructureExplorerScreen(toggleTheme: toggleTheme)),
              );
            },
          ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text("Trocar Módulo"),
            onTap: () {
              Navigator.pop(context); // Fecha Drawer
              Navigator.pop(context); // Volta para a tela de Módulos
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Alterar Senha"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChangePasswordScreen(toggleTheme: toggleTheme)),
              );
            },
          ),
          ListTile(
            leading: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            title: Text(isDarkMode ? "Modo Claro" : "Modo Escuro"),
            onTap: () {
              toggleTheme();
              // Pequeno delay para ver a transição antes de fechar (opcional)
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sair", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const FlashApp()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}