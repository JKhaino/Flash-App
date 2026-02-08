import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_search_field.dart';

class AbastecimentoScreen extends StatefulWidget {
  final int pmpId;
  final String carName;
  final VoidCallback toggleTheme;

  const AbastecimentoScreen({
    super.key,
    required this.pmpId,
    required this.carName,
    required this.toggleTheme,
  });

  @override
  State<AbastecimentoScreen> createState() => _AbastecimentoScreenState();
}

class _AbastecimentoScreenState extends State<AbastecimentoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = SupabaseService.client;
  
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Buscar itens da lista de separação (apenas os já separados)
      final listData = await _supabase
          .from('app_lista_separacao')
          .select()
          .eq('id_pmp', widget.pmpId)
          .gt('qtd_separada', 0); // REGRA: Apenas itens com quantidade separada > 0

      if ((listData as List).isEmpty) {
        setState(() { _allItems = []; _filteredItems = []; _isLoading = false; });
        return;
      }

      // 2. Coletar códigos para buscar descrições
      final productCodes = listData.map((e) => e['produto'] as String).toSet().toList();

      // 3. Buscar descrições (app_produtos)
      final productsData = await _supabase
          .from('app_produtos')
          .select('codigo, descricao')
          .inFilter('codigo', productCodes);
      final productsMap = { for (var p in productsData) p['codigo']: p['descricao'] };

      // 4. Montar lista final
      final merged = listData.map<Map<String, dynamic>>((item) {
        final code = item['produto'];
        
        return {
          'id': item['id'],
          'componente': code,
          'descricao': productsMap[code] ?? 'Descrição não encontrada',
          'qtdTotal': item['qtd_total_calc'],
          'qtdSeparada': item['qtd_separada'] ?? 0,
          'qtdAbastecida': item['qtd_abastecida'] ?? 0,
          'armazem_destino': item['armazem_destino'],
          'isSub': item['armazem_destino'] == '58',
        };
      }).toList();

      // 5. Ordenação (Armazém Destino -> Componente)
      merged.sort((a, b) {
        final armA = (a['armazem_destino'] ?? '').toString();
        final armB = (b['armazem_destino'] ?? '').toString();
        final int armResult = armA.compareTo(armB);
        if (armResult != 0) return armResult;
        
        return (a['componente'] as String).compareTo(b['componente'] as String);
      });

      if (mounted) {
        setState(() {
          _allItems = merged;
          _filteredItems = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _filterList(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      if (lowerQuery.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems.where((item) {
          final comp = item['componente'].toString().toLowerCase();
          final desc = item['descricao'].toString().toLowerCase();
          final dest = (item['armazem_destino'] ?? '').toString().toLowerCase();
          return comp.contains(lowerQuery) || desc.contains(lowerQuery) || dest.contains(lowerQuery);
        }).toList();
      }
    });
  }

  String formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _handleAbastecimento() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um item para abastecer.')),
      );
      return;
    }

    // 1. Pedir o Box
    final box = await _showBoxDialog();
    if (box == null || box.trim().isEmpty) return;

    // 2. Abrir Câmera
    final ImagePicker picker = ImagePicker();
    // Nota: Requer pacote image_picker no pubspec.yaml
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    
    if (photo == null) return; // Usuário cancelou a foto

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Usuário não logado");

      final timestamp = DateTime.now().toIso8601String();

      for (final id in _selectedIds) {
        final item = _allItems.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
        if (item.isEmpty) continue;

        // Calcula o que falta entregar (Delta)
        final qtdEntregarAgora = (item['qtdSeparada'] as num) - (item['qtdAbastecida'] as num);

        // 3. Salvar no Log
        await _supabase.from('app_log_abastecimento').insert({
          'id_lista': id,
          'user_id': user.id,
          'data_hora': timestamp,
          'qtd_entregue': qtdEntregarAgora,
          'box': box,
          'foto_url': 'https://placeholder.com/image.jpg', // URL Teste
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abastecimento registrado com sucesso!')),
      );

      _selectedIds.clear();
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showBoxDialog() {
    String boxValue = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Informar Box'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Qual o Box abastecido?',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => boxValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, boxValue),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const flashYellow = Color(0xFFFFD700);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    // Separação das listas
    final pendingItems = _filteredItems.where((item) {
      return (item['qtdSeparada'] as num) > (item['qtdAbastecida'] as num);
    }).toList();

    final completedItems = _filteredItems.where((item) {
      return (item['qtdSeparada'] as num) <= (item['qtdAbastecida'] as num);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Abastecimento - ${widget.carName}"),
        leadingWidth: 100,
        leading: Row(
          children: [
            const BackButton(),
            IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: widget.toggleTheme),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomSearchField(
              controller: _searchController,
              onChanged: _filterList,
              hintText: 'Pesquisar código, descrição, destino...',
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (pendingItems.isEmpty && completedItems.isEmpty)
                      Center(child: Text("Nenhum item separado para abastecer.", style: TextStyle(color: subTextColor))),
                    
                    // Lista de Pendentes
                    ...pendingItems.map((item) => _buildItemCard(item, cardColor, flashYellow, textColor, subTextColor, isCompleted: false)),

                    // Seção de Concluídos (Abastecidos)
                    if (completedItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => setState(() => _showCompleted = !_showCompleted),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                _showCompleted ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                color: subTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Abastecidos (${completedItems.length})",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Expanded(child: Divider(indent: 16)),
                            ],
                          ),
                        ),
                      ),
                      if (_showCompleted)
                        ...completedItems.map((item) => _buildItemCard(item, cardColor.withOpacity(0.6), flashYellow.withOpacity(0.5), textColor.withOpacity(0.7), subTextColor, isCompleted: true)),
                    ],
                  ],
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleAbastecimento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: flashYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("ABASTECER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, Color cardColor, Color flashYellow, Color textColor, Color? subTextColor, {required bool isCompleted}) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (!isCompleted) // Só mostra checkbox se não estiver completo
              Transform.scale(
                scale: 1.3,
                child: Checkbox(
                  value: _selectedIds.contains(item['id'].toString()),
                  activeColor: const Color(0xFFFFD700), // Sempre amarelo forte no ativo
                  checkColor: Colors.black,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(item['id'].toString());
                      } else {
                        _selectedIds.remove(item['id'].toString());
                      }
                    });
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.check_circle, color: Colors.green),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['componente'],
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: flashYellow),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['descricao'],
                    style: TextStyle(fontSize: 12, color: subTextColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(isCompleted ? "ENTREGUE" : "A ENTREGAR", style: TextStyle(color: subTextColor, fontSize: 8)),
                Text(
                  formatNumber(isCompleted 
                      ? (item['qtdAbastecida'] as num) 
                      : (item['qtdSeparada'] as num) - (item['qtdAbastecida'] as num)),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
