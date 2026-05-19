// main.dart
import 'package:flutter/material.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/selection_screen.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/editor_screen.dart';

class InvoiceTemplateEditorApp extends StatefulWidget {
  const InvoiceTemplateEditorApp({super.key});

  @override
  State<InvoiceTemplateEditorApp> createState() =>
      _InvoiceTemplateEditorAppState();
}

class _InvoiceTemplateEditorAppState extends State<InvoiceTemplateEditorApp> {
  String _view = 'selection';
  String? _selectedId;

  void handleEdit(String id) {
    setState(() {
      _selectedId = id;
      _view = 'editor';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Template Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _view == 'selection'
            ? SelectionScreen(
                key: const ValueKey('selection'),
                onEdit: handleEdit,
              )
            : EditorScreen(
                key: ValueKey('editor-$_selectedId'),
                onBack: () {
                  setState(() {
                    _view = 'selection';
                  });
                },
                templateId: _selectedId,
              ),
      ),
    );
  }
}
