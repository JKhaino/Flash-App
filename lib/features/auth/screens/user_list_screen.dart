import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import 'user_creation_screen.dart';
import 'user_edit_screen.dart';

class UserListScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const UserListScreen({super.key, required this.toggleTheme});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _supabase = SupabaseService.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('app_usuarios')
          .select()
          .order('nome');
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuários: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const flashYellow = Color(0xFFFFD700);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar Usuários"),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: flashYellow,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserCreationScreen(toggleTheme: widget.toggleTheme)),
          );
          _fetchUsers();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: flashYellow))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isActive = user['ativo'] == true;
                final roles = List<String>.from(user['funcoes'] ?? []);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? Colors.green : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(user['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("@${user['username']}"),
                        const SizedBox(height: 4),
                        Text(roles.join(', '), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: flashYellow),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserEditScreen(
                              user: user,
                              toggleTheme: widget.toggleTheme,
                            ),
                          ),
                        );
                        _fetchUsers();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}