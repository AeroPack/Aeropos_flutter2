import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lucide_icons/lucide_icons.dart';

// --- Local Models (Renamed to avoid conflict with AeroPOS core models) ---

enum EditorTemplateFormat { a4, thermal, a5 }

class EditorInvoiceItem {
  String id;
  String desc;
  String details;
  double qty;
  double rate;

  EditorInvoiceItem({
    required this.id,
    required this.desc,
    this.details = '',
    required this.qty,
    required this.rate,
  });

  double get total => qty * rate;
}

class EditorTemplate {
  final String id;
  final String name;
  final String industry;
  final EditorTemplateFormat format;
  final String style;
  final String image;
  final String metadata;
  final String tag;
  final Color styleColor;

  EditorTemplate({
    required this.id,
    required this.name,
    required this.industry,
    required this.format,
    required this.style,
    required this.image,
    required this.metadata,
    required this.tag,
    this.styleColor = const Color(0xFF4F46E5),
  });
}

// --- Data ---

final List<EditorTemplate> templates = [
  EditorTemplate(
    id: '1',
    name: 'Retail Basic',
    industry: 'RETAIL',
    format: EditorTemplateFormat.a4,
    style: 'COMPACT',
    image: 'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=400',
    metadata: 'Standard Retail Format',
    tag: 'POPULAR',
  ),
  EditorTemplate(
    id: '2',
    name: 'Grocery GST Detailed',
    industry: 'GROCERY',
    format: EditorTemplateFormat.thermal,
    style: 'DETAILED',
    image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
    metadata: 'HSN & Weight Ready',
    tag: 'GST COMPLIANT',
    styleColor: Colors.green,
  ),
  EditorTemplate(
    id: '3',
    name: 'Garment Elegant',
    industry: 'GARMENT',
    format: EditorTemplateFormat.a5,
    style: 'STYLE FOCUS',
    image: 'https://images.unsplash.com/photo-1626266061368-46a8f578ddd6?w=400',
    metadata: 'Boutique Look',
    tag: 'FEATURED',
    styleColor: Colors.purple,
  ),
  EditorTemplate(
    id: '10',
    name: 'Fresh Mart Grocery',
    industry: 'GROCERY',
    format: EditorTemplateFormat.thermal,
    style: 'COMPACT',
    image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
    metadata: '58mm/80mm optimized',
    tag: 'GROCERY SPECIAL',
    styleColor: Colors.green,
  ),
  EditorTemplate(
    id: '11',
    name: 'Cozy Corner Cafe',
    industry: 'RESTAURANT',
    format: EditorTemplateFormat.thermal,
    style: 'CAFE STYLE',
    image: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=400',
    metadata: 'Table & Dine-in Ready',
    tag: 'CAFE FAVORITE',
    styleColor: Colors.orange,
  ),
];

// --- Selection Screen (AeroPOS Entry Point) ---

class InvoiceTemplateEditorScreen extends ConsumerStatefulWidget {
  const InvoiceTemplateEditorScreen({super.key});

  @override
  ConsumerState<InvoiceTemplateEditorScreen> createState() =>
      _InvoiceTemplateEditorScreenState();
}

class _InvoiceTemplateEditorScreenState
    extends ConsumerState<InvoiceTemplateEditorScreen> {
  String activeFormat = 'Thermal Receipt';
  String activeIndustry = 'All Industries';

  final formats = ['Thermal Receipt', 'A5 Half-Page', 'A4 Full-Page'];
  final industries = [
    'All Industries',
    'Retail',
    'Grocery',
    'Garment',
    'Electronics',
    'Restaurant',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildFormatTabs(),
            const SizedBox(height: 24),
            _buildIndustryFilters(),
            const SizedBox(height: 32),
            _buildTemplateGrid(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.creditCard,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'InvoiceGenius ',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'POS',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          width: 250,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search POS layouts...',
              prefixIcon: Icon(LucideIcons.search, size: 16),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 8),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const CircleAvatar(
          backgroundImage: NetworkImage(
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
          ),
          radius: 18,
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select POS Template',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'Choose a bill format optimized for your industry',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Custom POS Layout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: formats.map((f) {
          bool isActive = activeFormat == f;
          return InkWell(
            onTap: () => setState(() => activeFormat = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? const Color(0xFF4F46E5)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFF1E293B) : Colors.grey[500],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIndustryFilters() {
    return Wrap(
      spacing: 12,
      children: industries.map((i) {
        bool isActive = activeIndustry == i;
        return ChoiceChip(
          label: Text(i),
          selected: isActive,
          onSelected: (val) => setState(() => activeIndustry = i),
          backgroundColor: const Color(0xFFF1F5F9),
          selectedColor: const Color(0xFF4F46E5),
          labelStyle: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  List<EditorTemplate> get filteredTemplates {
    return templates.where((t) {
      final formatMatch =
          activeFormat == 'All Formats' || // Fallback if added
          (activeFormat == 'Thermal Receipt' &&
              t.format == EditorTemplateFormat.thermal) ||
          (activeFormat == 'A5 Half-Page' &&
              t.format == EditorTemplateFormat.a5) ||
          (activeFormat == 'A4 Full-Page' &&
              t.format == EditorTemplateFormat.a4);

      final industryMatch =
          activeIndustry == 'All Industries' ||
          t.industry.toLowerCase() == activeIndustry.toLowerCase();

      return formatMatch && industryMatch;
    }).toList();
  }

  Widget _buildTemplateGrid() {
    final list = filteredTemplates;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(LucideIcons.searchX, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No templates found for this criteria',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        crossAxisSpacing: 32,
        mainAxisSpacing: 32,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final t = list[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        InvoiceDesignEditorScreen(template: t),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(t.image),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${t.industry} | ${t.format.name.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.styleColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.style,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E293B),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.metadata,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                Text(
                  t.tag,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// --- Editor Screen ---

class InvoiceDesignEditorScreen extends ConsumerStatefulWidget {
  final EditorTemplate template;
  const InvoiceDesignEditorScreen({super.key, required this.template});

  @override
  ConsumerState<InvoiceDesignEditorScreen> createState() =>
      _InvoiceDesignEditorScreenState();
}

class _InvoiceDesignEditorScreenState
    extends ConsumerState<InvoiceDesignEditorScreen> {
  late String businessName;
  late List<EditorInvoiceItem> items;
  String themeColor = '#4F46E5';
  String fontFamily = 'Inter';

  @override
  void initState() {
    super.initState();
    businessName = widget.template.name;
    items = [
      EditorInvoiceItem(id: '1', desc: 'Product Item 1', qty: 2, rate: 450),
      EditorInvoiceItem(id: '2', desc: 'Product Item 2', qty: 1, rate: 1200),
    ];
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: _buildEditorAppBar(),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(child: _buildPreviewArea()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildEditorAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(
          LucideIcons.arrowLeft,
          size: 18,
          color: Color(0xFF1E293B),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.template.name,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
      actions: [
        _buildActionBtn(
          'Export PDF',
          LucideIcons.download,
          const Color(0xFFEEF2FF),
          const Color(0xFF4F46E5),
          onPressed: () => _generatePdf(),
        ),
        _buildActionBtn(
          'Print',
          LucideIcons.monitor,
          const Color(0xFFF1F5F9),
          const Color(0xFF475569),
          onPressed: () => _handlePrint(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template saved successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Template'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color bg,
    Color text, {
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: text),
        label: Text(
          label,
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        style: TextButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildToolbarTool('Logo', LucideIcons.uploadCloud),
          const VerticalDivider(width: 32, indent: 12, endIndent: 12),
          _buildThemePicker(),
          const VerticalDivider(width: 32, indent: 12, endIndent: 12),
          _buildFontPicker(),
          const Spacer(),
          const Icon(LucideIcons.monitor, size: 18, color: Color(0xFF4F46E5)),
          const SizedBox(width: 16),
          const Icon(LucideIcons.tablet, size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 16),
          const Icon(
            LucideIcons.smartphone,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarTool(String label, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildThemePicker() {
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: colors
              .map(
                (c) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        const Text(
          'THEME',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildFontPicker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Inter',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'FONT',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccordion('1. Business & Client Content', LucideIcons.info, [
            _buildInputLabel('Business Name'),
            _buildTextField(
              businessName,
              (val) => setState(() => businessName = val),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Email', (val) {})),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField('Phone', (val) {})),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField('Address', (val) {}, maxLines: 2),
          ]),
          const SizedBox(height: 12),
          _buildAccordion('2. Line Items', LucideIcons.list, [
            ...items.asMap().entries.map(
              (entry) => _buildItemRow(entry.key, entry.value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(
                () => items.add(
                  EditorInvoiceItem(
                    id: DateTime.now().toString(),
                    desc: 'New Item',
                    qty: 1,
                    rate: 0,
                  ),
                ),
              ),
              icon: const Icon(LucideIcons.plusCircle, size: 16),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildAccordion('3. Pricing & Tax', LucideIcons.creditCard, [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calculate GST',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Switch(
                  value: true,
                  onChanged: (val) {},
                  activeThumbColor: const Color(0xFF4F46E5),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAccordion(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        backgroundColor: const Color(0xFFF8FAFC),
        collapsedBackgroundColor: const Color(0xFFF8FAFC),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        leading: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, EditorInvoiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          _buildTextField(item.desc, (val) => setState(() => item.desc = val)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 60,
                child: _buildTextField(
                  item.qty.toString(),
                  (val) => setState(() => item.qty = double.tryParse(val) ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: _buildTextField(
                  item.rate.toString(),
                  (val) =>
                      setState(() => item.rate = double.tryParse(val) ?? 0),
                ),
              ),
              const Spacer(),
              Text(
                '₹${item.total}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Colors.red,
                ),
                onPressed: () => setState(() => items.removeAt(index)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String initialValue,
    Function(String) onChanged, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: TextEditingController(text: initialValue),
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Container(
      color: const Color(0xFFF6F7F8),
      child: Center(
        child: SingleChildScrollView(
          child: widget.template.format == EditorTemplateFormat.thermal
              ? _buildThermalPreview()
              : _buildA4Preview(),
        ),
      ),
    );
  }

  Widget _buildThermalPreview() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          Text(
            businessName.toUpperCase(),
            style: GoogleFonts.courierPrime(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GSTIN: 27AABCF1234Z1Z5',
            style: GoogleFonts.courierPrime(fontSize: 12),
          ),
          const Divider(thickness: 1, color: Colors.black),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.desc} x ${item.qty}',
                      style: GoogleFonts.courierPrime(),
                    ),
                  ),
                  Text(
                    '₹${item.total}',
                    style: GoogleFonts.courierPrime(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(thickness: 1, color: Colors.black),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹$subtotal',
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('*** THANK YOU ***', style: GoogleFonts.courierPrime()),
        ],
      ),
    );
  }

  Widget _buildA4Preview() {
    return Container(
      width: 595,
      height: 842, // A4 aspect ratio
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                businessName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: widget.template.styleColor,
                ),
              ),
              const Text(
                'INVOICE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w100,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoBlock(
                'BILL FROM',
                '$businessName\n123 Market St\nCity, State',
              ),
              _buildInfoBlock('BILL TO', 'Walk-in Customer\nLocal Area'),
            ],
          ),
          const SizedBox(height: 48),
          _buildTable(),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Grand Total: ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹$subtotal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: widget.template.styleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 12, height: 1.5)),
      ],
    );
  }

  Widget _buildTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.template.styleColor.withValues(alpha: 0.1),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'Qty',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'Rate',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(item.desc)),
                Expanded(child: Text(item.qty.toString())),
                Expanded(child: Text('₹${item.rate}')),
                Expanded(
                  child: Text(
                    '₹${item.total}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- PDF Logic ---

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.courierPrimeRegular();
    final fontBold = await PdfGoogleFonts.courierPrimeBold();

    pdf.addPage(
      pw.Page(
        pageFormat: widget.template.format == EditorTemplateFormat.thermal
            ? PdfPageFormat.roll80
            : PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: 18),
              ),
              pw.Divider(),
              ...items.map(
                (item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.desc.toUpperCase(),
                      style: pw.TextStyle(font: fontBold),
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${item.qty} x ${item.rate}',
                          style: pw.TextStyle(font: font),
                        ),
                        pw.Text(
                          'INR ${item.total}',
                          style: pw.TextStyle(font: font),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.Text(
                    'INR $subtotal',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _handlePrint() async {
    await _generatePdf();
  }
}
