
import 'dart:async';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/orders_api.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, Object?>> orders = [];
  bool loading = true, syncing = false;
  String filter = 'all';
  Timer? _timer;
  String connectionLabel = 'الاتصال غير مضبوط';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _syncRemote(showMessage: false));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    if (mounted) setState(() => loading = true);
    await _load();
    await _syncRemote(showMessage: false);
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('customer_orders',
      where: filter == 'all' ? null : 'status = ?',
      whereArgs: filter == 'all' ? null : [filter], orderBy: 'id DESC');
    if (mounted) setState(() { orders = rows; loading = false; });
  }

  Future<void> _syncRemote({bool showMessage = true}) async {
    if (syncing) return;
    syncing = true;
    try {
      if (!await OrdersApi.configured) {
        connectionLabel = 'اضبط اتصال الخادم';
      } else {
        final count = await OrdersApi.syncOrders();
        connectionLabel = 'متصل بالخادم';
        await _load();
        if (showMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(count == 0 ? 'لا توجد طلبات جديدة' : 'وصلت $count طلبات جديدة')));
        }
      }
    } catch (e) {
      connectionLabel = 'تعذر الاتصال بالخادم';
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      syncing = false;
      if (mounted) setState(() {});
    }
  }

  String _status(String s) => switch (s) {
    'new' => 'جديد', 'accepted' => 'تم القبول', 'preparing' => 'قيد التجهيز',
    'out_for_delivery' => 'خرج للتوصيل', 'completed' => 'مكتمل',
    'rejected' => 'مرفوض', _ => s
  };

  Future<void> _changeStatus(Map<String, Object?> order) async {
    const statuses = {'accepted':'قبول الطلب','preparing':'بدء التجهيز',
      'out_for_delivery':'خرج للتوصيل','completed':'تم التسليم','rejected':'رفض الطلب'};
    final selected = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true,
        children: statuses.entries.map((e) => ListTile(title: Text(e.value),
          onTap: () => Navigator.pop(ctx, e.key))).toList())));
    if (selected == null) return;
    try {
      final remoteId = order['remote_id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        await OrdersApi.updateRemoteStatus(remoteId, selected);
      }
      final db = await AppDatabase.instance.database;
      await db.update('customer_orders', {'status': selected},
          where: 'id = ?', whereArgs: [order['id']]);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم تحديث الحالة: $e')));
    }
  }

  Future<void> _showDetails(Map<String, Object?> order) async {
    final db = await AppDatabase.instance.database;
    final items = await db.query('customer_order_items',
        where: 'order_id = ?', whereArgs: [order['id']]);
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلب ${order['order_code']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('العميل: ${order['customer_name']}'),
            Text('الهاتف: ${order['phone']}'),
            Text('العنوان: ${order['address']}'),
            Text('الاستلام: ${order['fulfillment'] == 'delivery' ? 'توصيل' : 'استلام من المحل'}'),
            Text('المصدر: ${order['source'] == 'online' ? 'طلب إلكتروني' : 'طلب محلي'}'),
            const Divider(),
            ...items.map((i) => ListTile(contentPadding: EdgeInsets.zero,
              title: Text('${i['product_name']} × ${i['quantity']} ${i['unit']}'),
              trailing: Text('${i['line_total']} ر.ي'))),
            const Divider(),
            Align(alignment: Alignment.centerLeft,
              child: Text('الإجمالي: ${order['total']} ر.ي',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            if ((order['notes'] as String? ?? '').isNotEmpty) Text('ملاحظات: ${order['notes']}'),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () { Navigator.pop(ctx); _changeStatus(order); },
              child: const Text('تحديث حالة الطلب')))
          ]))));
  }


  Future<void> _syncCatalog() async {
    try {
      final count = await OrdersApi.syncCatalog();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نشر $count صنفاً في متجر العملاء')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذرت مزامنة الأصناف: $e')));
    }
  }

  Future<void> _configureServer() async {
    final url = TextEditingController(text: await OrdersApi.serverUrl);
    final token = TextEditingController(text: await OrdersApi.adminToken);
    if (!mounted) return;
    final saved = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ربط تطبيق المحل بالخادم'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'رابط الخادم', hintText: 'https://your-domain.example')),
          const SizedBox(height: 10),
          TextField(controller: token, obscureText: true,
            decoration: const InputDecoration(labelText: 'الرمز الإداري')),
          const SizedBox(height: 8),
          const Text('لا تستخدم عنوان localhost عند تشغيل التطبيق على الهاتف. أدخل رابط الخادم المنشور مع HTTPS.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ));
    if (saved == true) {
      await OrdersApi.saveSettings(url.text, token.text);
      await _syncRemote();
    }
    url.dispose(); token.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(children: [
        const Expanded(child: Text('طلبات العملاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        IconButton(tooltip: 'إعداد الاتصال', onPressed: _configureServer, icon: const Icon(Icons.cloud_outlined)),
        IconButton(tooltip: 'نشر الأصناف للعميل', onPressed: _syncCatalog, icon: const Icon(Icons.cloud_upload_outlined)),
        IconButton(tooltip: 'مزامنة الطلبات', onPressed: () => _syncRemote(), icon: const Icon(Icons.sync)),
      ])),
    Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.circle, size: 8, color: connectionLabel == 'متصل بالخادم' ? Colors.green : Colors.orange),
        const SizedBox(width: 6), Text(connectionLabel, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        if (syncing) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 12,height: 12,child: CircularProgressIndicator(strokeWidth: 2))),
      ])),
    SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        _filterChip('all','الكل'), _filterChip('new','الجديدة'),
        _filterChip('accepted','مقبولة'), _filterChip('preparing','قيد التجهيز'),
        _filterChip('completed','مكتملة')
      ])),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator())
      : orders.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_bag_outlined, size: 58, color: Colors.black26),
          SizedBox(height: 12), Text('لا توجد طلبات حتى الآن',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          SizedBox(height: 6), Text('اضبط اتصال الخادم لاستقبال طلبات العملاء عبر الإنترنت',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))
        ])))
      : RefreshIndicator(onRefresh: _refresh, child: ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final o = orders[i];
          return Card(child: ListTile(onTap: () => _showDetails(o),
            leading: CircleAvatar(backgroundColor: const Color(0xFFE5F3F1),
              child: Icon(o['source'] == 'online' ? Icons.language : Icons.receipt_long,
                color: const Color(0xFF087E75))),
            title: Text('${o['customer_name']} • ${o['order_code']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${o['phone']}\n${o['address']}\n${_status(o['status'] as String)}',
              maxLines: 3, overflow: TextOverflow.ellipsis), isThreeLine: true,
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${o['total']} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.chevron_left)
            ])));
        })))
  ]);

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(label: Text(label), selected: filter == value,
      onSelected: (_) { setState(() { filter = value; loading = true; }); _load(); }));
}
