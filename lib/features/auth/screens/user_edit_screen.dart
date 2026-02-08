import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback toggleTheme;

  const UserEditScreen({super.key, required this.user, required this.toggleTheme});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _supabase = SupabaseService.client;
  late bool _isActive;
  List<String> _availableRoles = [];
  final List<String> _selectedRoles = [];
  bool _isLoading = false;

  final Map<String, String> _roleLabels = {
    'SEPARADOR': 'Separador',
    'ABASTECEDOR': 'Abastecedor',
    'LIDER_SEP': 'Líder de Separação',
    'LIDER_ABA': 'Líder de Abastecimento',
    'ADM': 'ADM',
    'WATCHDOG': 'Watchdog',
    'SIL_LOVE': 'Administrador',
  };

  @override
  void initState() {
    super.initState();
    _isActive = widget.user['ativo'] ?? true;
    _selectedRoles.addAll(List<String>.from(widget.user['funcoes'] ?? []));
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final data = await _supabase
          .from('app_cargos')
          .select('slug')
          .order('nome');
      
      if (mounted) {
        setState(() {
          _availableRoles = List<String>.from(data.map((e) => e['slug']));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableRoles = ['SEPARADOR', 'ABASTECEDOR', 'LIDER_SEP', 'LIDER_ABA', 'ADM', 'WATCHDOG', 'SIL_LOVE'];
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('app_usuarios').update({
        'ativo': _isActive,
        'funcoes': _selectedRoles,
      }).eq('id', widget.user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário atualizado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const flashYellow = Color(0xFFFFD700);

    return Scaffold(
      appBar: AppBar(
        title: Text("Editar ${widget.user['username']}"),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nome: ${widget.user['nome']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Email: ${widget.user['email_contato'] ?? '-'}", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text("Status do Acesso", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: Text(_isActive ? "Ativo" : "Inativo"),
              value: _isActive,
              activeColor: flashYellow,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 16),
            const Text("Funções (Cargos)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableRoles.map((role) {
                final isSelected = _selectedRoles.contains(role);
                return FilterChip(
                  label: Text(_roleLabels[role] ?? role),
                  selected: isSelected,
                  selectedColor: flashYellow,
                  checkmarkColor: Colors.black,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : (isDarkMode ? Colors.white : Colors.black),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedRoles.add(role);
                      } else {
                        _selectedRoles.remove(role);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: flashYellow, foregroundColor: Colors.black),
                child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("SALVAR ALTERAÇÕES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}