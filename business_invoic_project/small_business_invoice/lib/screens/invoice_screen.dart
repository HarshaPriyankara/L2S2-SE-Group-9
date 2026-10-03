import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/pdf_service.dart';

/// One line in the cart
class _CartLine {
  final Map<String, dynamic> product;
  double qty = 1;
  final double unitPrice;

  _CartLine({required this.product, required this.unitPrice});

  int get productId => product['ProductID'] as int;
  String get name => product['ProductName'].toString();
  double get stock => (product['StockQuantity'] as num?)?.toDouble() ?? 0;
  double get subTotal => qty * unitPrice;
}

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // cart state
  final List<_CartLine> _cart = [];
  int _customerId = 1; // Cash Customer
  String _paymentType = 'CASH';
  int _tab = 0; // 0 = New Sale, 1 = History

  final _searchController = TextEditingController();
  final _discountController = TextEditingController();
  final _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ helpers
  String _fmtQty(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();

  double get _subTotal => _cart.fold(0.0, (s, l) => s + l.subTotal);
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _total => (_subTotal - _discount).clamp(0, double.infinity);
  double get _cashReceived => _cashController.text.trim().isEmpty
      ? _total
      : (double.tryParse(_cashController.text.trim()) ?? 0);
  double get _balance => _paymentType == 'CASH' ? _cashReceived - _total : 0;

  void _msg(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  // ------------------------------------------------------------ data
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final products = await DatabaseHelper.instance.getProducts();
    final customers = await DatabaseHelper.instance.getCustomers();
    final sales = await DatabaseHelper.instance.getSales();
    if (!mounted) return;
    setState(() {
      _products = products;
      _customers = customers;
      _sales = sales;
      _isLoading = false;
    });
    _applySearch();
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        if (q.isEmpty) return true;
        final name = (p['ProductName'] ?? '').toString().toLowerCase();
        final cat = (p['CategoryName'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    });
  }

  // ------------------------------------------------------------ cart actions
  void _addToCart(Map<String, dynamic> p) {
    final stock = (p['StockQuantity'] as num?)?.toDouble() ?? 0;
    final idx = _cart.indexWhere((l) => l.productId == p['ProductID']);

    if (idx >= 0) {
      if (_cart[idx].qty + 1 > stock) {
        _msg('Only ${_fmtQty(stock)} in stock for ${p['ProductName']}',
            color: Colors.orange);
        return;
      }
      setState(() => _cart[idx].qty += 1);
    } else {
      if (stock < 1) {
        _msg('${p['ProductName']} is out of stock', color: Colors.orange);
        return;
      }
      setState(() => _cart.add(_CartLine(
            product: p,
            unitPrice: (p['OurPrice'] as num?)?.toDouble() ?? 0,
          )));
    }
  }

  void _changeQty(_CartLine line, double delta) {
    final newQty = line.qty + delta;
    if (newQty <= 0) {
      setState(() => _cart.remove(line));
      return;
    }
    if (newQty > line.stock) {
      _msg('Only ${_fmtQty(line.stock)} in stock', color: Colors.orange);
      return;
    }
    setState(() => line.qty = newQty);
  }

  void _editQtyDialog(_CartLine line) {
    final c = TextEditingController(text: _fmtQty(line.qty));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(line.name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (Stock: ${_fmtQty(line.stock)})',
          ),
          onSubmitted: (_) => _applyQty(dialogContext, line, c.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _applyQty(dialogContext, line, c.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _applyQty(BuildContext dialogContext, _CartLine line, String text) {
    final n = double.tryParse(text.trim());
    if (n == null || n <= 0) {
      _msg('Enter a valid quantity');
      return;
    }
    if (n > line.stock) {
      _msg('Only ${_fmtQty(line.stock)} in stock', color: Colors.orange);
      return;
    }
    setState(() => line.qty = n);
    Navigator.pop(dialogContext);
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerId = 1;
      _paymentType = 'CASH';
      _discountController.clear();
      _cashController.clear();
    });
  }

  // ------------------------------------------------------------ pdf
  Future<void> _savePdf(Map<String, dynamic> details) async {
    try {
      final path = await PdfService.saveInvoicePdf(details);
      if (path != null) {
        _msg('PDF saved: $path', color: Colors.green);
        await PdfService.openFile(path);
      }
    } catch (e) {
      _msg('Could not save PDF: $e');
    }
  }

  // ------------------------------------------------------------ checkout
  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    if (_discount < 0 || _discount > _subTotal) {
      _msg('Discount must be between 0 and the sub total');
      return;
    }
    if (_paymentType == 'CASH' && _cashReceived < _total) {
      _msg('Cash received is less than the total');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final saleData = {
        'CustomerID': _customerId,
        'TotalAmount': _total,
        'TotalDiscount': _discount,
        'CashReceived': _paymentType == 'CASH' ? _cashReceived : _total,
        'Balance': _balance,
        'PaymentType': _paymentType,
      };

      // NOTE: only DB columns here (ProductName is NOT a SaleItems column)
      final items = _cart
          .map((l) => {
                'ProductID': l.productId,
                'ProductName': l.name, // used only for stock error message
                'Quantity': l.qty,
                'UnitPrice': l.unitPrice,
                'SubTotal': l.subTotal,
              })
          .toList();

      final billId = await DatabaseHelper.instance.insertSale(saleData, items);

      _clearCart();
      await _loadAll(); // refresh stock + history

      _msg('Invoice #$billId saved', color: Colors.green);

      final details = await DatabaseHelper.instance.getSaleDetails(billId);
      if (details != null) {
        await _savePdf(details);
      }
    } catch (e) {
      _msg('Could not save invoice: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ------------------------------------------------------------ UI: products
  Widget _buildProductPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applySearch(),
            decoration: InputDecoration(
              hintText: 'Search product or category...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(child: Text('No products found.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, i) {
                    final p = _filteredProducts[i];
                    final stock = (p['StockQuantity'] as num?)?.toDouble() ?? 0;
                    final price = (p['OurPrice'] as num?)?.toDouble() ?? 0;
                    final inCart = _cart
                        .where((l) => l.productId == p['ProductID'])
                        .fold(0.0, (s, l) => s + l.qty);
                    final out = stock <= 0;

                    return Card(
                      child: ListTile(
                        enabled: !out,
                        onTap: out ? null : () => _addToCart(p),
                        leading: CircleAvatar(
                          backgroundColor: out ? Colors.red : Colors.blue,
                          child: const Icon(Icons.inventory_2,
                              color: Colors.white),
                        ),
                        title: Text(p['ProductName'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p['CategoryName'] ?? 'N/A'} | '
                          '${out ? 'Out of stock' : 'Stock: ${_fmtQty(stock)}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (inCart > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label: Text('x${_fmtQty(inCart)}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            Text('Rs. ${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Icon(Icons.add_circle,
                                color: out ? Colors.grey : Colors.green),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ UI: cart
  Widget _buildCartPanel() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      child: Column(
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart),
                const SizedBox(width: 8),
                Text('Cart (${_cart.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cart.isEmpty ? null : _clearCart,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<int>(
              initialValue: _customers.any((c) => c['CustomerID'] == _customerId)
                  ? _customerId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Customer',
                prefixIcon: Icon(Icons.person),
                isDense: true,
              ),
              items: _customers
                  .map((c) => DropdownMenuItem<int>(
                        value: c['CustomerID'] as int,
                        child: Text(c['CustomerName'].toString()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _customerId = v ?? 1),
            ),
          ),
          const Divider(height: 20),

          // lines
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text('Cart is empty.\nTap a product to add it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final line = _cart[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      'Rs. ${line.unitPrice.toStringAsFixed(2)} each',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _changeQty(line, -1),
                            ),
                            InkWell(
                              onTap: () => _editQtyDialog(line),
                              child: Container(
                                constraints:
                                    const BoxConstraints(minWidth: 36),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(_fmtQty(line.qty),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _changeQty(line, 1),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(line.subTotal.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _cart.remove(line)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // totals + payment
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _totalRow('Sub Total', _subTotal),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Discount (Rs.)')),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _discountController,
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            isDense: true, hintText: '0.00'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _totalRow('TOTAL', _total, big: true),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'CASH',
                        icon: Icon(Icons.payments),
                        label: Text('Cash')),
                    ButtonSegment(
                        value: 'CARD',
                        icon: Icon(Icons.credit_card),
                        label: Text('Card')),
                  ],
                  selected: {_paymentType},
                  onSelectionChanged: (s) =>
                      setState(() => _paymentType = s.first),
                ),
                if (_paymentType == 'CASH') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('Cash Received (Rs.)')),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _cashController,
                          onChanged: (_) => setState(() {}),
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              isDense: true,
                              hintText: _total.toStringAsFixed(2)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _totalRow('Balance', _balance < 0 ? 0 : _balance,
                      color: _balance < 0 ? Colors.red : Colors.green),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: (_cart.isEmpty || _isSaving) ? null : _checkout,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Save Invoice & PDF'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value,
      {bool big = false, Color? color}) {
    final style = TextStyle(
      fontSize: big ? 20 : 14,
      fontWeight: big ? FontWeight.bold : FontWeight.w500,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('Rs. ${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }

  // ------------------------------------------------------------ UI: history
  Widget _buildHistory() {
    if (_sales.isEmpty) {
      return const Center(child: Text('No Invoices Found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt)),
            title: Text(
                'Invoice #${sale['BillID']} - ${sale['CustomerName'] ?? 'Cash Customer'}'),
            subtitle: Text(
                'Date: ${sale['BillDate']} | ${sale['PaymentType']} | Total: Rs. ${(sale['TotalAmount'] as num).toStringAsFixed(2)}'),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'Save as PDF',
              onPressed: () async {
                final d = await DatabaseHelper.instance
                    .getSaleDetails(sale['BillID'] as int);
                if (d != null) await _savePdf(d);
              },
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                segments: [
                  const ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.point_of_sale),
                      label: Text('New Sale')),
                  ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.history),
                      label: Text('History (${_sales.length})')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildProductPanel()),
                    SizedBox(width: 400, child: _buildCartPanel()),
                  ],
                ),
                _buildHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}