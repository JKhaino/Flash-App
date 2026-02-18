import 'package:flutter/material.dart';
import '../services/access_control.dart';
import '../services/supabase_service.dart';
import '../../main.dart';
import '../../features/estoque/screens/mission_screen.dart';
import '../../features/estoque/screens/pmp_screen.dart';
import '../../features/BI/screens/estoque_screen.dart';
import '../../features/auth/screens/user_list_screen.dart';

class HomeModulesScreen extends StatelessWidget {
  final List<String> userRoles;
  final VoidCallback toggleTheme;

  const HomeModulesScreen({
    super.key,
    required this.userRoles,
    required this.toggleTheme,
  });

  void _navigateToEstoque(BuildContext context) {
    // Lógica de roteamento do módulo de Estoque baseada na role
    if (userRoles.contains(AccessControl.roleAdm) ||
        userRoles.contains(AccessControl.roleLiderSep) ||
        userRoles.contains(AccessControl.roleLiderAba)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PmpScreen(toggleTheme: toggleTheme)),
      );
    } else {
      // Operadores (Separadores/Abastecedores) vão para Missões
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MissionScreen(toggleTheme: toggleTheme)),
      );
    }
  }

  void _navigateToBI(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BiEstoqueScreen(toggleTheme: toggleTheme)),
    );
  }

  void _navigateToConfig(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserListScreen(toggleTheme: toggleTheme)),
    );
  }

  void _showComingSoon(BuildContext context, String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Módulo $moduleName em desenvolvimento.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    const flashYellow = Color(0xFFFFD700);

    final bool isSilLove = userRoles.contains(AccessControl.roleSilLove);

    final modules = [
      {'name': 'LOGÍSTICA', 'icon': Icons.local_shipping, 'active': false},
      {'name': 'PLANEJAMENTO', 'icon': Icons.calendar_month, 'active': false},
      {'name': 'FISCAL', 'icon': Icons.receipt_long, 'active': false},
      {'name': 'ESTOQUE', 'icon': Icons.inventory_2, 'active': true, 'onTap': () => _navigateToEstoque(context)},
      {'name': 'PRODUÇÃO', 'icon': Icons.factory, 'active': false},
      {'name': 'QUALIDADE', 'icon': Icons.verified, 'active': false},
      {'name': 'INTELIGÊNCIA', 'icon': Icons.insights, 'active': true, 'onTap': () => _navigateToBI(context)},
      if (isSilLove)
        {'name': 'CONFIGURAÇÃO', 'icon': Icons.settings, 'active': true, 'onTap': () => _navigateToConfig(context)},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Módulos Flash"),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await SupabaseService.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const FlashApp()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(builder: (context, constraints) {
              // Define colunas baseado na largura disponível
              int crossAxisCount = 2;
              if (constraints.maxWidth > 600) crossAxisCount = 3;
              if (constraints.maxWidth > 900) crossAxisCount = 4;

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  final isActive = module['active'] as bool;
                  final onTap = module['onTap'] as VoidCallback?;

                  return Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      onTap: isActive
                          ? onTap
                          : () =>
                              _showComingSoon(context, module['name'] as String),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? flashYellow.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              module['icon'] as IconData,
                              size: 32,
                              color: isActive
                                  ? flashYellow
                                  : (isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[400]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            module['name'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isActive
                                  ? (isDarkMode ? Colors.white : Colors.black)
                                  : Colors.grey,
                            ),
                          ),
                          if (!isActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "Em breve",
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}