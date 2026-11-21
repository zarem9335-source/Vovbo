from flask import Flask, request, jsonify
import json, os

app = Flask(__name__)
DB_FILE = "vpnsopr_orders.json"

def load_orders():
    if os.path.exists(DB_FILE):
        with open(DB_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []

def save_orders(orders):
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(orders, f, ensure_ascii=False, indent=2)

@app.route("/api/orders", methods=["GET"])
def get_all_orders():
    return jsonify(load_orders())

@app.route("/api/orders/user/<username>", methods=["GET"])
def get_user_orders(username):
    orders = [o for o in load_orders() if o.get("username") == username]
    return jsonify(orders)

@app.route("/api/orders", methods=["POST"])
def create_order():
    data = request.get_json(force=True)
    orders = load_orders()
    orders.insert(0, data)
    save_orders(orders)
    return jsonify({"ok": True, "id": data.get("id")}), 201

@app.route("/api/orders/<order_id>/approve", methods=["POST"])
def approve_order(order_id):
    data = request.get_json(silent=True) or {}
    orders = load_orders()
    for o in orders:
        if o.get("id") == order_id:
            o["status"] = "approved"
            o["activatedConfigJson"] = data.get("activatedConfigJson", "")
            break
    save_orders(orders)
    return jsonify({"ok": True})

@app.route("/api/orders/<order_id>/reject", methods=["POST"])
def reject_order(order_id):
    orders = load_orders()
    for o in orders:
        if o.get("id") == order_id:
            o["status"] = "rejected"
            break
    save_orders(orders)
    return jsonify({"ok": True})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8090)
