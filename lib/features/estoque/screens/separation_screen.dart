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
  final ScrollController _scrollController = ScrollController();
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          'tipo_item': item['tipo_item'],
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

  Future<String?> _showExcessDialog(BuildContext context, double excessQty) async {
    String? selectedReason;
    final TextEditingController otherReasonController = TextEditingController();
    final reasons = [
      'Peça perdida na linha',
      'Item solicitado a mais',
      'Estrutura errada',
      'Outro'
    ];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Justificativa de Excesso'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Você está pagando ${formatNumber(excessQty)} acima do solicitado.\nDeseja confirmar a operação?',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => selectedReason = v),
                    ),
                    if (selectedReason == 'Outro') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otherReasonController,
                        decoration: const InputDecoration(
                          labelText: 'Detalhe o motivo',
                          border: OutlineInputBorder(),
                        ),
                      )
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedReason == null) return;
                    String finalReason = selectedReason!;
                    if (selectedReason == 'Outro') {
                      if (otherReasonController.text.trim().isEmpty) return;
                      finalReason = "Outro: ${otherReasonController.text.trim()}";
                    }
                    Navigator.pop(context, finalReason);
                  },
                  child: const Text('CONFIRMAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSubstituteDialog(Map<String, dynamic> item) async {
    final currentCode = item['componente'];
    final tipoItem = item['tipo_item'];
    
    // Define a função RPC baseada no tipo
    final functionName = (tipoItem == 'METÁLICO') 
        ? 'fn_buscar_familia_miolo' 
        : 'fn_buscar_familia_sufixo';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
    );

    try {
      final List<dynamic> response = await _supabase.rpc(functionName, params: {'p_codigo': currentCode});
      
      if (mounted) {
        Navigator.pop(context); // Fecha o loading
        
        if (response.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum substituto encontrado.')),
          );
          return;
        }

        showDialog(
          context: context,
          builder: (ctx) {
            // Variáveis locais para o Dialog (StatefulBuilder)
            List<dynamic> filteredList = List.from(response);
            final TextEditingController dialogSearchController = TextEditingController();

            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: Text("Trocar $currentCode", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), // Fonte menor
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400, // Altura fixa para caber a lista
                    child: Column(
                      children: [
                        CustomSearchField(
                          controller: dialogSearchController,
                          hintText: 'Buscar substituto...',
                          autofocus: true,
                          onChanged: (query) {
                            setStateDialog(() {
                              if (query.isEmpty) {
                                filteredList = List.from(response);
                              } else {
                                filteredList = response.where((option) {
                                  return option['codigo'].toString().toLowerCase().contains(query.toLowerCase()) ||
                                         (option['descricao'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
                                }).toList();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (ctx, index) {
                              final prod = filteredList[index];
                              return ListTile(
                                title: Text(prod['codigo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(prod['descricao'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await _replaceProduct(item['id'], prod['codigo']);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CANCELAR"),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha o loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar substitutos: $e')),
        );
      }
    }
  }

  Future<void> _replaceProduct(String listId, String newCode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
    );

    try {
      await _supabase
          .from('app_lista_separacao')
          .update({'produto': newCode})
          .eq('id', listId);
      
      await _loadData();
      
      if (mounted) {
        Navigator.pop(context); // Fecha o loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item trocado para $newCode')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha o loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao trocar produto: $e')),
        );
      }
    }
  }

  void showSeparationDialog(Map<String, dynamic> item, Color cardColor, Color textColor, Color subTextColor, Color flashYellow, bool isDarkMode) {
    final double qtdSeparadaAtual = (item['qtdSeparada'] as num).toDouble();
    final double qtdTotal = (item['qtdTotal'] as num).toDouble();
    final double remaining = qtdTotal - qtdSeparadaAtual;
    final TextEditingController qtdController = TextEditingController();
    
    final bool controlsAddress = item['controla_endereco'] ?? true;
    final List<dynamic> addresses = item['lista_enderecos'] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        bool localIsEstorno = false;
        
        // Lista de endereços para o Dropdown
        List<String> availableAddresses = [];
        if (addresses.isNotEmpty) {
          availableAddresses = addresses.map((e) => e['endereco'].toString()).toList();
        } else {
          availableAddresses = ['RECEBIMENTO'];
        }
        
        String? selectedAddress = availableAddresses.isNotEmpty ? availableAddresses.first : null;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
          backgroundColor: cardColor,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          title: Text(localIsEstorno ? "Estornar Item" : "Separar Item", style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item['componente'], style: TextStyle(color: flashYellow, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                
                // Seção de Endereços (Apenas se controlar endereço)
                if (controlsAddress) ...[
                  DropdownButtonFormField<String>(
                    value: selectedAddress,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor, fontSize: 16),
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
                            setStateDialog(() {
                              if (!availableAddresses.contains(result)) {
                                availableAddresses.add(result);
                              }
                              selectedAddress = result;
                            });
                          }
                        },
                      ),
                    ),
                    items: availableAddresses.map((addr) {
                      final matches = addresses.where((e) => e['endereco'] == addr);
                      final info = matches.isNotEmpty ? matches.first : null;
                      final text = info != null ? "$addr (${formatNumber(info['saldo'])})" : addr;
                      return DropdownMenuItem(
                        value: addr,
                        child: Text(text),
                      );
                    }).toList(),
                    onChanged: (val) => setStateDialog(() => selectedAddress = val),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: localIsEstorno ? "DISPONÍVEL" : "A SEPARAR",
                          labelStyle: TextStyle(color: subTextColor),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        textAlign: TextAlign.center,
                        child: Text(
                          formatNumber(localIsEstorno ? qtdSeparadaAtual : remaining),
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
                          labelText: localIsEstorno ? "QTD ESTORNO" : "SEPARADO",
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      localIsEstorno ? "MODO ESTORNO" : "MODO SEPARAÇÃO",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: localIsEstorno ? Colors.red : textColor,
                      ),
                    ),
                    Switch(
                      value: localIsEstorno,
                      activeColor: Colors.red,
                      inactiveThumbColor: flashYellow,
                      onChanged: (val) => setStateDialog(() => localIsEstorno = val),
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
                    
                    if (qtdSeparadaInput <= 0) {
                      Navigator.pop(context);
                      return;
                    }

                    final user = _supabase.auth.currentUser;
                    if (user == null) return;

                    String enderecoFinal = '';
                    if (controlsAddress) {
                      enderecoFinal = selectedAddress ?? 'RECEBIMENTO';
                    }

                    if (localIsEstorno) {
                      if (qtdSeparadaInput > qtdSeparadaAtual) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Quantidade de estorno maior que a separada!')),
                        );
                        return;
                      }

                      await _supabase.from('app_log_separacao').insert({
                        'id_lista': item['id'],
                        'user_id': user.id,
                        'qtd_movimentada': qtdSeparadaInput,
                        'endereco_retirada_real': enderecoFinal,
                        'armazem_destino': item['armazem_destino'] ?? '',
                        'tipo_movimento': 'ESTORNO',
                        'data_hora': DateTime.now().toIso8601String(),
                        'observacao': 'Estorno via App',
                        'produto': item['componente'],
                      });

                      _loadData();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estorno realizado!')));
                      }
                      return;
                    }
                  
                    // O quanto falta para completar (se for negativo, é 0)
                    final needed = remaining > 0 ? remaining : 0.0;

                    double normalQty = 0.0;
                    double excessQty = 0.0;

                    if (qtdSeparadaInput > needed) {
                      normalQty = needed;
                      excessQty = qtdSeparadaInput - needed;
                    } else {
                      normalQty = qtdSeparadaInput;
                      excessQty = 0.0;
                    }

                    String? justification;
                    if (excessQty > 0) {
                      justification = await _showExcessDialog(context, excessQty);
                      if (justification == null) return; // Cancelou a justificativa
                    }

                    try {
                      final timestamp = DateTime.now().toIso8601String();
                      
                      // 1. Log Normal (se houver)
                      if (normalQty > 0) {
                        await _supabase.from('app_log_separacao').insert({
                          'id_lista': item['id'],
                          'user_id': user.id,
                          'qtd_movimentada': normalQty,
                          'endereco_retirada_real': enderecoFinal,
                          'armazem_destino': item['armazem_destino'] ?? '',
                          'tipo_movimento': 'SEPARACAO',
                          'data_hora': timestamp,
                          'produto': item['componente'],
                        });
                      }

                      // 2. Log Excedente (se houver)
                      if (excessQty > 0) {
                         await _supabase.from('app_log_separacao').insert({
                          'id_lista': item['id'],
                          'user_id': user.id,
                          'qtd_movimentada': excessQty,
                          'endereco_retirada_real': enderecoFinal,
                          'armazem_destino': item['armazem_destino'] ?? '',
                          'tipo_movimento': 'SEPARACAO',
                          'data_hora': timestamp, 
                          'observacao': "Excesso: $justification",
                          'produto': item['componente'],
                        });
                      }
                      
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
                  style: ElevatedButton.styleFrom(backgroundColor: localIsEstorno ? Colors.red : flashYellow, foregroundColor: localIsEstorno ? Colors.white : Colors.black),
                  child: Text(localIsEstorno ? "ESTORNAR" : "CONFIRMAR"),
                ),
              ],
            ),
          ],
        );
          },
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
                  controller: _scrollController,
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
                          onSwap: () => _showSubstituteDialog(item),
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
                              onSwap: () => _showSubstituteDialog(item),
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
  final VoidCallback? onSwap;
  final String Function(num) formatNumber;

  const SeparationItemCard({
    super.key,
    required this.item,
    required this.cardColor,
    required this.flashYellow,
    required this.textColor,
    required this.subTextColor,
    required this.onTap,
    this.onSwap,
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item['componente'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: flashYellow),
                          ),
                        ),
                        if (onSwap != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: InkWell(
                              onTap: onSwap,
                              child: Icon(Icons.swap_horiz, color: subTextColor, size: 20),
                            ),
                          ),
                      ],
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