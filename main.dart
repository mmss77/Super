import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database/app_database.dart';
import 'orders/orders_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const SawahilApp());
}

class SawahilApp extends StatelessWidget {
  const SawahilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بقالة سواحل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087E75),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F8),
          foregroundColor: Color(0xFF172B2A),
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE8EEEE)),
          ),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;

  final pages = const [
    DashboardPage(),
    SalesPage(),
    ProductsPage(),
    AccountsPage(),
    ReportsPage(),
    OrdersPage(),
  ];

  final titles = const ['الرئيسية', 'المبيعات', 'الأصناف', 'الحسابات', 'التقارير', 'الطلبات'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF087E75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[selected], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Text('بقالة سواحل', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'المبيعات'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'الأصناف'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'الحسابات'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'الطلبات'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF087E75), Color(0xFF075B57)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أهلاً بك في بقالة سواحل', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7),
              Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 20),
              const Text('مبيعات اليوم', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              const Text('٠ ر.ي', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('ستظهر المبيعات هنا بعد تسجيل أول عملية بيع', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: 'ملخص المتجر', subtitle: 'نظرة سريعة على وضع البقالة'),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: StatCard(title: 'الأصناف', value: '٠', icon: Icons.inventory_2_outlined, color: Color(0xFF2878C8))),
          SizedBox(width: 10),
          Expanded(child: StatCard(title: 'العملاء', value: '٠', icon: Icons.people_outline, color: Color(0xFF8B5CC7))),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: StatCard(title: 'ديون العملاء', value: '٠ ر.ي', icon: Icons.account_balance_wallet_outlined, color: Color(0xFFE09A35))),
          SizedBox(width: 10),
          Expanded(child: StatCard(title: 'مصروفات اليوم', value: '٠ ر.ي', icon: Icons.payments_outlined, color: Color(0xFFD45C5C))),
        ]),
        const SizedBox(height: 20),
        const SectionHeading(title: 'الوصول السريع', subtitle: 'الأعمال الأكثر استخداماً'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: const [
            QuickAction(icon: Icons.add_shopping_cart, title: 'عملية بيع جديدة', color: Color(0xFF087E75)),
            QuickAction(icon: Icons.add_box_outlined, title: 'إضافة صنف', color: Color(0xFF2878C8)),
            QuickAction(icon: Icons.person_add_alt_1, title: 'إضافة عميل', color: Color(0xFF8B5CC7)),
            QuickAction(icon: Icons.local_shipping_outlined, title: 'إضافة مورد', color: Color(0xFFE09A35)),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE5F3F1), child: Icon(Icons.shield_outlined, color: Color(0xFF087E75))),
            title: const Text('بياناتك محفوظة على هذا الجهاز', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('سنضيف النسخ الاحتياطي والاستعادة في مرحلة الحماية', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const SectionHeading({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
    ],
  );
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 17, backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ),
  );
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const QuickAction({super.key, required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        CircleAvatar(radius: 17, backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    ),
  );
}

class EmptyModulePage extends StatelessWidget {
  final String title, description;
  final IconData icon;
  const EmptyModulePage({super.key, required this.title, required this.description, required this.icon});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 86, height: 86, decoration: BoxDecoration(color: const Color(0xFFE5F3F1), borderRadius: BorderRadius.circular(26)), child: Icon(icon, color: const Color(0xFF087E75), size: 42)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.6)),
        const SizedBox(height: 18),
        const Chip(avatar: Icon(Icons.construction_outlined, size: 16), label: Text('سيتم تفعيل الوظائف في المرحلة التالية')),
      ]),
    ),
  );
}

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyModulePage(title: 'المبيعات', description: 'واجهة نقطة البيع ستتيح البحث عن الأصناف وإضافتها إلى السلة وتسجيل الدفع النقدي أو الآجل.', icon: Icons.point_of_sale);
}
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyModulePage(title: 'الأصناف والمخزون', description: 'إدارة الأصناف والأسعار والكميات والباركود والتنبيه عند انخفاض المخزون.', icon: Icons.inventory_2);
}
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyModulePage(title: 'العملاء والموردون', description: 'ملفات العملاء والموردين وكشوف الحساب والديون والمدفوعات.', icon: Icons.people_alt);
}
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyModulePage(title: 'التقارير', description: 'تقارير المبيعات والأرباح والمشتريات والمصروفات وحركة المخزون.', icon: Icons.analytics);
}
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      Card(child: ListTile(leading: Icon(Icons.store_outlined), title: Text('بيانات البقالة'), subtitle: Text('بقالة سواحل'))),
      Card(child: ListTile(leading: Icon(Icons.currency_exchange), title: Text('العملة'), subtitle: Text('الريال اليمني'))),
      Card(child: ListTile(leading: Icon(Icons.backup_outlined), title: Text('النسخ الاحتياطي'), subtitle: Text('سيتم تفعيله في مرحلة الحماية'))),
      Card(child: ListTile(leading: Icon(Icons.print_outlined), title: Text('الطباعة'), subtitle: Text('إعداد الطابعة الحرارية لاحقاً'))),
      Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('حول التطبيق'), subtitle: Text('بقالة سواحل – الإصدار التأسيسي 1.0'))),
    ]),
  );
}
