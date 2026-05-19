class PaymentMethodStat {
  final String method; // 'cash', 'card', 'upi', 'other'
  final double amount;
  final double percentage; // 0.0 to 1.0
  final int count;

  PaymentMethodStat({
    required this.method,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class SaleStats {
  final double grossSales;
  final double netSales;
  final double avgOrder;
  final int totalOrders;
  final List<PaymentMethodStat> paymentMethods;

  // New fields for dynamic trends
  final double grossSalesTrend; // percentage e.g. 12.5 for 12.5%
  final double netSalesTrend;
  final double avgOrderTrend;
  final double totalOrdersTrend;

  // Data for the revenue trend chart
  final List<RevenueDataPoint> revenueTrend;

  SaleStats({
    required this.grossSales,
    required this.netSales,
    required this.avgOrder,
    required this.totalOrders,
    required this.paymentMethods,
    this.grossSalesTrend = 0.0,
    this.netSalesTrend = 0.0,
    this.avgOrderTrend = 0.0,
    this.totalOrdersTrend = 0.0,
    this.revenueTrend = const [],
  });

  factory SaleStats.empty() => SaleStats(
        grossSales: 0.0,
        netSales: 0.0,
        avgOrder: 0.0,
        totalOrders: 0,
        paymentMethods: [],
        grossSalesTrend: 0.0,
        netSalesTrend: 0.0,
        avgOrderTrend: 0.0,
        totalOrdersTrend: 0.0,
        revenueTrend: [],
      );
}

class RevenueDataPoint {
  final String label; // e.g. "MON", "01/10"
  final DateTime date;
  final double amount;

  RevenueDataPoint({
    required this.label,
    required this.date,
    required this.amount,
  });
}
