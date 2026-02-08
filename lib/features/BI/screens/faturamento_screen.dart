import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import 'estoque_screen.dart';

class FaturamentoScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const FaturamentoScreen({super.key, required this.toggleTheme});

  @override
  State<FaturamentoScreen> createState() => _FaturamentoScreenState();
}

class _FaturamentoScreenState extends State<FaturamentoScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final _authService = AuthService();

  // Filtro de Data
  DateTime _selectedDate = DateTime.now();

  // Dados
  Map<String, dynamic>? _kpis;
  List<Map<String, dynamic>> _rankingClientes = [];
  List<Map<String, dynamic>> _historicoFaturamento = [];
  
  // Dados Processados para o Gráfico (Performance)
  List<FlSpot> _spotsBase = []; // Ano Anterior
  List<FlSpot> _spotsRealized = []; // Ano Atual (Realizado)
  List<FlSpot> _spotsProjected = []; // Ano Atual (Projeção)
  double _growthPercentage = 0.0;
  int _visibleClientsCount = 5;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = SupabaseService.client;
      final mes = _selectedDate.month;
      final ano = _selectedDate.year;

      // 1. KPIs do Mês
      final kpisResponse = await client.rpc('get_kpis_faturamento_mes', params: {
        'p_mes': mes,
        'p_ano': ano,
      });

      // 2. Ranking de Clientes
      final rankingResponse = await client.rpc('get_faturamento_cliente_mensal', params: {
        'p_mes': mes,
        'p_ano': ano,
      });

      // 3. Histórico (Carrega apenas uma vez ou sempre para garantir atualização)
      final historicoResponse = await client.rpc('get_faturamento_mensal');
      
      // Processa os dados do gráfico AQUI, uma única vez, e não no build
      final historicoList = List<Map<String, dynamic>>.from(historicoResponse as List? ?? []);
      _processChartData(historicoList);

      if (!mounted) return;

      setState(() {
        _kpis = kpisResponse as Map<String, dynamic>?;
        _rankingClientes = List<Map<String, dynamic>>.from(rankingResponse as List? ?? []);
        _historicoFaturamento = historicoList;
        _visibleClientsCount = 5;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar dados: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _processChartData(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final currentYear = now.year;
    final lastYear = currentYear - 1;

    final List<double> totalsBase = List.filled(12, 0.0);
    final List<double> totalsCurrent = List.filled(12, 0.0);

    for (var item in data) {
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final dataSortStr = item['data_sort'] as String?;
      
      if (dataSortStr != null) {
        try {
          final date = DateTime.parse(dataSortStr);
          if (date.year == lastYear) {
            totalsBase[date.month - 1] += total;
          } else if (date.year == currentYear) {
            totalsCurrent[date.month - 1] += total;
          }
        } catch (_) {}
      }
    }

    // 1. Calcular Variação (Trend) com base em meses CONSOLIDADOS (mês anterior ao atual)
    double sumBaseYTD = 0;
    double sumCurrentYTD = 0;
    
    // Ex: Se estamos em Março (3), consolidado é até Fev (1). Index = 3 - 2 = 1.
    final consolidatedMonthIndex = now.month - 2;

    if (consolidatedMonthIndex >= 0) {
      for (int i = 0; i <= consolidatedMonthIndex; i++) {
        sumBaseYTD += totalsBase[i];
        sumCurrentYTD += totalsCurrent[i];
      }
    }

    double growthFactor = 1.0;
    if (sumBaseYTD > 0) {
      growthFactor = sumCurrentYTD / sumBaseYTD;
    }
    _growthPercentage = (growthFactor - 1) * 100;

    // 2. Gerar Spots
    // Para o gráfico visual, mantemos o mês atual como realizado (parcial)
    final currentMonthIndex = now.month - 1;
    
    _spotsBase = [];
    _spotsRealized = [];
    _spotsProjected = [];

    for (int i = 0; i < 12; i++) {
      // Ano Anterior (Base)
      _spotsBase.add(FlSpot(i.toDouble(), totalsBase[i]));

      // Ano Atual
      if (i <= currentMonthIndex) {
        // Realizado
        _spotsRealized.add(FlSpot(i.toDouble(), totalsCurrent[i]));
      } 
      
      if (i >= currentMonthIndex) {
        // Projeção (Começa do último realizado para conectar as linhas)
        // Se for o mês atual, usa o realizado como ponto de partida, senão projeta
        double value = (i == currentMonthIndex) 
            ? totalsCurrent[i] 
            : totalsBase[i] * growthFactor;
            
        _spotsProjected.add(FlSpot(i.toDouble(), value));
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    int tempYear = _selectedDate.year;
    int tempMonth = _selectedDate.month;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Selecione Mês/Ano"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: tempYear > 2020
                            ? () => setStateDialog(() => tempYear--)
                            : null,
                      ),
                      Text(
                        "$tempYear",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: tempYear < DateTime.now().year
                            ? () => setStateDialog(() => tempYear++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    height: 160,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthIndex = index + 1;
                        final isSelected = monthIndex == tempMonth;
                        final monthName = DateFormat.MMM('pt_BR')
                            .format(DateTime(2024, monthIndex));

                        return InkWell(
                          onTap: () {
                            setStateDialog(() {
                              tempMonth = monthIndex;
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFD700)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? null
                                  : Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              monthName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.black : null,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, DateTime(tempYear, tempMonth));
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null &&
        (picked.month != _selectedDate.month ||
            picked.year != _selectedDate.year)) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(2).replaceAll('.', ',')} Mi';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(2).replaceAll('.', ',')} Mil';
    }
    return _formatCurrency(value);
  }

  Color _getCategoryColor(String? categoria) {
    switch (categoria?.toUpperCase()) {
      case 'KIT':
        return Colors.blue;
      case 'ADAPTAÇÃO':
      case 'ADAPTACAO':
        return Colors.orange;
      case 'SUCATA':
        return Colors.red[300]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final flashYellow = const Color(0xFFFFD700);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Faturamento"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Filtrar Mês/Ano',
            color: flashYellow,
            onPressed: _isLoading ? null : () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      toggleTheme: widget.toggleTheme,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      drawer: CustomDrawer(toggleTheme: widget.toggleTheme, module: 'BI'),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: flashYellow,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => BiEstoqueScreen(toggleTheme: widget.toggleTheme),
                transitionDuration: Duration.zero,
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Estoque'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Faturamento'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Não foi possível carregar o dashboard.\n$_errorMessage',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFFFD700),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDateHeader(),
          const SizedBox(height: 16),
          _buildKpiSection(),
          const SizedBox(height: 24),
          _buildPieChartSection(),
          const SizedBox(height: 24),
          _buildChartSection(),
          const SizedBox(height: 24),
          Text(
            'Top Clientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildRankingList(),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    // Proteção caso o locale ainda não esteja pronto (embora o restart deva resolver)
    String dateStr;
    try {
      dateStr = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDate);
    } catch (e) {
      dateStr = "${_selectedDate.month}/${_selectedDate.year}";
    }

    return Center(
      child: Text(
        dateStr.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    final totalVenda = (_kpis?['total_venda'] as num?)?.toDouble() ?? 0.0;
    
    return SizedBox(
      width: double.infinity,
      child: _KpiCard(
        title: 'Faturamento',
        value: _formatCurrency(totalVenda),
        color: Colors.blue,
        icon: Icons.monetization_on,
      ),
    );
  }

  Widget _buildChartSection() {
    // O processamento pesado foi removido daqui e movido para _processChartData

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;
    final growthColor = _growthPercentage >= 0 ? Colors.green : Colors.red;
    final growthIcon = _growthPercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Evolução Anual ($lastYear vs $currentYear)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text("Tendência: ", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Icon(growthIcon, size: 14, color: growthColor),
                Text(
                  "${_growthPercentage.abs().toStringAsFixed(1)}%", 
                  style: TextStyle(color: growthColor, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _spotsBase.isEmpty && _spotsRealized.isEmpty
                ? const Center(child: Text("Sem dados"))
                : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 10000000, // 10 Milhões
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('');
                            return Text(
                              '${(value / 1000000).toStringAsFixed(0)}M',
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                            final index = value.toInt();
                            if (index >= 0 && index < months.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(months[index], style: TextStyle(color: textColor, fontSize: 10)),
                              );
                            }
                            return const Text('');
                          },
                          interval: 1,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // Ano Anterior (Base)
                      LineChartBarData(
                        spots: _spotsBase,
                        isCurved: true,
                        color: Colors.grey,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      ),
                      // Ano Atual (Projeção - Tracejado)
                      LineChartBarData(
                        spots: _spotsProjected,
                        isCurved: true,
                        color: const Color(0xFFFFD700),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 5], // Tracejado
                      ),
                      // Ano Atual (Realizado - Sólido)
                      LineChartBarData(
                        spots: _spotsRealized,
                        isCurved: true,
                        color: const Color(0xFFFFD700),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(color: Colors.grey, label: '$lastYear', textColor: textColor),
                const SizedBox(width: 16),
                _buildLegendItem(color: const Color(0xFFFFD700), label: '$currentYear', textColor: textColor),
                const SizedBox(width: 16),
                _buildLegendItem(color: const Color(0xFFFFD700).withOpacity(0.6), label: 'Projeção', textColor: textColor, isDashed: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label, required Color textColor, bool isDashed = false}) {
    return Row(
      children: [
        if (isDashed)
          Row(
            children: [
              Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 2),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          )
        else
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPieChartSection() {
    final currentMonthData = _historicoFaturamento.where((item) {
      final dataSortStr = item['data_sort'] as String?;
      if (dataSortStr == null) return false;
      try {
        final date = DateTime.parse(dataSortStr);
        return date.month == _selectedDate.month && date.year == _selectedDate.year;
      } catch (_) {
        return false;
      }
    }).toList();

    final Map<String, double> categoryTotals = {};
    double totalMonth = 0;
    
    for (var item in currentMonthData) {
      final cat = item['categoria'] as String? ?? 'OUTROS';
      final val = (item['total'] as num?)?.toDouble() ?? 0.0;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + val;
      totalMonth += val;
    }

    if (totalMonth == 0) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Distribuição por Categoria", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      sections: sortedEntries.map((e) {
                        return PieChartSectionData(
                          color: _getCategoryColor(e.key),
                          value: e.value,
                          showTitle: false,
                          radius: 50,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedEntries.map((e) {
                      final percentage = (e.value / totalMonth) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildPieLegendItem(
                          color: _getCategoryColor(e.key),
                          label: e.key,
                          percentage: percentage,
                          textColor: textColor,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieLegendItem({
    required Color color,
    required String label,
    required double percentage,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingList() {
    if (_rankingClientes.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Nenhum faturamento neste mês."),
      ));
    }

    final visibleList = _rankingClientes.take(_visibleClientsCount).toList();

    return Column(
      children: [
        ...visibleList.map((cliente) {
        final nome = cliente['nome_cliente'] ?? 'Cliente Desconhecido';
        final total = (cliente['total'] as num?)?.toDouble() ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF8E1), // Light Yellow
              child: Icon(Icons.business, color: Color(0xFFFFD700), size: 20),
            ),
            title: Text(
              nome,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatCompactCurrency(total),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        );
      }),
      if (_visibleClientsCount < _rankingClientes.length)
        TextButton(
          onPressed: () {
            setState(() {
              _visibleClientsCount += 5;
            });
          },
          child: const Text("Carregar Mais"),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Card(
      color: cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: isDarkMode ? Colors.white : Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}
