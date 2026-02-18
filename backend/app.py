from flask import Flask, request, jsonify
from flask_cors import CORS
# il wrapper del database si trova in database.py
from database import DatabaseWrapper
from dotenv import load_dotenv
import os

# carica le variabili definite in un file .env (se esiste)
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
    print(f"Avviso: Impossibile connettere al database - {e}")
    db = None


def check_db():
    if db is None:
        return jsonify({'error': 'Database non disponibile'}), 503
    return None


@app.route('/')
def index():
    return jsonify({'message': 'API Hamburgeria attiva'})


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200


@app.route('/menu-items', methods=['GET'])
def get_menu_items():
    db_error = check_db()
    if db_error:
        return db_error
    items = db.get_menu_items()
    return jsonify(items), 200


@app.route('/menu-items', methods=['POST'])
def add_menu_item():
    db_error = check_db()
    if db_error:
        return db_error

    data = request.get_json() or {}
    required_fields = ['nome', 'categoria', 'prezzo']
    for field in required_fields:
        if field not in data or data[field] in (None, ''):
            return jsonify({'error': f"Campo '{field}' è obbligatorio"}), 400

    try:
        prezzo = float(data['prezzo'])
        if prezzo <= 0:
            return jsonify({'error': 'Il prezzo deve essere positivo'}), 400
    except (ValueError, TypeError):
        return jsonify({'error': 'Il prezzo deve essere un numero valido'}), 400

    item_id = db.add_menu_item(
        nome=data['nome'].strip(),
        categoria=data['categoria'].strip(),
        prezzo=prezzo,
        available=data.get('available', True),
        description=data.get('description'),
    )
    return jsonify({'message': 'Prodotto aggiunto con successo', 'id': item_id}), 201


@app.route('/menu-items/<int:item_id>', methods=['PUT'])
def update_menu_item(item_id):
    db_error = check_db()
    if db_error:
        return db_error

    data = request.get_json() or {}
    try:
        prezzo = float(data.get('prezzo', 0))
    except (TypeError, ValueError):
        return jsonify({'error': 'Prezzo non valido'}), 400

    nome = data.get('nome', '').strip()
    categoria = data.get('categoria', '').strip()
    if not nome or not categoria or prezzo <= 0:
        return jsonify({'error': 'Nome, categoria e prezzo sono obbligatori e validi'}), 400

    available = data.get('available')
    description = data.get('description')
    db.update_menu_item(item_id, nome, categoria, prezzo, available=available, description=description)
    return jsonify({'message': 'Prodotto aggiornato'}), 200


@app.route('/menu-items/<int:item_id>', methods=['DELETE'])
def delete_menu_item(item_id):
    db_error = check_db()
    if db_error:
        return db_error

    db.delete_menu_item(item_id)
    return jsonify({'message': 'Prodotto eliminato'}), 200


@app.route('/orders', methods=['GET'])
def get_orders():
    db_error = check_db()
    if db_error:
        return db_error

    orders = db.get_orders_with_items()
    return jsonify(orders), 200


@app.route('/orders', methods=['POST'])
def add_order():
    db_error = check_db()
    if db_error:
        return db_error

    data = request.get_json() or {}
    items = data.get('items', [])

    if not isinstance(items, list) or len(items) == 0:
        return jsonify({'error': 'L\'ordine deve contenere almeno un prodotto'}), 400

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
def update_order(order_id):
    db_error = check_db()
    if db_error:
        return db_error

    data = request.get_json() or {}
    status = data.get('status')
    if not status:
        return jsonify({'error': "Campo 'status' è richiesto"}), 400

    db.update_order_status(order_id, status)
    return jsonify({'message': 'Status ordine aggiornato'}), 200


@app.route('/orders/<int:order_id>', methods=['DELETE'])
def delete_order(order_id):
    db_error = check_db()
    if db_error:
        return db_error

    db.delete_order(order_id)
    return jsonify({'message': 'Ordine eliminato'}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', '5000')), debug=True)