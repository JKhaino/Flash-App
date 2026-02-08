import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Getters para uso em clientes secundários (ex: criação de usuário sem logout)
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Inicialização correta para Flutter (com persistência de sessão)
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  // Acesso ao cliente singleton gerenciado pelo pacote
  static SupabaseClient get client => Supabase.instance.client;
}