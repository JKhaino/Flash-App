import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../main.dart';
import '../../../core/widgets/custom_drawer.dart';

class PmpScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const PmpScreen({super.key, required this.toggleTheme});

  @override
  State<PmpScreen> createState() => _PmpScreenState();
}

class _PmpScreenState extends State<PmpScreen> {
  final _supabase = SupabaseService.client;
  List<Map<String, dynamic>> _pmps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPmps();
  }

  Future<void> _fetchPmps() async {
    try {
      final data = await _supabase
          .from('app_pmp')
          .select()
          .order('id', ascending: false);
      
      final pmpsList = List<Map<String, dynamic>>.from(data);

      // Buscar descrições dos produtos (carros)
      if (pmpsList.isNotEmpty) {
        final codes = pmpsList.map((e) => e['cod_estrutura'] as String).toSet().toList();
        final pmpIds = pmpsList.map((e) => e['id']).toList();

        final productsData = await _supabase
            .from('app_produtos')
            .select('codigo, descricao')
            .inFilter('codigo', codes);
        
        // Buscar atribuições para saber quais tipos já têm dono
        final assignmentsData = await _supabase
            .from('app_atribuicoes')
            .select('id_pmp, tipo_responsavel')
            .inFilter('id_pmp', pmpIds);
            
        final descMap = {for (var p in productsData) p['codigo']: p['descricao']};
        
        // Mapear atribuições por PMP
        final assignmentsMap = <int, Set<String>>{};
        for (var a in assignmentsData) {
          assignmentsMap.putIfAbsent(a['id_pmp'], () => {}).add(a['tipo_responsavel']);
        }
        
        for (var pmp in pmpsList) {
          pmp['descricao_carro'] = descMap[pmp['cod_estrutura']];
          pmp['assigned_types'] = assignmentsMap[pmp['id']] ?? <String>{};
        }
      }

      if (mounted) {
        setState(() {
          _pmps = pmpsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar PMPs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de PMP"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const FlashApp()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: CustomDrawer(toggleTheme: widget.toggleTheme, module: 'ESTOQUE'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
        : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pmps.length,
        itemBuilder: (context, index) {
          final item = _pmps[index];
          final tat = item['tat'] ?? 'Sem TAT';
          final codEstrutura = item['cod_estrutura'] ?? '';
          final descricao = item['descricao_carro'] ?? '...';
          final status = item['status'] ?? 'AGUARDANDO';
          final id = item['id'];
          final assignedTypes = item['assigned_types'] as Set<String>? ?? {};

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$tat",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "$codEstrutura",
                        style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricao,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (ctx) => AssignmentSheet(pmpId: id, tat: tat),
                              );
                              _fetchPmps(); // Atualiza os indicadores ao voltar
                            },
                            icon: const Icon(Icons.person_add, color: Color(0xFFFFD700)),
                            label: const Text("Atribuir", style: TextStyle(color: Color(0xFFFFD700))),
                          ),
                          Row(
                            children: [
                              _buildIndicator('C', 'COMPRADO', assignedTypes),
                              _buildIndicator('F', 'FIXADOR', assignedTypes),
                              _buildIndicator('M', 'METÁLICO', assignedTypes),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'MONTADO': return Colors.blue[100]!;
      case 'APONTADO': return Colors.green[100]!;
      default: return Colors.grey[300]!;
    }
  }

  Widget _buildIndicator(String letter, String type, Set<String> assignedTypes) {
    final isAssigned = assignedTypes.contains(type);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAssigned ? Colors.green : Colors.grey[300],
        border: isAssigned ? null : Border.all(color: Colors.grey[400]!),
      ),
      child: Text(letter, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAssigned ? Colors.white : Colors.grey[600])),
    );
  }
}

class AssignmentSheet extends StatefulWidget {
  final int pmpId;
  final String tat;

  const AssignmentSheet({super.key, required this.pmpId, required this.tat});

  @override
  State<AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<AssignmentSheet> {
  final _supabase = SupabaseService.client;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _existingAssignments = [];
  bool _isLoading = true;
  bool _showForm = false;

  String? _selectedUserId;
  String? _selectedType;
  final List<String> _allTypes = ['METÁLICO', 'COMPRADO', 'FIXADOR'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Buscar Usuários Ativos
      final dataUsers = await _supabase
          .from('app_usuarios')
          .select('id, nome')
          .eq('ativo', true)
          .order('nome');
      
      final usersList = List<Map<String, dynamic>>.from(dataUsers);

      // 2. Buscar Atribuições Existentes (Sem Join automático para evitar erros)
      final dataAssignments = await _supabase
          .from('app_atribuicoes')
          .select('id, tipo_responsavel, user_id')
          .eq('id_pmp', widget.pmpId);

      final assignmentsList = List<Map<String, dynamic>>.from(dataAssignments);

      // 3. Enriquecer com nomes manualmente
      if (assignmentsList.isNotEmpty) {
        final userIds = assignmentsList.map((e) => e['user_id']).toList();
        final namesData = await _supabase.from('app_usuarios').select('id, nome').inFilter('id', userIds);
        final namesMap = {for (var u in namesData) u['id']: u['nome']};
        
        for (var item in assignmentsList) {
          item['username_display'] = namesMap[item['user_id']] ?? 'Desconhecido';
        }
      }

      if (mounted) {
        setState(() {
          _users = usersList;
          _existingAssignments = assignmentsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filtra apenas os tipos que ainda NÃO foram atribuídos
  List<String> get _availableTypes {
    final taken = _existingAssignments.map((e) => e['tipo_responsavel'].toString()).toSet();
    return _allTypes.where((t) => !taken.contains(t)).toList();
  }

  Future<void> _saveAssignment() async {
    if (_selectedUserId == null || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    try {
      await _supabase.from('app_atribuicoes').insert({
        'id_pmp': widget.pmpId,
        'user_id': _selectedUserId,
        'tipo_responsavel': _selectedType!,
      });

      // Recarrega a lista e limpa o formulário
      await _loadData();

      if (mounted) {
        setState(() {
          _showForm = false;
          _selectedUserId = null;
          _selectedType = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atribuição realizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atribuir: $e')),
        );
      }
    }
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      await _supabase.from('app_atribuicoes').delete().eq('id', id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao remover: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[800] : Colors.grey[100];
    const flashYellow = Color(0xFFFFD700);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Equipe - ${widget.tat}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: flashYellow)))
          else ...[
            // 1. Lista de quem já está atribuído
            if (_existingAssignments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text("Ninguém atribuído ainda.", style: TextStyle(color: Colors.grey[600])),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingAssignments.length,
                itemBuilder: (context, index) {
                  final item = _existingAssignments[index];
                  final nome = item['username_display'] ?? '...';
                  final type = item['tipo_responsavel'];
                  
                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, color: flashYellow),
                      title: Text(nome, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      subtitle: Text(type, style: TextStyle(color: Colors.grey[500])),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteAssignment(item['id']),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 2. Área de Nova Atribuição
            if (!_showForm)
              if (_availableTypes.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showForm = true),
                    icon: const Icon(Icons.add, color: flashYellow),
                    label: const Text("ADICIONAR MEMBRO", style: TextStyle(color: flashYellow, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Center(child: Text("Equipe completa!", style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold)))
            else ...[
              Text("Nova Atribuição", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(
                labelText: 'Selecione o Operador',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _users.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'],
                  child: Text(user['nome'], style: TextStyle(color: textColor)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedUserId = value),
              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo de Item',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              // Mostra apenas tipos DISPONÍVEIS
              items: _availableTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type, style: TextStyle(color: textColor)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedType = value),
              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _showForm = false),
                    child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: flashYellow,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("SALVAR"),
                  ),
                ),
              ],
            ),
            ]
          ]
        ],
      ),
    );
  }
}