import 'package:flutter/material.dart';
import '../../../core/models/structure_models.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_search_field.dart';

class StructureExplorerScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const StructureExplorerScreen({super.key, required this.toggleTheme});

  @override
  State<StructureExplorerScreen> createState() => _StructureExplorerScreenState();
}

class _StructureExplorerScreenState extends State<StructureExplorerScreen> {
  final _supabase = SupabaseService.client;
  
  List<ProductParent> _parents = [];
  List<StructureItem> _structure = [];
  List<StructureItem> _filteredStructure = [];
  ProductParent? _selectedParent;
  final TextEditingController _internalSearchController = TextEditingController();
  
  bool _isLoadingParents = true;
  bool _isLoadingStructure = false;
  
  // Cores do Design System
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => _isDarkMode ? const Color(0xFF121212) : Colors.grey[100]!;
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  final Color _flashYellow = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    try {
      // Simplificação: Buscar direto em produtos onde começa com 7
      final responseProducts = await _supabase
          .from('app_produtos')
          .select('codigo, descricao')
          .like('codigo', '7%')
          .order('codigo');

      final parents = (responseProducts as List).map<ProductParent>((item) {
        return ProductParent(
          code: item['codigo'],
          name: item['descricao'] ?? '',
        );
      }).toList();

      // Garantir ordenação alfabética pelo código na pesquisa
      parents.sort((a, b) => a.code.compareTo(b.code));

      if (mounted) {
        setState(() {
          _parents = parents;
          _isLoadingParents = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingParents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar produtos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadStructure(ProductParent parent) async {
    setState(() {
      _isLoadingStructure = true;
      _structure = [];
      _filteredStructure = [];
      _selectedParent = parent;
      _internalSearchController.clear();
    });

    try {
      // 1. Buscar estrutura plana
      final structureData = await _supabase
          .from('app_estrutura_simples')
          .select()
          .eq('cod_raiz', parent.code);

      // 2. Coletar códigos para buscar detalhes
      final List<String> componentCodes = (structureData as List)
          .map((e) => e['cod_filho'] as String)
          .toSet()
          .toList();

      // 3. Buscar detalhes dos componentes (descrição, unidade)
      Map<String, dynamic> productsMap = {};
      if (componentCodes.isNotEmpty) {
        final productsData = await _supabase
            .from('app_produtos')
            .select('codigo, descricao, unidade')
            .inFilter('codigo', componentCodes);
        
        productsMap = {
          for (var item in (productsData as List)) item['codigo']: item
        };
      }

      // 4. Montar objetos StructureItem
      final structure = (structureData as List).map<StructureItem>((item) {
        final code = item['cod_filho'];
        final details = productsMap[code];
        return StructureItem(
          nivel: item['nivel'],
          codComponente: code,
          descComponente: details?['descricao'] ?? 'Item não encontrado',
          unid: details?['unidade'] ?? '-',
          qtdTotalAcum: (item['qtd_unitaria'] as num).toDouble(),
          fixVar: item['fix_var'] ?? 'V',
          dataInicial: item['data_adicao'],
          codPai: item['cod_pai'] ?? '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _structure = structure;
          _filteredStructure = structure;
          _isLoadingStructure = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingStructure = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar estrutura: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterStructure(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStructure = _structure;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredStructure = _structure.where((item) {
          return item.codComponente.toLowerCase().contains(lowerQuery) ||
                 item.descComponente.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _resetSelection() {
    setState(() {
      _selectedParent = null;
      _structure = [];
      _filteredStructure = [];
      _internalSearchController.clear();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      // Tenta parsear ISO 8601 (YYYY-MM-DD)
      DateTime? date = DateTime.tryParse(dateStr);
      // Se falhar e for YYYYMMDD (comum em ERPs)
      if (date == null && dateStr.length == 8) {
         int year = int.parse(dateStr.substring(0, 4));
         int month = int.parse(dateStr.substring(4, 6));
         int day = int.parse(dateStr.substring(6, 8));
         date = DateTime(year, month, day);
      }
      if (date != null) {
        return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          "ESTRUTURA SIMPLES",
          style: TextStyle(
            color: _flashYellow, 
            letterSpacing: 2, 
            fontWeight: FontWeight.bold
          ),
        ),
        leadingWidth: 100,
        leading: Row(
          children: [
            const BackButton(),
            IconButton(icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: widget.toggleTheme),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Header: Seletor de Produto
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedParent == null ? "Selecione o Produto Pai" : "Produto: ${_selectedParent!.code}",
                      style: TextStyle(color: _isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 12)
                    ),
                    if (_selectedParent != null)
                      GestureDetector(
                        onTap: _resetSelection,
                        child: Text("TROCAR", style: TextStyle(color: _flashYellow, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                _isLoadingParents 
                  ? LinearProgressIndicator(color: _flashYellow, backgroundColor: Colors.grey[800])
                  : _selectedParent != null
                    ? CustomSearchField(
                        controller: _internalSearchController,
                        onChanged: _filterStructure,
                        hintText: "Filtrar componentes...",
                      )
                  : Autocomplete<ProductParent>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<ProductParent>.empty();
                        }
                        return _parents.where((ProductParent option) {
                          return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                 option.code.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      displayStringForOption: (ProductParent option) => "${option.code} - ${option.name}",
                      onSelected: (ProductParent selection) {
                        _loadStructure(selection);
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return CustomSearchField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          hintText: "Digite código ou nome...",
                          onSubmitted: (val) => onFieldSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                            elevation: 8.0,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 32,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final ProductParent option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option.name, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
                                    subtitle: Text(option.code, style: TextStyle(color: _flashYellow)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
          
          // 2. Body: Visualização da Árvore
          Expanded(
            child: _isLoadingStructure 
              ? Center(child: CircularProgressIndicator(color: _flashYellow))
              : _filteredStructure.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_tree_outlined, size: 60, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text("Nenhuma estrutura encontrada", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredStructure.length,
                    itemBuilder: (context, index) {
                      final item = _filteredStructure[index];
                      final isLevel1 = item.nivel == 1;
                      final isFixed = item.fixVar == 'F';
                      final formattedDate = _formatDate(item.dataInicial);
                      
                      // Indentação Inteligente
                      final double indent = (item.nivel - 1) * 24.0;

                      return Padding(
                        padding: EdgeInsets.only(left: indent, bottom: 8),
                        child: Card(
                          color: isLevel1 ? (_isDarkMode ? Colors.black : Colors.grey[300]) : (_isDarkMode ? Colors.grey[900] : Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isLevel1 ? BorderSide(color: _flashYellow.withOpacity(0.5)) : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Código, Pai e Qtd
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (item.codPai.isNotEmpty)
                                            Text(
                                              "Pai: ${item.codPai}",
                                              style: TextStyle(color: _isDarkMode ? Colors.grey[600] : Colors.grey[500], fontSize: 10),
                                            ),
                                          Text(
                                            item.codComponente,
                                            style: TextStyle(
                                              color: isLevel1 ? (_isDarkMode ? _flashYellow : Colors.black) : (_isDarkMode ? Colors.white : Colors.black87),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.descComponente,
                                            style: TextStyle(color: _isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${item.qtdTotalAcum}",
                                          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(item.unid, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Divider Discreto
                                Divider(height: 1, color: Colors.grey[800]),
                                const SizedBox(height: 8),
                                // Footer: Data e Badges
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text("Início: $formattedDate", style: TextStyle(color: _isDarkMode ? Colors.grey[500] : Colors.grey[600], fontSize: 11)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFixed ? Colors.blueGrey[900] : Colors.brown[900],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isFixed ? Colors.blueGrey[700]! : Colors.brown[700]!, width: 0.5),
                                      ),
                                      child: Text(
                                        isFixed ? "FIXO" : "VARIÁVEL",
                                        style: TextStyle(
                                          color: isFixed ? Colors.blue[100] : Colors.orange[100],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}