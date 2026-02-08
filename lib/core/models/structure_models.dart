class ProductParent {
  final String code;
  final String name;

  ProductParent({required this.code, required this.name});
}

class StructureItem {
  final int nivel;
  final String codComponente;
  final String descComponente;
  final String unid;
  final double qtdTotalAcum;
  final String fixVar; // 'F' ou 'V'
  final String? dataInicial;
  final String codPai;

  StructureItem({
    required this.nivel,
    required this.codComponente,
    required this.descComponente,
    required this.unid,
    required this.qtdTotalAcum,
    required this.fixVar,
    this.dataInicial,
    required this.codPai,
  });
}