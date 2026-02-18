# hamburgeria

Questo progetto contiene un backend Flask che utilizza un database MySQL/MariaDB.

## Avvio del backend

1. Posizionati nella directory `backend`:
   ```bash
   cd backend
   ```
2. (Opzionale) crea un ambiente virtuale e installa le dipendenze:
   ```bash
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. Crea un file `.env` basato su `.env.example` e modifica i valori secondo le tue credenziali:
   ```bash
   cp .env.example .env
   # poi modifica .env con host, user, password, nome database, porta...
   ```
4. Avvia l'API:
   ```bash
   flask run   # oppure python app.py
   ```

L'app legge automaticamente le variabili d'ambiente (anche da `.env`) per connettersi al database.
