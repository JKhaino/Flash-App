import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class UserCreationScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const UserCreationScreen({super.key, required this.toggleTheme});

  @override
  State<UserCreationScreen> createState() => _UserCreationScreenState();
}

class _UserCreationScreenState extends State<UserCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _generatedUsername = '';
  
  // Lista de cargos disponíveis (Carregado do banco ou fixo)
  List<String> _availableRoles = [];
  final List<String> _selectedRoles = [];
  bool _isActive = true;
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
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final data = await SupabaseService.client
          .from('app_cargos')
          .select('slug')
          .order('nome');
      
      if (mounted) {
        setState(() {
          _availableRoles = List<String>.from(data.map((e) => e['slug']));
        });
      }
    } catch (e) {
      // Fallback se der erro ou tabela vazia
      if (mounted) {
        setState(() {
          _availableRoles = ['SEPARADOR', 'ABASTECEDOR', 'LIDER_SEP', 'LIDER_ABA', 'ADM', 'WATCHDOG', 'SIL_LOVE'];
        });
      }
    }
  }

  void _generateUsername(String fullName) {
    if (fullName.trim().isEmpty) {
      setState(() => _generatedUsername = '');
      return;
    }
    
    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      setState(() => _generatedUsername = '');
      return;
    }

    String username = '';
    if (parts.length == 1) {
      username = parts[0].toLowerCase();
    } else {
      // Iniciais dos primeiros nomes
      for (int i = 0; i < parts.length - 1; i++) {
        username += parts[i][0].toLowerCase();
      }
      // Sobrenome completo
      username += parts.last.toLowerCase();
    }

    // Remove acentos (básico)
    username = username
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');

    setState(() {
      _generatedUsername = username;
    });
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos uma função.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Cliente temporário para não deslogar o admin atual
    final tempClient = SupabaseClient(SupabaseService.url, SupabaseService.anonKey);

    try {
      final username = _generatedUsername;
      final emailAuth = '$username@flashapp.interno';
      const password = 'flashengenharia';

      // 1. Criar no Auth (Supabase)
      final authResponse = await tempClient.auth.signUp(
        email: emailAuth,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception("Falha ao criar usuário no Auth.");
      }

      final newUserId = authResponse.user!.id;

      // 2. Criar na tabela app_usuarios (Usando o cliente principal logado como Admin)
      await SupabaseService.client.from('app_usuarios').insert({
        'id': newUserId,
        'username': username,
        'nome': _nameController.text.trim(),
        'email_contato': _emailController.text.trim(),
        'funcoes': _selectedRoles,
        'ativo': _isActive,
        'pontos': 0,
        'nivel': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuário $username criado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await tempClient.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const flashYellow = Color(0xFFFFD700);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Usuário"),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dados Pessoais", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder()),
                onChanged: _generateUsername,
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              if (_generatedUsername.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Usuário gerado: $_generatedUsername", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "E-mail de Contato", 
                  border: OutlineInputBorder(),
                  helperText: "Para recuperação de senha",
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text("Permissões e Acesso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text("Usuário Ativo"),
                value: _isActive,
                activeColor: flashYellow,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 8),
              const Text("Funções (Cargos):"),
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
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(backgroundColor: flashYellow, foregroundColor: Colors.black),
                  child: _isLoading 
                      ? const CircularProgressIndicator() 
                      : const Text("CRIAR USUÁRIO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}