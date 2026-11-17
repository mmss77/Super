import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      join(dbPath, 'sawahil_store.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            barcode TEXT UNIQUE,
            category TEXT,
            purchase_price REAL NOT NULL DEFAULT 0,
            sale_price REAL NOT NULL DEFAULT 0,
            quantity REAL NOT NULL DEFAULT 0,
            unit TEXT NOT NULL DEFAULT 'حبة',
            min_quantity REAL NOT NULL DEFAULT 0,
            expiry_date TEXT,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE parties (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            type TEXT NOT NULL CHECK(type IN ('customer','supplier')),
            opening_balance REAL NOT NULL DEFAULT 0,
            credit_limit REAL NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT NOT NULL UNIQUE,
            party_id INTEGER,
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            paid REAL NOT NULL DEFAULT 0,
            payment_method TEXT NOT NULL DEFAULT 'cash',
            created_at TEXT NOT NULL,
            FOREIGN KEY(party_id) REFERENCES parties(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            cost_price REAL NOT NULL DEFAULT 0,
            line_total REAL NOT NULL,
            FOREIGN KEY(sale_id) REFERENCES sales(id),
            FOREIGN KEY(product_id) REFERENCES products(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE financial_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            party_id INTEGER,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            direction TEXT NOT NULL,
            description TEXT,
            reference_id INTEGER,
            created_at TEXT NOT NULL,
            FOREIGN KEY(party_id) REFERENCES parties(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            movement_type TEXT NOT NULL,
            quantity REAL NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id)
          )
        ''');
        await db.execute('CREATE INDEX idx_products_name ON products(name)');
        await db.execute('CREATE INDEX idx_parties_name ON parties(name)');
        await db.execute('CREATE INDEX idx_sales_date ON sales(created_at)');
        await db.execute('CREATE INDEX idx_transactions_party ON financial_transactions(party_id)');
        await db.execute('''CREATE TABLE customer_orders (id INTEGER PRIMARY KEY AUTOINCREMENT, order_code TEXT NOT NULL UNIQUE, customer_name TEXT NOT NULL, phone TEXT NOT NULL, address TEXT NOT NULL, fulfillment TEXT NOT NULL CHECK(fulfillment IN ('delivery','pickup')), notes TEXT, subtotal REAL NOT NULL DEFAULT 0, delivery_fee REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'new', source TEXT NOT NULL DEFAULT 'local', remote_id TEXT, created_at TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE customer_order_items (id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL, product_id INTEGER, product_name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL DEFAULT 'حبة', unit_price REAL NOT NULL, line_total REAL NOT NULL, FOREIGN KEY(order_id) REFERENCES customer_orders(id) ON DELETE CASCADE)''');
        await db.execute('CREATE INDEX idx_customer_orders_date ON customer_orders(created_at)');
        await db.execute('CREATE INDEX idx_customer_orders_status ON customer_orders(status)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE customer_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_code TEXT NOT NULL UNIQUE,
            customer_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            address TEXT NOT NULL,
            fulfillment TEXT NOT NULL CHECK(fulfillment IN ('delivery','pickup')),
            notes TEXT,
            subtotal REAL NOT NULL DEFAULT 0,
            delivery_fee REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'new',
            source TEXT NOT NULL DEFAULT 'local',
            remote_id TEXT,
            created_at TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE customer_order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_id INTEGER,
            product_name TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL DEFAULT 'حبة',
            unit_price REAL NOT NULL,
            line_total REAL NOT NULL,
            FOREIGN KEY(order_id) REFERENCES customer_orders(id) ON DELETE CASCADE
          )''');
          await db.execute('CREATE INDEX idx_customer_orders_date ON customer_orders(created_at)');
          await db.execute('CREATE INDEX idx_customer_orders_status ON customer_orders(status)');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _database!;
  }
}
