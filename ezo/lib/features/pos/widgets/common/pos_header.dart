import 'package:flutter/material.dart';


/// A unified header component for all POS layouts.
/// Provides a consistent look (title, search area, clock).
class PosHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? body; // For layout-specific controls like barcode, search field, or order types
  final List<Widget>? actions;
  final double height;
  final Color backgroundColor;
  final bool showClock;
  
  // Standard POS actions
  final VoidCallback? onBack;
  final VoidCallback? onReset;
  final VoidCallback? onOrders;


  const PosHeader({
    super.key,
    this.title = 'Point of Sale',
    this.subtitle,
    this.body,
    this.actions,
    this.height = 70,
    this.backgroundColor = Colors.white,
    this.showClock = true,
    this.onBack,
    this.onReset,
    this.onOrders,

  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Title Section
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          
          const Spacer(),

          // Center Area (Body)
          if (body != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: body!,
            ),

          // Actions / Clock Section
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1E293B)),
              onPressed: onBack,
              tooltip: 'Back',
            ),
          if (onOrders != null)
            TextButton.icon(
              onPressed: onOrders,
              icon: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF00A78E)),
              label: const Text('Orders', style: TextStyle(color: Color(0xFF00A78E), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          if (onReset != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6366F1)),
              onPressed: onReset,
              tooltip: 'Reset',
            ),

          if (actions != null) ...[
            ...actions!,
            const SizedBox(width: 12),
          ],

          if (showClock)
            StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
              builder: (context, snapshot) {
                final now = snapshot.data ?? DateTime.now();
                return Text(
                  "${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Convenience method to build a standard search bar for headers
  static Widget buildSearchBar({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String hint = 'Search products...',
    double width = 250,
  }) {
    return Container(
      width: width,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }
}
