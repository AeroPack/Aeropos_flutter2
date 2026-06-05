import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/sale_stats.dart';

final salesListStreamProvider = StreamProvider.autoDispose<List<TypedResult>>((ref) {
  final database = ServiceLocator.instance.database;
  final companyId = ServiceLocator.instance.sessionService.companyId;
  return database.watchInvoicesWithCustomer(companyId: companyId);
});

final salesStatsProvider = Provider.autoDispose<AsyncValue<SaleStats>>((ref) {
  final salesAsync = ref.watch(salesListStreamProvider);
  return salesAsync.whenData((results) {
    try {
      if (results.isEmpty) return SaleStats.empty();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final sixtyDaysAgo = today.subtract(const Duration(days: 60));

      double currentGross = 0;
      double currentNet = 0;
      int currentTotal = 0;

      double previousGross = 0;
      double previousNet = 0;
      int previousTotal = 0;

      Map<String, double> methodTotals = {};
      Map<String, int> methodCounts = {};

      // For revenue chart (last 7 days)
      Map<String, double> dailyRevenue = {};
      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final label = DateFormat('EEE').format(date).toUpperCase();
        dailyRevenue[label] = 0.0;
      }

      final db = ServiceLocator.instance.database;

      for (var row in results) {
        final invoice = row.readTable(db.invoices);
        final total = invoice.total;
        final subtotal = invoice.subtotal;
        final date = invoice.date;

        // KPI and Trends
        if (date.isAfter(thirtyDaysAgo)) {
          currentGross += total;
          currentNet += subtotal;
          currentTotal++;

          // Accumulate for current methods
          final m = invoice.paymentMethod ?? 'other';
          methodTotals[m] = (methodTotals[m] ?? 0) + total;
          methodCounts[m] = (methodCounts[m] ?? 0) + 1;

          // Daily revenue for chart (last 7 days)
          if (date.isAfter(today.subtract(const Duration(days: 7)))) {
            final label = DateFormat('EEE').format(date).toUpperCase();
            dailyRevenue[label] = (dailyRevenue[label] ?? 0) + total;
          }
        } else if (date.isAfter(sixtyDaysAgo)) {
          previousGross += total;
          previousNet += subtotal;
          previousTotal++;
        }
      }

      // Trend calculations
      double calculateTrend(double current, double previous) {
        if (previous == 0) return current > 0 ? 100.0 : 0.0;
        return ((current - previous) / previous) * 100.0;
      }

      final grossTrend = calculateTrend(currentGross, previousGross);
      final netTrend = calculateTrend(currentNet, previousNet);
      final countTrend = calculateTrend(
        currentTotal.toDouble(),
        previousTotal.toDouble(),
      );

      final currentAvg = currentTotal > 0 ? currentGross / currentTotal : 0.0;
      final previousAvg = previousTotal > 0
          ? previousGross / previousTotal
          : 0.0;
      final avgTrend = calculateTrend(currentAvg, previousAvg);

      // Methods normalization
      final List<PaymentMethodStat> methods = [];
      methodTotals.forEach((method, amount) {
        methods.add(
          PaymentMethodStat(
            method: method,
            amount: amount,
            percentage: currentGross > 0 ? amount / currentGross : 0,
            count: methodCounts[method] ?? 0,
          ),
        );
      });
      methods.sort((a, b) => b.amount.compareTo(a.amount));

      // Chart points
      final List<RevenueDataPoint> chartData = dailyRevenue.entries.map((e) {
        return RevenueDataPoint(
          label: e.key,
          date: DateTime.now(),
          amount: e.value,
        );
      }).toList();

      return SaleStats(
        grossSales: currentGross,
        netSales: currentNet,
        avgOrder: currentAvg,
        totalOrders: currentTotal,
        paymentMethods: methods,
        grossSalesTrend: grossTrend,
        netSalesTrend: netTrend,
        avgOrderTrend: avgTrend,
        totalOrdersTrend: countTrend,
        revenueTrend: chartData,
      );
    } catch (e) {
      return SaleStats.empty(); // Safe fallback
    }
  });
});
