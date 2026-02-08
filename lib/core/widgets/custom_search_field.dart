import 'package:flutter/material.dart';
import 'scanner_page.dart';

class CustomSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const CustomSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Pesquisar...',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final flashYellow = const Color(0xFFFFD700);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: subTextColor),
        prefixIcon: Icon(Icons.search, color: flashYellow),
        suffixIcon: IconButton(
          icon: Icon(Icons.qr_code_scanner, color: flashYellow),
          onPressed: () async {
            try {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerPage()),
              );

              if (result is String && result != '-1' && context.mounted) {
                if (controller != null) {
                  controller!.text = result;
                }
                
                // Dispara os eventos para quem estiver ouvindo
                if (onChanged != null) {
                  onChanged!(result);
                }
                if (onSubmitted != null) {
                  onSubmitted!(result);
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao abrir scanner: $e')),
                );
              }
            }
          },
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.black26 : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: flashYellow),
        ),
      ),
    );
  }
}