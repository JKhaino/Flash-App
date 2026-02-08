import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../estoque/screens/consulta_saldo_screen.dart';
import 'faturamento_screen.dart';

class BiEstoqueScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const BiEstoqueScreen({super.key, required this.toggleTheme});

  @override
  State<BiEstoqueScreen> createState() => _BiEstoqueScreenState();
}

class _BiEstoqueScreenState extends State<BiEstoqueScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _items = [];
  int _currentOffset = 0;
  static const int _pageSize = 10;
  bool _hasMore = true;
  String? _errorMessage;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _items = [];
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      // 1. Busca totais via RPC (Mais rápido e preciso)
      final totals = await SupabaseService.client.rpc('get_dashboard_totais');

      // 2. Busca Itens Paginados (Primeira página)
      await _fetchItems();

      if (!mounted) return;

      setState(() {
        _dashboardData = {
          'valor_total': (totals['total_bruto'] as num?)?.toDouble() ?? 0.0,
          'valor_empenhado': (totals['total_empenhado'] as num?)?.toDouble() ?? 0.0,
          'valor_disponivel': (totals['total_livre'] as num?)?.toDouble() ?? 0.0,
        };
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

  Future<void> _fetchItems() async {
    final data = await SupabaseService.client
        .from('view_dashboard_estoque')
        .select()
        .order('valor_livre', ascending: false)
        .range(_currentOffset, _currentOffset + _pageSize - 1);

    final List<Map<String, dynamic>> newItems =
        List<Map<String, dynamic>>.from(data);

    if (mounted) {
      setState(() {
        _items.addAll(newItems);
        _currentOffset += newItems.length;
        _hasMore = newItems.length == _pageSize;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _fetchItems();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao carregar mais: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(2).replaceAll('.', ',')} mi';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(2).replaceAll('.', ',')} mil';
    }
    return _formatCurrency(value);
  }

  String _formatQuantity(double value) {
    return NumberFormat.decimalPattern('pt_BR').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard BI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;
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
        currentIndex: 0,
        selectedItemColor: const Color(0xFFFFD700),
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => FaturamentoScreen(toggleTheme: widget.toggleTheme),
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
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
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

    if (_dashboardData == null) {
      return const Center(child: Text('Nenhum dado encontrado.'));
    }

    final valorTotal = _dashboardData!['valor_total'] as double;
    final valorEmpenhado = _dashboardData!['valor_empenhado'] as double;
    final valorDisponivel = _dashboardData!['valor_disponivel'] as double;

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: const Color(0xFFFFD700),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildKpiSection(valorTotal, valorEmpenhado, valorDisponivel),
          const SizedBox(height: 24),
          _buildPieChart(valorEmpenhado, valorDisponivel),
          const SizedBox(height: 24),
          Text(
            'Itens sem demanda',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildItemsList(),
        ],
      ),
    );
  }

  Widget _buildKpiSection(double total, double empenhado, double disponivel) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _KpiCard(
            title: 'Valor Total',
            value: _formatCurrency(total),
            icon: Icons.inventory_2,
            color: Colors.blue,
            isLarge: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Valor em Processo',
                value: _formatCurrency(empenhado),
                icon: Icons.lock_clock,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Valor Ocioso',
                value: _formatCurrency(disponivel),
                icon: Icons.local_shipping,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPieChart(double empenhado, double disponivel) {
    final total = empenhado + disponivel;
    final pctEmpenhado = total > 0 ? (empenhado / total) * 100 : 0.0;
    final pctDisponivel = total > 0 ? (disponivel / total) * 100 : 0.0;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                  sections: [
                    PieChartSectionData(
                      color: Colors.orange,
                      value: empenhado,
                      showTitle: false,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: disponivel,
                      showTitle: false,
                      radius: 50,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(
                    color: Colors.orange,
                    label: 'Processo',
                    percentage: pctEmpenhado,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    color: Colors.green,
                    label: 'Ocioso',
                    percentage: pctDisponivel,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
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
        Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    return Card(
      color: cardColor,
      elevation: 2,
      child: Column(
        children: [
          ...List.generate(_items.length, (index) {
            final item = _items[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultaSaldoScreen(
                    toggleTheme: widget.toggleTheme,
                    initialSearchCode: item['codigo'],
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['codigo'] ?? 'N/A',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              item['descricao'] ?? 'Sem descrição',
                              style: TextStyle(color: subTextColor, fontSize: 12),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Saldo: ${_formatQuantity((item['saldo_livre'] as num?)?.toDouble() ?? 0.0)}',
                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                ),
                                Text(
                                  '  |  ',
                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                ),
                                Text(
                                  'Valor: ${_formatCompactCurrency((item['valor_livre'] as num?)?.toDouble() ?? 0.0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < _items.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ),
          );
          }),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Carregar mais itens'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final iconSize = isLarge ? 32.0 : 24.0;
    final titleSize = isLarge ? 14.0 : 12.0;
    final valueSize = isLarge ? 24.0 : 16.0;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 16.0 : 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}