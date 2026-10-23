import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/money_format.dart';

/// Options shown in the dashboard dropdown
enum DashRange {
  allTime('All Time'),
  last7('Last 7 Days'),
  thisWeek('This Week'),
  lastWeek('Last Week'),
  lastMonth('Last Month'),
  thisMonth('This Month'),
  thisYear('This Year'),
  lastYear('Last Year');

  final String label;
  const DashRange(this.label);
}

class _Span {
  final DateTime start;
  final DateTime end;
  const _Span(this.start, this.end);
}

enum _Mode { day, month, year }

class _Bucket {
  final String key; // yyyy-MM-dd / yyyy-MM / yyyy
  final String label; // x axis label
  final String tip; // tooltip title
  double value = 0;
  _Bucket(this.key, this.label, this.tip);
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _money(double v) => fmtRs(v);

String _trim(double v) => v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

String _compact(double v) {
  final a = v.abs();
  if (a >= 1e6) return '${_trim(v / 1e6)}M';
  if (a >= 1e3) return '${_trim(v / 1e3)}k';
  return _trim(v);
}

/// Round up to 1 / 2 / 5 x 10^n so the y axis labels look clean
double _niceMax(double m) {
  if (m <= 0) return 100;
  final exp = math.pow(10, (math.log(m) / math.ln10).floor()).toDouble();
  final f = m / exp;
  final nf = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
  return nf * exp;
}

class DashboardOverview extends StatefulWidget {
  final VoidCallback onCreateInvoice;
  final VoidCallback onAddExpense;

  const DashboardOverview({
    super.key,
    required this.onCreateInvoice,
    required this.onAddExpense,
  });

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  DashRange _range = DashRange.thisMonth;
  bool _loading = true;
  int _reqId = 0; // ignore results of old requests

  double _income = 0;
  double _expenses = 0;
  double _salesProfit = 0; // (selling price - supplier price) x qty
  List<_Bucket> _incomeBuckets = [];
  List<_Bucket> _expenseBuckets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------- Date ranges ----------------

  /// null = all time
  _Span? _resolve(DashRange r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));

    switch (r) {
      case DashRange.allTime:
        return null;
      case DashRange.last7:
        return _Span(DateTime(today.year, today.month, today.day - 6), today);
      case DashRange.thisWeek:
        return _Span(monday, DateTime(monday.year, monday.month, monday.day + 6));
      case DashRange.lastWeek:
        return _Span(
          DateTime(monday.year, monday.month, monday.day - 7),
          DateTime(monday.year, monday.month, monday.day - 1),
        );
      case DashRange.thisMonth:
        return _Span(
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 0),
        );
      case DashRange.lastMonth:
        return _Span(
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 0),
        );
      case DashRange.thisYear:
        return _Span(DateTime(today.year, 1, 1), DateTime(today.year, 12, 31));
      case DashRange.lastYear:
        return _Span(DateTime(today.year - 1, 1, 1), DateTime(today.year - 1, 12, 31));
    }
  }

  // ---------------- Load data ----------------

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() => _loading = true);

    try {
      final span = _resolve(_range);
      final String? s = span == null ? null : _fmt(span.start);
      final String? e = span == null ? null : _fmt(span.end);
      final db = DatabaseHelper.instance;

      final (incomeDaily, expenseDaily, salesProfit) = await (
        db.getDailyIncome(start: s, end: e),
        db.getDailyExpenses(start: s, end: e),
        db.getSalesProfit(start: s, end: e),
      ).wait;

      if (!mounted || id != _reqId) return;

      final plan = _plan(span, incomeDaily, expenseDaily);

      setState(() {
        _income = incomeDaily.values.fold(0.0, (a, b) => a + b);
        _expenses = expenseDaily.values.fold(0.0, (a, b) => a + b);
        _salesProfit = salesProfit;
        _incomeBuckets = plan == null
            ? []
            : _makeBuckets(plan.mode, plan.start, plan.end, incomeDaily);
        _expenseBuckets = plan == null
            ? []
            : _makeBuckets(plan.mode, plan.start, plan.end, expenseDaily);
        _loading = false;
      });
    } catch (err) {
      if (!mounted || id != _reqId) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load dashboard: $err'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Decides how the chart is grouped (per day / per month / per year)
  ({_Mode mode, DateTime start, DateTime end})? _plan(
    _Span? span,
    Map<String, double> a,
    Map<String, double> b,
  ) {
    if (span != null) {
      final yearly = _range == DashRange.thisYear || _range == DashRange.lastYear;
      return (
        mode: yearly ? _Mode.month : _Mode.day,
        start: span.start,
        end: span.end,
      );
    }

    // All time
    final keys = [...a.keys, ...b.keys]..sort();
    if (keys.isEmpty) return null;

    final first = DateTime.parse(keys.first);
    final last = DateTime.parse(keys.last);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = last.isAfter(today) ? last : today;
    final months = (end.year - first.year) * 12 + end.month - first.month + 1;

    return (
      mode: months > 24 ? _Mode.year : _Mode.month,
      start: DateTime(first.year, first.month, 1),
      end: end,
    );
  }

  List<_Bucket> _makeBuckets(
    _Mode mode,
    DateTime start,
    DateTime end,
    Map<String, double> data,
  ) {
    final list = <_Bucket>[];

    switch (mode) {
      case _Mode.day:
        final shortRange = end.difference(start).inDays <= 6;
        for (var d = start;
            !d.isAfter(end);
            d = DateTime(d.year, d.month, d.day + 1)) {
          final key = _fmt(d);
          final wd = _weekdays[d.weekday - 1];
          list.add(_Bucket(key, shortRange ? wd : '${d.day}', '$wd, $key'));
        }
        break;

      case _Mode.month:
        final showYear = start.year != end.year;
        for (var m = DateTime(start.year, start.month, 1);
            !m.isAfter(end);
            m = DateTime(m.year, m.month + 1, 1)) {
          final name = _months[m.month - 1];
          final yy = _two(m.year % 100);
          list.add(_Bucket(
            '${m.year}-${_two(m.month)}',
            showYear ? '$name\n$yy' : name,
            '$name ${m.year}',
          ));
        }
        break;

      case _Mode.year:
        for (var y = start.year; y <= end.year; y++) {
          list.add(_Bucket('$y', '$y', '$y'));
        }
        break;
    }

    final index = {for (final b in list) b.key: b};
    data.forEach((day, value) {
      final key = mode == _Mode.day
          ? day
          : (mode == _Mode.month ? day.substring(0, 7) : day.substring(0, 4));
      index[key]?.value += value;
    });

    return list;
  }

  // ---------------- UI pieces ----------------

  Widget _buildRangeDropdown() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<DashRange>(
              value: _range,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: [
                for (final r in DashRange.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) {
                if (v == null || v == _range) return;
                setState(() => _range = v);
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Overview of your business finances',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          _buildRangeDropdown(),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, {Color? color}) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards() {
    // Net profit = sales profit - expenses
    final net = _salesProfit - _expenses;

    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        _summaryCard('Total Income', _money(_income), Icons.trending_up,
            color: Colors.green.shade700),
        _summaryCard('Total Expenses', _money(_expenses), Icons.money_off,
            color: Colors.red.shade600),
        _summaryCard('Sales Profit', _money(_salesProfit), Icons.show_chart,
            color: _salesProfit < 0
                ? Colors.red.shade600
                : Colors.teal.shade700),
        _summaryCard('Net Profit', _money(net), Icons.account_balance_wallet,
            color: net < 0 ? Colors.red.shade600 : Colors.blue.shade700),
      ],
    );
  }

  Widget _buildQuickActions({required bool vertical}) {
    final createInvoice = FilledButton.icon(
      onPressed: widget.onCreateInvoice,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
      icon: const Icon(Icons.add, size: 22),
      label: const Text(
        'Create Invoice',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    final addExpense = OutlinedButton.icon(
      onPressed: widget.onAddExpense,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
      icon: const Icon(Icons.add, size: 22),
      label: const Text(
        'Add Expense',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Actions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (vertical) ...[
          SizedBox(width: double.infinity, child: createInvoice),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: addExpense),
        ] else
          Row(
            children: [
              Expanded(child: createInvoice),
              const SizedBox(width: 12),
              Expanded(child: addExpense),
            ],
          ),
      ],
    );
  }

  Widget _buildCharts(double maxWidth) {
    final incomeCard = _ChartCard(
      title: 'Income',
      icon: Icons.trending_up,
      color: Colors.green.shade600,
      total: _income,
      buckets: _incomeBuckets,
    );
    final expenseCard = _ChartCard(
      title: 'Expenses',
      icon: Icons.money_off,
      color: Colors.red.shade400,
      total: _expenses,
      buckets: _expenseBuckets,
    );

    // Income on the left, Expenses on the right
    if (maxWidth >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: incomeCard),
          const SizedBox(width: 16),
          Expanded(child: expenseCard),
        ],
      );
    }

    return Column(
      children: [
        incomeCard,
        const SizedBox(height: 16),
        expenseCard,
      ],
    );
  }

  static const double _cardW = 220;
  static const double _cardGap = 15;

  /// Width taken by the summary cards (so the dropdown can line up with
  /// the right edge of the last card in the row)
  double _cardsWidth(double available) {
    final cols =
        ((available + _cardGap) / (_cardW + _cardGap)).floor().clamp(1, 4).toInt();
    if (cols < 2) return available;
    return cols * _cardW + (cols - 1) * _cardGap;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool sideBySide = constraints.maxWidth >= 1300;

          final Widget body;
          if (sideBySide) {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cards + dropdown share the same width
                    SizedBox(
                      width: _cardsWidth(constraints.maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderRow(),
                          const SizedBox(height: 15),
                          _buildCards(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Quick Actions use the remaining space
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildQuickActions(vertical: true),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildCharts(constraints.maxWidth),
              ],
            );
          } else {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _cardsWidth(constraints.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(),
                      const SizedBox(height: 20),
                      _buildCards(),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildQuickActions(vertical: false),
                const SizedBox(height: 30),
                _buildCharts(constraints.maxWidth),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // thin loading bar (space is always reserved -> no jumping)
              SizedBox(
                height: 3,
                child: _loading ? const LinearProgressIndicator() : null,
              ),
              const SizedBox(height: 12),
              body,
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// Bar chart card (used for both Income and Expenses)
// =====================================================================

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final double total;
  final List<_Bucket> buckets;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.total,
    required this.buckets,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double maxValue =
        buckets.fold<double>(0, (m, b) => math.max(m, b.value));
    final double maxY = _niceMax(maxValue);
    final double interval = maxY / 5;
    final bool hasData = maxValue > 0;

    final int n = buckets.length;
    final int step = math.max(1, (n / 12).ceil()); // hide some labels if crowded
    final double barWidth = n <= 7 ? 22 : (n <= 12 ? 18 : (n <= 31 ? 8 : 12));

    final labelStyle = TextStyle(fontSize: 11, color: cs.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${_money(total)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: !hasData
                  ? Center(
                      child: Text(
                        'No data for this period',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: cs.outlineVariant,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              interval: interval,
                              getTitlesWidget: (value, meta) => SideTitleWidget(
                                meta: meta,
                                space: 6,
                                child: Text(_compact(value), style: labelStyle),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= n || i % step != 0) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 6,
                                  child: Text(
                                    buckets[i].label,
                                    textAlign: TextAlign.center,
                                    style: labelStyle,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final b = buckets[groupIndex];
                              return BarTooltipItem(
                                '${b.tip}\n${_money(rod.toY)}',
                                const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < n; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: buckets[i].value,
                                  color: color,
                                  width: barWidth,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}