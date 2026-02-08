import 'package:flutter/material.dart';
import '../../../core/services/access_control.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme; // Para mudar de Dark para Light
  final bool isDarkMode;

  const LoginScreen({
    super.key, 
    required this.toggleTheme, 
    required this.isDarkMode
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  // Cor Oficial da Flash (Amarelo/Dourado)
  final Color flashYellow = const Color(0xFFFFD700); 

  Future<void> _handleLogin() async {
    final username = _userController.text.trim();
    final password = _passController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe usuário e senha.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // 1. Autenticação no Supabase
      final response = await _authService.login(username, password);
      
      if (response.user == null) throw Exception("Usuário não identificado.");

      // 2. Busca permissões (Roles)
      final roles = await _authService.getUserRoles(response.user!.id);

      if (mounted) {
        // 3. Redirecionamento Inteligente via AccessControl
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AccessControl.getInitialScreen(roles, widget.toggleTheme),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString().contains('Invalid login') 
            ? 'Usuário ou senha incorretos.' 
            : 'Erro ao conectar: ${e.toString()}';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define as cores baseadas no tema atual
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
    final txtColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: txtColor),
          onPressed: widget.toggleTheme,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Logo e Título
              Image.asset(
                'assets/images/icon.png',
                height: 120, // Ajuste o tamanho conforme necessário
              ),
              const SizedBox(height: 10),
              Text(
                'FLASH APP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: txtColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Somos o que construímos',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 50),

              // 2. Card de Login
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _userController,
                      style: TextStyle(color: txtColor),
                      decoration: InputDecoration(
                        labelText: 'Usuário',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.person_outline, color: flashYellow),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[800]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: flashYellow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      style: TextStyle(color: txtColor),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.lock_outline, color: flashYellow),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                         focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: flashYellow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // 3. Botão de Ação
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: flashYellow,
                          foregroundColor: Colors.black, // Texto preto no amarelo
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Text(
                "Versão Alpha 0.2 - Dados Reais",
                style: TextStyle(fontSize: 10, color: Colors.grey[800]),
              )
            ],
          ),
        ),
      ),
    );
  }
}