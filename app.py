"""Secure starter backend for Baqala Sawahil online orders."""
import os
import re
import sqlite3
import secrets
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from urllib.parse import quote
from flask import Flask, jsonify, request, render_template, abort

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 64 * 1024
DB = os.environ.get("SAWAHIL_DB", os.path.join(os.path.dirname(__file__), "sawahil_online.db"))
ADMIN_TOKEN = os.environ.get("SAWAHIL_ADMIN_TOKEN", "").strip()
WHATSAPP_NUMBER = re.sub(r"\D", "", os.environ.get("SAWAHIL_WHATSAPP_NUMBER", "967773543025"))
SHOP_NAME = os.environ.get("SAWAHIL_SHOP_NAME", "بقالة سواحل")
ALLOWED_STATUSES = {"accepted", "preparing", "out_for_delivery", "completed", "rejected"}
_rate = {}

@contextmanager
def conn():
    c = sqlite3.connect(DB, timeout=15)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA foreign_keys=ON")
    c.execute("PRAGMA busy_timeout=15000")
    try:
        yield c
        c.commit()
    except Exception:
        c.rollback()
        raise
    finally:
        c.close()

def init_db():
    with conn() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS products(
          id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL NOT NULL CHECK(price>=0),
          unit TEXT NOT NULL DEFAULT 'حبة', active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE NOT NULL,
          customer_name TEXT NOT NULL, phone TEXT NOT NULL, address TEXT NOT NULL,
          fulfillment TEXT NOT NULL CHECK(fulfillment IN ('delivery','pickup')),
          notes TEXT, total REAL NOT NULL CHECK(total>=0),
          status TEXT NOT NULL DEFAULT 'new', created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS order_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL,
          product_id INTEGER, name TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity>0),
          unit TEXT NOT NULL, price REAL NOT NULL, line_total REAL NOT NULL,
          FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
        CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
        """)

def require_admin():
    if not ADMIN_TOKEN or not secrets.compare_digest(
        request.headers.get("X-Admin-Token", ""), ADMIN_TOKEN
    ):
        abort(401)

def rate_limit():
    # Lightweight abuse protection; use a reverse-proxy/WAF limit in production too.
    now = time.time()
    ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown").split(",")[0].strip()
    hits = [t for t in _rate.get(ip, []) if now - t < 60]
    if len(hits) >= 12:
        return False
    hits.append(now)
    _rate[ip] = hits
    return True

@app.errorhandler(413)
def too_large(_):
    return jsonify(error="حجم الطلب أكبر من المسموح"), 413

@app.get("/health")
def health():
    return jsonify(ok=True, service="sawahil-orders")

@app.get("/")
def storefront():
    return render_template("store.html")

@app.get("/api/store-config")
def store_config():
    return jsonify(shop_name=SHOP_NAME, whatsapp_enabled=bool(WHATSAPP_NUMBER))

@app.get("/api/products")
def products():
    with conn() as c:
        rows = c.execute(
            "SELECT id,name,price,unit FROM products WHERE active=1 ORDER BY name"
        ).fetchall()
    return jsonify([dict(r) for r in rows])

@app.get("/api/admin/products")
def admin_products():
    require_admin()
    with conn() as c:
        rows = c.execute(
            "SELECT id,name,price,unit,active FROM products ORDER BY name"
        ).fetchall()
    return jsonify([dict(r) for r in rows])

@app.put("/api/admin/products/sync")
def sync_products():
    require_admin()
    data = request.get_json(silent=True) or {}
    items = data.get("products")
    if not isinstance(items, list) or len(items) > 2000:
        return jsonify(error="قائمة الأصناف غير صحيحة"), 400
    clean = []
    seen = set()
    for item in items:
        if not isinstance(item, dict):
            return jsonify(error="بيانات صنف غير صحيحة"), 400
        try:
            pid = int(item.get("id"))
            price = float(item.get("price"))
            name = str(item.get("name", "")).strip()
            unit = str(item.get("unit", "حبة")).strip() or "حبة"
        except (TypeError, ValueError):
            return jsonify(error="تحقق من رقم الصنف والسعر"), 400
        if pid <= 0 or pid in seen or not name or len(name) > 120 or price < 0:
            return jsonify(error="اسم أو رقم أو سعر صنف غير صالح"), 400
        seen.add(pid)
        clean.append((pid, name, price, unit[:30]))
    with conn() as c:
        c.execute("UPDATE products SET active=0")
        for row in clean:
            c.execute("""INSERT INTO products(id,name,price,unit,active) VALUES(?,?,?,?,1)
              ON CONFLICT(id) DO UPDATE SET name=excluded.name,price=excluded.price,
              unit=excluded.unit,active=1""", row)
    return jsonify(ok=True, synced=len(clean))

@app.post("/api/orders")
def create_order():
    if not rate_limit():
        return jsonify(error="تم تجاوز عدد المحاولات. حاول بعد قليل"), 429
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify(error="صيغة الطلب غير صحيحة"), 400
    name = str(data.get("customer_name", "")).strip()
    phone = str(data.get("phone", "")).strip()
    address = str(data.get("address", "")).strip()
    fulfillment = str(data.get("fulfillment", "delivery"))
    notes = str(data.get("notes", "")).strip()
    if not name or len(name) > 100:
        return jsonify(error="أدخل الاسم (حتى 100 حرف)"), 400
    if not phone or len(phone) > 25 or not re.fullmatch(r"[0-9+() .-]{7,25}", phone):
        return jsonify(error="رقم الهاتف غير صحيح"), 400
    if fulfillment not in ("delivery", "pickup"):
        return jsonify(error="طريقة الاستلام غير صحيحة"), 400
    if fulfillment == "delivery" and (not address or len(address) > 400):
        return jsonify(error="أدخل عنوان التوصيل (حتى 400 حرف)"), 400
    if fulfillment == "pickup" and not address:
        address = "استلام من المحل"
    if len(notes) > 500:
        return jsonify(error="الملاحظات طويلة جداً"), 400
    items = data.get("items")
    if not isinstance(items, list) or not items or len(items) > 100:
        return jsonify(error="أضف من صنف إلى 100 صنف"), 400

    clean = []
    total = 0.0
    try:
        with conn() as c:
            for item in items:
                if not isinstance(item, dict):
                    return jsonify(error="تفاصيل صنف غير صحيحة"), 400
                pid = int(item.get("product_id"))
                qty = float(item.get("quantity"))
                if qty <= 0 or qty > 10000:
                    return jsonify(error="الكمية غير صحيحة"), 400
                p = c.execute(
                    "SELECT id,name,price,unit FROM products WHERE id=? AND active=1",
                    (pid,)
                ).fetchone()
                if not p:
                    return jsonify(error="أحد الأصناف لم يعد متاحاً"), 400
                line = round(float(p["price"]) * qty, 2)
                total += line
                clean.append((p, qty, line))
            total = round(total, 2)
            code = "SW-" + secrets.token_hex(4).upper()
            created = datetime.now(timezone.utc).isoformat()
            cur = c.execute("""INSERT INTO orders
              (code,customer_name,phone,address,fulfillment,notes,total,status,created_at)
              VALUES(?,?,?,?,?,?,?,'new',?)""",
              (code, name, phone, address, fulfillment, notes, total, created))
            oid = cur.lastrowid
            for p, qty, line in clean:
                c.execute("""INSERT INTO order_items
                  (order_id,product_id,name,quantity,unit,price,line_total)
                  VALUES(?,?,?,?,?,?,?)""",
                  (oid, p["id"], p["name"], qty, p["unit"], p["price"], line))
    except (TypeError, ValueError, OverflowError):
        return jsonify(error="تأكد من كميات وأسعار الأصناف"), 400

    message = f"طلب جديد من {SHOP_NAME}%0Aرقم الطلب: {code}%0Aالعميل: {name}%0Aالهاتف: {phone}%0Aالعنوان: {address}%0Aالإجمالي: {total:g} ريال"
    wa_url = f"https://wa.me/{WHATSAPP_NUMBER}?text={quote(message)}" if WHATSAPP_NUMBER else None
    return jsonify(ok=True, id=oid, code=code, total=total, whatsapp_url=wa_url,
                   message="تم استلام طلبك، ستتواصل معك البقالة للتأكيد"), 201

@app.get("/api/orders")
def admin_orders():
    require_admin()
    with conn() as c:
        rows = c.execute("SELECT * FROM orders ORDER BY id DESC LIMIT 200").fetchall()
        result = []
        for r in rows:
            o = dict(r)
            o["items"] = [dict(x) for x in c.execute(
                "SELECT * FROM order_items WHERE order_id=?", (r["id"],)
            ).fetchall()]
            result.append(o)
    return jsonify(result)

@app.patch("/api/orders/<int:oid>")
def update_order(oid):
    require_admin()
    status = (request.get_json(silent=True) or {}).get("status")
    if status not in ALLOWED_STATUSES:
        return jsonify(error="حالة غير صحيحة"), 400
    with conn() as c:
        cur = c.execute("UPDATE orders SET status=? WHERE id=?", (status, oid))
        if cur.rowcount == 0:
            return jsonify(error="الطلب غير موجود"), 404
    return jsonify(ok=True, id=oid, status=status)

@app.post("/api/products")
def add_product():
    require_admin()
    d = request.get_json(silent=True) or {}
    name = str(d.get("name", "")).strip()
    try:
        price = float(d.get("price"))
    except (TypeError, ValueError):
        return jsonify(error="السعر غير صحيح"), 400
    if not name or len(name) > 120 or price < 0:
        return jsonify(error="اسم الصنف والسعر مطلوبان"), 400
    with conn() as c:
        cur = c.execute(
            "INSERT INTO products(name,price,unit) VALUES(?,?,?)",
            (name, price, str(d.get("unit", "حبة"))[:30])
        )
    return jsonify(id=cur.lastrowid), 201

init_db()

if __name__ == "__main__":
    if not ADMIN_TOKEN:
        raise SystemExit("يجب تعيين SAWAHIL_ADMIN_TOKEN قبل تشغيل الخادم")
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")), debug=False)
