import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../main.dart'; // Para reiniciar o app no logout
import '../../../core/widgets/custom_drawer.dart';
import 'consulta_saldo_screen.dart';
import 'separation_screen.dart';
import 'structure_explorer_screen.dart';
import 'abastecimento_screen.dart';

class MissionScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const MissionScreen({super.key, required this.toggleTheme});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  final _supabase = SupabaseService.client;
  List<Map<String, dynamic>> _missions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMissions();
  }

  Future<void> _fetchMissions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Busca atribuições fazendo join com a tabela de PMP
      final data = await _supabase
          .from('app_atribuicoes')
          .select('tipo_responsavel, app_pmp!inner(id, tat, cod_estrutura, status)')
          .eq('user_id', userId);

      // Agrupar por PMP para evitar duplicidade visual
      final Map<int, Map<String, dynamic>> grouped = {};
      for (var item in data) {
        final pmp = item['app_pmp'];
        final pmpId = pmp['id'];
        final type = item['tipo_responsavel'] as String;
        
        if (!grouped.containsKey(pmpId)) {
          grouped[pmpId] = {
            'app_pmp': pmp,
            'tipos': <String>{type}, // Usar Set para evitar duplicatas
          };
        } else {
          (grouped[pmpId]!['tipos'] as Set<String>).add(type);
        }
      }

      final missionsList = grouped.values.map((e) {
        return {
          'app_pmp': e['app_pmp'],
          'tipos': (e['tipos'] as Set<String>).toList(),
        };
      }).toList();

      // Buscar descrições dos produtos (carros)
      if (missionsList.isNotEmpty) {
        final codes = missionsList
            .map((e) => e['app_pmp']['cod_estrutura'])
            .where((e) => e != null)
            .map((e) => e.toString())
            .toSet()
            .toList();
        
        if (codes.isNotEmpty) {
          final productsData = await _supabase
              .from('app_produtos')
              .select('codigo, descricao')
              .inFilter('codigo', codes);
              
          final descMap = {for (var p in productsData) p['codigo']: p['descricao']};
          
          for (var mission in missionsList) {
            mission['descricao_carro'] = descMap[mission['app_pmp']['cod_estrutura']];
          }
        }
      }

      if (mounted) {
        setState(() {
          _missions = missionsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar missões: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Missões"),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search, color: Color(0xFFFFD700)),
            tooltip: 'Consultar Saldo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ConsultaSaldoScreen(toggleTheme: widget.toggleTheme)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.engineering, color: Color(0xFFFFD700)),
            tooltip: 'Engenharia',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StructureExplorerScreen(toggleTheme: widget.toggleTheme)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Reinicia o app voltando para o Login
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const FlashApp()),
                (route) => false,
              );
            },
          )
        ],
      ),
      drawer: CustomDrawer(toggleTheme: widget.toggleTheme, module: 'ESTOQUE'),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
        : _missions.isEmpty
            ? const Center(child: Text("Nenhuma missão atribuída."))
            : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _missions.length,
        itemBuilder: (context, index) {
          final mission = _missions[index];
          final pmp = mission['app_pmp'];
          final types = List<String>.from(mission['tipos'] ?? []);
          final status = pmp['status'] ?? 'PENDENTE';
          final descricao = mission['descricao_carro'] ?? '...';
          final isPending = status != 'APONTADO'; // Lógica simplificada

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${pmp['tat']}\n${pmp['cod_estrutura']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending ? const Color(0xFFFFD700) : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(descricao, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Tipos: ${types.join(', ')}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 12),
                  if (isPending)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.local_shipping, color: Colors.blue),
                          tooltip: 'Abastecimento',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AbastecimentoScreen(
                                  pmpId: pmp['id'],
                                  carName: pmp['tat'],
                                  toggleTheme: widget.toggleTheme,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SeparationScreen(
                                  pmpId: pmp['id'],
                                  carName: pmp['tat'],
                                  missionTypes: types,
                                  toggleTheme: widget.toggleTheme
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text("INICIAR"),
                        ),
                      ],
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}