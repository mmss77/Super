
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

class OrdersApi {
  static const _urlKey = 'sawahil_server_url';
  static const _tokenKey = 'sawahil_admin_token';

  static Future<String> get serverUrl async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_urlKey) ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String> get adminToken async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_tokenKey) ?? '').trim();
  }

  static Future<void> saveSettings(String url, String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_urlKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
    await p.setString(_tokenKey, token.trim());
  }

  static Future<bool> get configured async =>
      (await serverUrl).isNotEmpty && (await adminToken).isNotEmpty;

  static Future<Map<String, dynamic>> testConnection() async {
    final base = await serverUrl;
    final token = await adminToken;
    if (base.isEmpty || token.isEmpty) {
      return {'ok': false, 'message': 'أدخل رابط الخادم والرمز الإداري أولاً'};
    }
    try {
      final response = await http.get(Uri.parse('$base/api/orders'),
          headers: {'X-Admin-Token': token}).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) return {'ok': true, 'message': 'الاتصال بالخادم ناجح'};
      if (response.statusCode == 401) return {'ok': false, 'message': 'الرمز الإداري غير صحيح'};
      return {'ok': false, 'message': 'رد الخادم: ${response.statusCode}'};
    } catch (_) {
      return {'ok': false, 'message': 'تعذر الوصول إلى الخادم. تحقق من الرابط والإنترنت'};
    }
  }

  static Future<int> syncOrders() async {
    final base = await serverUrl;
    final token = await adminToken;
    if (base.isEmpty || token.isEmpty) return 0;
    final response = await http.get(Uri.parse('$base/api/orders'),
        headers: {'X-Admin-Token': token}).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(response.statusCode == 401
          ? 'الرمز الإداري غير صحيح'
          : 'فشل جلب الطلبات (${response.statusCode})');
    }
    final payload = jsonDecode(response.body);
    if (payload is! List) throw Exception('صيغة بيانات الطلبات غير صحيحة');
    final db = await AppDatabase.instance.database;
    var added = 0;
    for (final raw in payload) {
      if (raw is! Map) continue;
      final o = Map<String, dynamic>.from(raw);
      final remoteId = '${o['id']}';
      final existing = await db.query('customer_orders',
          columns: ['id'], where: 'remote_id = ?', whereArgs: [remoteId], limit: 1);
      if (existing.isNotEmpty) {
        await db.update('customer_orders', {
          'status': o['status'] ?? 'new',
          'total': (o['total'] as num?)?.toDouble() ?? 0,
        }, where: 'remote_id = ?', whereArgs: [remoteId]);
        continue;
      }
      final total = (o['total'] as num?)?.toDouble() ?? 0;
      final code = (o['code'] ?? 'REMOTE-$remoteId').toString();
      final orderId = await db.insert('customer_orders', {
        'order_code': code,
        'customer_name': o['customer_name'] ?? 'عميل',
        'phone': o['phone'] ?? '',
        'address': o['address'] ?? '',
        'fulfillment': o['fulfillment'] ?? 'delivery',
        'notes': o['notes'] ?? '',
        'subtotal': total,
        'delivery_fee': 0,
        'total': total,
        'status': o['status'] ?? 'new',
        'source': 'online',
        'remote_id': remoteId,
        'created_at': o['created_at'] ?? DateTime.now().toIso8601String(),
      });
      final items = o['items'];
      if (items is List) {
        for (final itemRaw in items) {
          if (itemRaw is! Map) continue;
          final item = Map<String, dynamic>.from(itemRaw);
          await db.insert('customer_order_items', {
            'order_id': orderId,
            'product_id': item['product_id'],
            'product_name': item['name'] ?? 'صنف',
            'quantity': (item['quantity'] as num?)?.toDouble() ?? 0,
            'unit': item['unit'] ?? 'حبة',
            'unit_price': (item['price'] as num?)?.toDouble() ?? 0,
            'line_total': (item['line_total'] as num?)?.toDouble() ?? 0,
          });
        }
      }
      added++;
    }
    return added;
  }


  static Future<int> syncCatalog() async {
    final base = await serverUrl;
    final token = await adminToken;
    if (base.isEmpty || token.isEmpty) {
      throw Exception('أدخل رابط الخادم والرمز الإداري أولاً');
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query('products', columns: ['id', 'name', 'sale_price', 'unit']);
    final products = rows.map((p) => {
      'id': p['id'],
      'name': p['name'],
      'price': p['sale_price'],
      'unit': p['unit'] ?? 'حبة',
    }).toList();
    final response = await http.put(Uri.parse('$base/api/admin/products/sync'),
      headers: {'Content-Type': 'application/json', 'X-Admin-Token': token},
      body: jsonEncode({'products': products})).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('فشلت مزامنة الأصناف (${response.statusCode})');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return (result['synced'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateRemoteStatus(String remoteId, String status) async {
    final base = await serverUrl;
    final token = await adminToken;
    if (base.isEmpty || token.isEmpty) throw Exception('إعداد اتصال الخادم غير مكتمل');
    final response = await http.patch(Uri.parse('$base/api/orders/$remoteId'),
        headers: {'Content-Type': 'application/json', 'X-Admin-Token': token},
        body: jsonEncode({'status': status})).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحديث الطلب على الخادم (${response.statusCode})');
    }
  }
}
