import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AuthService {
  final _supabase = SupabaseService.client;

  /// Realiza o login transformando o username em um email interno falso
  Future<AuthResponse> login(String username, String password) async {
    // Cria o email fake para autenticação
    final email = '${username.trim()}@flashapp.interno';
    
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Busca as roles (funções) do usuário na tabela pública app_usuarios
  Future<List<String>> getUserRoles(String userId) async {
    try {
      final data = await _supabase
          .from('app_usuarios')
          .select('funcoes')
          .eq('id', userId)
          .maybeSingle();
      
      if (data != null && data['funcoes'] != null) {
        return List<String>.from(data['funcoes']);
      }
      return [];
    } catch (e) {
      // Em caso de erro, retorna lista vazia para cair no fallback de acesso
      return [];
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}