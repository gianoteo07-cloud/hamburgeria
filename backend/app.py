from flask import Flask, request, jsonify
from flask_cors import CORS
from functools import wraps
from database import DatabaseWrapper
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)
CORS(app)

try:
    db = DatabaseWrapper(
        host=os.getenv('DB_HOST', 'localhost'),
        user=os.getenv('DB_USER', 'root'),
        password=os.getenv('DB_PASSWORD', ''),
        database=os.getenv('DB_NAME', 'bb_db'),
        port=int(os.getenv('DB_PORT', '3306')),
    )
except Exception as e:
    print(f"Errore connessione database: {e}")
    db = None


def require_db(f):
    """Decorator per verificare disponibilità database"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if db is None:
            return jsonify({'error': 'Database non disponibile'}), 503
        return f(*args, **kwargs)
    return decorated_function


def validate_price(price):
    """Valida il prezzo"""
    try:
        p = float(price)
        if p <= 0:
            raise ValueError('Il prezzo deve essere positivo')
        return p
    except (ValueError, TypeError):
        raise ValueError('Il prezzo deve essere un numero valido')


@app.route('/')
def index():
    return jsonify({'message': 'API Hamburgeria attiva'})


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200


@app.route('/menu-items', methods=['GET'])
@require_db
def get_menu_items():
    items = db.get_menu_items()
    return jsonify(items), 200


@app.route('/menu-items', methods=['POST'])
@require_db
def add_menu_item():
    data = request.get_json() or {}
    required_fields = ['nome', 'categoria', 'prezzo']
    for field in required_fields:
        if field not in data or data[field] in (None, ''):
            return jsonify({'error': f"Campo '{field}' obbligatorio"}), 400

    try:
        prezzo = validate_price(data['prezzo'])
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

    item_id = db.add_menu_item(
        nome=data['nome'].strip(),
        categoria=data['categoria'].strip(),
        prezzo=prezzo,
        available=data.get('available', True),
        description=data.get('description'),
    )
    return jsonify({'message': 'Prodotto aggiunto con successo', 'id': item_id}), 201


@app.route('/menu-items/<int:item_id>', methods=['PUT'])
@require_db
def update_menu_item(item_id):
    data = request.get_json() or {}
    nome = data.get('nome', '').strip()
    categoria = data.get('categoria', '').strip()
    if not nome or not categoria:
        return jsonify({'error': 'Nome e categoria obbligatori'}), 400

    try:
        prezzo = validate_price(data.get('prezzo', 0))
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

    available = data.get('available')
    description = data.get('description')
    db.update_menu_item(item_id, nome, categoria, prezzo, available=available, description=description)
    return jsonify({'message': 'Prodotto aggiornato'}), 200


@app.route('/menu-items/<int:item_id>', methods=['DELETE'])
@require_db
def delete_menu_item(item_id):
    db.disable_menu_item(item_id)
    return jsonify({'message': 'Prodotto disabilitato'}), 200


@app.route('/orders', methods=['GET'])
@require_db
def get_orders():
    return jsonify(db.get_orders_with_items()), 200


@app.route('/orders', methods=['POST'])
@require_db
def add_order():
    data = request.get_json() or {}
    items = data.get('items', [])

    if not items or not isinstance(items, list):
        return jsonify({'error': 'Ordine vuoto'}), 400

    try:
        normalized_items = []
        for item in items:
            menu_item_id = int(item.get('menu_item_id'))
            quantity = int(item.get('quantity', 1))
            if quantity <= 0:
                return jsonify({'error': 'La quantità deve essere positiva'}), 400
            normalized_items.append({'menu_item_id': menu_item_id, 'quantity': quantity})

        order_id = db.create_order(normalized_items)
        return jsonify({'message': 'Ordine creato con successo', 'id': order_id}), 201
    except ValueError:
        return jsonify({'error': 'Formato ordine non valido'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/orders/<int:order_id>', methods=['PUT'])
@require_db
def update_order(order_id):
    status = request.get_json().get('status') if request.is_json else None
    if not status:
        return jsonify({'error': 'Status richiesto'}), 400
    db.update_order_status(order_id, status)
    return jsonify({'message': 'Status aggiornato'}), 200


@app.route('/orders/<int:order_id>', methods=['DELETE'])
@require_db
def delete_order(order_id):
    db.delete_order(order_id)
    return jsonify({'message': 'Ordine eliminato'}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', '5000')), debug=True)