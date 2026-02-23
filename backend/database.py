import pymysql


class DatabaseWrapper:
    def __init__(self, host, user, password, database, port):
        self.db_config = {
            'host': host,
            'user': user,
            'password': password,
            'database': database,
            'port': port,
            'cursorclass': pymysql.cursors.DictCursor,
            'autocommit': False,
        }
        self.create_tables()
        self._ensure_status_column()
        self._ensure_menu_columns()

    def connect(self):
        return pymysql.connect(**self.db_config)

    def execute_query(self, query, params=()):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
            conn.commit()
        finally:
            conn.close()

    def fetch_query(self, query, params=()):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                return cursor.fetchall()
        finally:
            conn.close()

    def create_tables(self):
        self.execute_query(
            '''
            CREATE TABLE IF NOT EXISTS menu_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                nome VARCHAR(100) NOT NULL,
                categoria VARCHAR(50) NOT NULL,
                prezzo DECIMAL(10,2) NOT NULL,
                available TINYINT(1) NOT NULL DEFAULT 1,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            '''
        )

        self.execute_query(
            '''
            CREATE TABLE IF NOT EXISTS orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                totale DECIMAL(10,2) NOT NULL,
                status VARCHAR(50) NOT NULL DEFAULT 'In Attesa',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            '''
        )

        self.execute_query(
            '''
            CREATE TABLE IF NOT EXISTS order_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_id INT NOT NULL,
                menu_item_id INT NOT NULL,
                quantity INT NOT NULL,
                prezzo_unitario DECIMAL(10,2) NOT NULL,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
            )
            '''
        )

    def get_menu_items(self):
        return self.fetch_query('SELECT * FROM menu_items WHERE available=1 ORDER BY created_at DESC')

    def _ensure_status_column(self):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SHOW COLUMNS FROM orders LIKE 'status'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE orders ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'In Attesa'")
            conn.commit()
        finally:
            conn.close()

    def _ensure_menu_columns(self):
        # se la tabella esiste ma mancano colonne, le aggiungiamo
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SHOW COLUMNS FROM menu_items LIKE 'available'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE menu_items ADD COLUMN available TINYINT(1) NOT NULL DEFAULT 1")
                cursor.execute("SHOW COLUMNS FROM menu_items LIKE 'description'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE menu_items ADD COLUMN description TEXT")
            conn.commit()
        finally:
            conn.close()

    def update_menu_item(self, item_id, nome, categoria, prezzo, available=None, description=None):
        if available is None and description is None:
            self.execute_query(
                'UPDATE menu_items SET nome=%s, categoria=%s, prezzo=%s WHERE id=%s',
                (nome, categoria, prezzo, item_id)
            )
        else:
            parts = ['nome=%s', 'categoria=%s', 'prezzo=%s']
            params = [nome, categoria, prezzo]
            if available is not None:
                parts.append('available=%s')
                params.append(1 if available else 0)
            if description is not None:
                parts.append('description=%s')
                params.append(description)
            params.append(item_id)
            query = 'UPDATE menu_items SET ' + ', '.join(parts) + ' WHERE id=%s'
            self.execute_query(query, tuple(params))

    def delete_menu_item(self, item_id):
        self.execute_query('DELETE FROM menu_items WHERE id=%s', (item_id,))

    def disable_menu_item(self, item_id):
        self.execute_query('UPDATE menu_items SET available=0 WHERE id=%s', (item_id,))

    def add_menu_item(self, nome, categoria, prezzo, available=True, description=None):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute(
                    'INSERT INTO menu_items (nome, categoria, prezzo, available, description) VALUES (%s, %s, %s, %s, %s)',
                    (nome, categoria, prezzo, 1 if available else 0, description),
                )
                item_id = cursor.lastrowid
            conn.commit()
            return item_id
        finally:
            conn.close()

    def create_order(self, items):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                total = 0.0
                details = []
                for item in items:
                    cursor.execute('SELECT id, prezzo FROM menu_items WHERE id = %s', (item['menu_item_id'],))
                    menu_item = cursor.fetchone()
                    if not menu_item:
                        raise ValueError(f"Prodotto con id {item['menu_item_id']} non trovato")
                    subtotal = float(menu_item['prezzo']) * item['quantity']
                    total += subtotal
                    details.append({
                        'menu_item_id': menu_item['id'],
                        'quantity': item['quantity'],
                        'prezzo_unitario': float(menu_item['prezzo']),
                    })

                cursor.execute('INSERT INTO orders (totale) VALUES (%s)', (total,))
                order_id = cursor.lastrowid

                for detail in details:
                    cursor.execute(
                        'INSERT INTO order_items (order_id, menu_item_id, quantity, prezzo_unitario) VALUES (%s, %s, %s, %s)',
                        (order_id, detail['menu_item_id'], detail['quantity'], detail['prezzo_unitario']),
                    )

            conn.commit()
            return order_id
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def get_orders_with_items(self):
        orders = self.fetch_query('SELECT id, totale, status, created_at FROM orders ORDER BY created_at DESC')
        for order in orders:
            order['items'] = self.fetch_query(
                '''
                SELECT oi.menu_item_id, mi.nome, oi.quantity, oi.prezzo_unitario
                FROM order_items oi
                JOIN menu_items mi ON mi.id = oi.menu_item_id
                WHERE oi.order_id = %s
                ''',
                (order['id'],),
            )
        return orders

    def update_order_status(self, order_id, status):
        self.execute_query('UPDATE orders SET status=%s WHERE id=%s', (status, order_id))

    def delete_order(self, order_id):
        self.execute_query('DELETE FROM orders WHERE id=%s', (order_id,))
