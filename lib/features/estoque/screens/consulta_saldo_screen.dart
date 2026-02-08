import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_search_field.dart';

class ConsultaSaldoScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final String? initialSearchCode;

  const ConsultaSaldoScreen({super.key, required this.toggleTheme, this.initialSearchCode});

  @override
  State<ConsultaSaldoScreen> createState() => _ConsultaSaldoScreenState();
}

class _ConsultaSaldoScreenState extends State<ConsultaSaldoScreen> {
  bool _hasSearched = false;
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  // Acesso centralizado ao cliente Supabase
  final _supabase = SupabaseService.client;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _performSearch(widget.initialSearchCode!));
    }
  }

  Future<void> _performSearch(String queryText) async {
    final query = queryText.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _result = null;
    });

    try {
      // 1. Busca Detalhes do Produto (app_produtos)
      final productData = await _supabase
          .from('app_produtos')
          .select('codigo, descricao')
          .eq('codigo', query)
          .maybeSingle();

      if (productData == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Busca Saldos (app_saldos)
      final saldosData = await _supabase
          .from('app_saldos')
          .select('armazem, endereco, saldo')
          .eq('codigo', query);

      // 3. Busca BI (app_bi_estoque)
      final biData = await _supabase
          .from('app_bi_estoque')
          .select('saldo_total, qtd_empenhada, saldo_livre')
          .eq('codigo', query)
          .maybeSingle();

      // 4. Monta o resultado compatível com a UI
      final result = {
        'codigo': productData['codigo'],
        'descricao': productData['descricao'],
        'bi': biData,
        'saldos': (saldosData as List).map((s) => {
          'armazem': s['armazem'],
          'endereco': s['endereco'],
          'qtd': s['saldo'], // Mapeia 'saldo' do banco para 'qtd' da UI
        }).toList(),
      };

      setState(() {
        _isLoading = false;
        _result = result;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao consultar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const flashYellow = Color(0xFFFFD700);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Consulta de Saldo"),
        leadingWidth: 100,
        leading: Row(
          children: [
            const BackButton(),
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: widget.toggleTheme,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barra de Pesquisa
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.length < 3) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                try {
                  final data = await _supabase
                      .from('app_produtos')
                      .select('codigo, descricao')
                      .or('codigo.ilike.%${textEditingValue.text}%,descricao.ilike.%${textEditingValue.text}%')
                      .limit(10);
                  return List<Map<String, dynamic>>.from(data);
                } catch (e) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
              },
              displayStringForOption: (Map<String, dynamic> option) => option['codigo'],
              onSelected: (Map<String, dynamic> selection) {
                _performSearch(selection['codigo']);
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return CustomSearchField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  hintText: 'Código do Item (Ex: 10.ABS...)',
                  onSubmitted: (String value) => _performSearch(value),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    color: cardColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> option = options.elementAt(index);
                          return ListTile(
                            title: Text(option['codigo'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            subtitle: Text(option['descricao'], style: TextStyle(color: subTextColor, fontSize: 12)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Área de Resultados
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: flashYellow))
            else if (_hasSearched && _result == null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text("Item não encontrado", style: TextStyle(color: subTextColor)),
                  ],
                ),
              )
            else if (_result != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card do Produto
                      Card(
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _result!['codigo'],
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: flashYellow),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _result!['descricao'],
                                style: TextStyle(fontSize: 16, color: textColor),
                              ),
                              if (_result!['bi'] != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildBiStat("Total", _result!['bi']['saldo_total'], Colors.blue, textColor),
                                    _buildBiStat("Empenhado", _result!['bi']['qtd_empenhada'], Colors.orange, textColor),
                                    _buildBiStat("Livre", _result!['bi']['saldo_livre'], Colors.green, textColor),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Seções de Saldo (Ativo e Histórico)
                      ..._buildSplitSections(_result!['saldos'], isDarkMode, textColor, subTextColor, cardColor),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiStat(String label, dynamic value, Color color, Color textColor) {
    final double val = (value as num?)?.toDouble() ?? 0.0;
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(
          NumberFormat.decimalPattern('pt_BR').format(val),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  List<Widget> _buildSplitSections(List<dynamic> saldos, bool isDarkMode, Color textColor, Color? subTextColor, Color cardColor) {
    final activeSaldos = saldos.where((s) => (s['qtd'] as num) > 0).toList();
    final zeroSaldos = saldos.where((s) => (s['qtd'] as num) == 0).toList();

    List<Widget> widgets = [];

    // 1. Saldos Ativos
    widgets.add(const SizedBox(height: 24));
    widgets.add(Text("Saldos por Armazém", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)));
    widgets.add(const SizedBox(height: 12));
    
    if (activeSaldos.isNotEmpty) {
      widgets.addAll(_buildBalanceList(activeSaldos, isDarkMode, textColor, subTextColor));
    } else {
      widgets.add(Text("Nenhum saldo disponível.", style: TextStyle(color: subTextColor)));
    }

    // 2. Endereços Anteriores (Saldo 0)
    if (zeroSaldos.isNotEmpty) {
      widgets.add(const SizedBox(height: 24));
      widgets.add(Text("Endereços Anteriores", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)));
      widgets.add(const SizedBox(height: 12));

      final historyText = zeroSaldos.map((s) => "${s['armazem']}: ${s['endereco']}").join("  |  ");

      widgets.add(Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(width: double.infinity, child: Text(historyText, style: TextStyle(color: subTextColor))),
        ),
      ));
    }

    return widgets;
  }

  List<Widget> _buildBalanceList(List<dynamic> saldos, bool isDarkMode, Color textColor, Color? subTextColor) {
    // Agrupa por Armazém
    final Map<String, List<dynamic>> grouped = {};
    for (var s in saldos) {
      if (!grouped.containsKey(s['armazem'])) grouped[s['armazem']] = [];
      grouped[s['armazem']]!.add(s);
    }

    return grouped.entries.map((entry) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warehouse, size: 20, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text("Armazém: ${entry.key}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                ],
              ),
              const Divider(),
              ...entry.value.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Endereço: ${item['endereco']}", style: TextStyle(color: subTextColor)),
                      Text("${item['qtd']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }).toList();
  }
}