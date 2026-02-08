import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_search_field.dart';
import '../../../core/widgets/scanner_page.dart';

class SeparationScreen extends StatefulWidget {
  final int pmpId;
  final String carName;
  final List<String> missionTypes;
  final VoidCallback toggleTheme;

  const SeparationScreen({super.key, required this.pmpId, required this.carName, required this.missionTypes, required this.toggleTheme});

  @override
  State<SeparationScreen> createState() => _SeparationScreenState();
}

class _SeparationScreenState extends State<SeparationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = SupabaseService.client;
  
  // Estado para controle dos dados e filtro
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Buscar itens da lista de separação
      final listData = await _supabase
          .from('app_lista_separacao')
          .select()
          .eq('id_pmp', widget.pmpId)
          .inFilter('tipo_item', widget.missionTypes);

      if ((listData as List).isEmpty) {
        setState(() { _allItems = []; _filteredItems = []; _isLoading = false; });
        return;
      }

      // 2. Coletar códigos para buscar detalhes
      final productCodes = listData.map((e) => e['produto'] as String).toSet().toList();

      // 3. Buscar descrições (app_produtos)
      final productsData = await _supabase
          .from('app_produtos')
          .select('codigo, descricao')
          .inFilter('codigo', productCodes);
      final productsMap = { for (var p in productsData) p['codigo']: p['descricao'] };

      // 4. Buscar saldos/localização (app_saldos)
      // Estratégia: Buscar endereços do armazém 01 e verificar flag de controle
      final saldosData = await _supabase
          .from('app_saldos')
          .select('codigo, endereco, saldo, controla_endereco')
          .eq('armazem', '01')
          .inFilter('codigo', productCodes);
      
      final allLocationsMap = <String, List<Map<String, dynamic>>>{};
      final controlAddressMap = <String, bool>{};

      for (var s in saldosData) {
        final code = s['codigo'];
        final saldo = s['saldo'] as num;
        
        // Captura flag de controle (assume consistência por produto)
        controlAddressMap[code] = s['controla_endereco'] ?? false;

        if (saldo > 0) {
          if (!allLocationsMap.containsKey(code)) {
            allLocationsMap[code] = [];
          }
          allLocationsMap[code]!.add(s);
        }
      }

      // 5. Montar lista final
      final merged = listData.map<Map<String, dynamic>>((item) {
        final code = item['produto'];
        final allLocs = allLocationsMap[code] ?? [];
        
        // Ordena por saldo decrescente
        allLocs.sort((a, b) => (b['saldo'] as num).compareTo(a['saldo'] as num));

        // Monta string de exibição (separada por |)
        final displayLoc = allLocs.map((e) => e['endereco']).join(' | ');
        
        // Define se controla endereço (default true se não encontrado, para garantir fluxo de RECEBIMENTO se necessário)
        final bool controlsAddress = controlAddressMap[code] ?? true;

        return {
          'id': item['id'], // UUID da linha na lista
          'componente': code,
          'descricao': productsMap[code] ?? 'Descrição não encontrada',
          'qtdTotal': item['qtd_total_calc'],
          'qtdSeparada': item['qtd_separada'] ?? 0,
          'localizacao': displayLoc,
          'saldo': allLocs.fold<num>(0, (p, c) => p + (c['saldo'] as num)),
          'isSub': item['armazem_destino'] == '58',
          'armazem_destino': item['armazem_destino'],
          'lista_enderecos': allLocs,
          'controla_endereco': controlsAddress,
        };
      }).toList();

      // 6. Ordenação Determinística (Armazém Destino -> Componente)
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
          final loc = item['localizacao'].toString().toLowerCase();
          return comp.contains(lowerQuery) || desc.contains(lowerQuery) || loc.contains(lowerQuery);
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

  void showSeparationDialog(Map<String, dynamic> item, Color cardColor, Color textColor, Color subTextColor, Color flashYellow, bool isDarkMode) {
    final remaining = (item['qtdTotal'] as num) - (item['qtdSeparada'] as num);
    final TextEditingController qtdController = TextEditingController();
    
    final bool controlsAddress = item['controla_endereco'] ?? true;
    final List<dynamic> addresses = item['lista_enderecos'] ?? [];
    
    // Define texto inicial do endereço
    String initialAddress = '';
    if (controlsAddress) {
      initialAddress = addresses.isNotEmpty ? addresses.first['endereco'] : '';
    }

    // Controller para o endereço, permitindo edição
    final TextEditingController addressController = TextEditingController(text: initialAddress);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          title: Text("Separar Item", style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item['componente'], style: TextStyle(color: flashYellow, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                
                // Seção de Endereços (Apenas se controlar endereço)
                if (controlsAddress) ...[
                  if (addresses.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Endereços Disponíveis (01):", style: TextStyle(color: subTextColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: addresses.map((addr) {
                        return InkWell(
                          onTap: () => addressController.text = addr['endereco'],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: subTextColor),
                              borderRadius: BorderRadius.circular(12),
                              color: cardColor,
                            ),
                            child: Text(
                              "${addr['endereco']} (${formatNumber(addr['saldo'])})",
                              style: TextStyle(fontSize: 11, color: textColor),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                     Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Sugestão:", style: TextStyle(color: subTextColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => addressController.text = 'RECEBIMENTO',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(12),
                          color: cardColor,
                        ),
                        child: Text("RECEBIMENTO", style: TextStyle(fontSize: 11, color: textColor)),
                      ),
                    ),
                     const SizedBox(height: 12),
                  ],

                  // Campo de Endereço Editável
                  TextField(
                    controller: addressController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: "Endereço de Retirada",
                      labelStyle: TextStyle(color: subTextColor),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: flashYellow)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.qr_code_scanner, color: flashYellow),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ScannerPage()),
                          );
                          if (result is String && result != '-1' && context.mounted) {
                            addressController.text = result;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "A SEPARAR",
                          labelStyle: TextStyle(color: subTextColor),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        textAlign: TextAlign.center,
                        child: Text(
                          formatNumber(remaining),
                          style: TextStyle(color: textColor, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: qtdController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 20),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: "SEPARADO",
                          labelStyle: TextStyle(color: subTextColor),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        autofocus: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("CANCELAR", style: TextStyle(color: subTextColor)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final qtdSeparadaInput = double.tryParse(qtdController.text.replaceAll(',', '.')) ?? 0;
                    
                    if (qtdSeparadaInput == 0) {
                      Navigator.pop(context);
                      return;
                    }

                    final user = _supabase.auth.currentUser;

                    if (user == null) return;
                    
                    // Atualiza no banco (Inserindo no Log para disparar Trigger)
                    String enderecoFinal = '';
                    if (controlsAddress) {
                      enderecoFinal = addressController.text.trim().isEmpty ? 'RECEBIMENTO' : addressController.text.trim();
                    }
                    // Se não controla endereço, envia vazio

                    try {
                      await _supabase.from('app_log_separacao').insert({
                        'id_lista': item['id'],
                        'user_id': user.id,
                        'qtd_movimentada': qtdSeparadaInput,
                        'endereco_retirada_real': enderecoFinal,
                        'armazem_destino': item['armazem_destino'] ?? '',
                        'tipo_movimento': 'SEPARACAO',
                        'data_hora': DateTime.now().toIso8601String(),
                      });
                      
                      // Recarrega a lista
                      _loadData();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Item ${item['componente']} confirmado!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        // Exibe o erro real para facilitar o diagnóstico
                        final msg = e.toString().contains('SocketException') 
                            ? 'Sem conexão com a internet.' 
                            : 'Erro no banco: $e';
                            
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: flashYellow, foregroundColor: Colors.black),
                  child: const Text("CONFIRMAR"),
                ),
              ],
            )
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

    // Separa os itens em duas listas
    final pendingItems = _filteredItems.where((item) {
      final remaining = (item['qtdTotal'] as num) - (item['qtdSeparada'] as num);
      return remaining.abs() > 0.001; // Mostra se for positivo (pendente) ou negativo (erro)
    }).toList();

    final completedItems = _filteredItems.where((item) {
      final remaining = (item['qtdTotal'] as num) - (item['qtdSeparada'] as num);
      return remaining.abs() <= 0.001; // Exatamente zero
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.carName}"),
        leadingWidth: 100, // Espaço para botão voltar + botão tema
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
              hintText: 'Pesquisar código, descrição...',
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    // Lista de Pendentes (e Erros)
                    ...pendingItems.map((item) => SeparationItemCard(
                          item: item,
                          cardColor: cardColor,
                          flashYellow: flashYellow,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () => showSeparationDialog(item, cardColor, textColor, subTextColor ?? Colors.grey, flashYellow, isDarkMode),
                          formatNumber: formatNumber,
                        )),

                    // Seção de Concluídos (Oculta por padrão)
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
                                "Separados (${completedItems.length})",
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
                        ...completedItems.map((item) => SeparationItemCard(
                              item: item,
                              cardColor: cardColor,
                              flashYellow: flashYellow,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              onTap: () => showSeparationDialog(item, cardColor, textColor, subTextColor ?? Colors.grey, flashYellow, isDarkMode),
                              formatNumber: formatNumber,
                            )),
                    ],
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class SeparationItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color cardColor;
  final Color flashYellow;
  final Color textColor;
  final Color? subTextColor;
  final VoidCallback onTap;
  final String Function(num) formatNumber;

  const SeparationItemCard({
    super.key,
    required this.item,
    required this.cardColor,
    required this.flashYellow,
    required this.textColor,
    required this.subTextColor,
    required this.onTap,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (item['qtdTotal'] as num) - (item['qtdSeparada'] as num);
    final isNegative = remaining < -0.001; // Verifica se separou a mais (erro)

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.hardEdge,
      shape: isNegative 
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null, // Usa o padrão se não for negativo
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['componente'],
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: flashYellow),
                    ),
                  ),
                  if (item['isSub'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[900],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("SUB", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['descricao'],
                      style: TextStyle(fontSize: 12, color: subTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Saldo: ${formatNumber(item['saldo'] as num)}",
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['localizacao'],
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "OK: ${formatNumber(item['qtdSeparada'] as num)}",
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: flashYellow),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Sep: ${formatNumber((item['qtdTotal'] as num) - (item['qtdSeparada'] as num))}",
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}