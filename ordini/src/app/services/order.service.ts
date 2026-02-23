import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

const API_BASE = 'https://literate-parakeet-5g6q4xpgp65rcvv9r-5000.app.github.dev/';

// Interfacce per i dati
export interface OrderItem {
  menu_item_id: number;
  quantity: number;
}

export interface OrderItemDetail extends OrderItem {
  nome: string;
  prezzo_unitario: number;
}

export interface Order {
  id: number;
  totale: number;
  status: string;
  created_at: string;
  items: OrderItemDetail[];
}

@Injectable({
  providedIn: 'root',
})
export class OrderService {
  private apiUrl = `${API_BASE}/orders`;
  private healthUrl = `${API_BASE}/health`;

  constructor(private http: HttpClient) {}

  /**
   * Recupera tutti gli ordini
   */
  getOrders(): Observable<Order[]> {
    return this.http.get<Order[]>(this.apiUrl);
  }

  /**
   * Crea un nuovo ordine
   */
  createOrder(items: OrderItem[]): Observable<{ message: string; id: number }> {
    return this.http.post<{ message: string; id: number }>(this.apiUrl, { items });
  }

  /**
   * Aggiorna lo stato di un ordine
   */
  updateOrderStatus(orderId: number, status: string): Observable<{ message: string }> {
    return this.http.put<{ message: string }>(`${this.apiUrl}/${orderId}`, { status });
  }

  /**
   * Elimina un ordine
   */
  deleteOrder(orderId: number): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/${orderId}`);
  }

  /**
   * Recupera un singolo ordine
   */
  getOrderById(orderId: number): Observable<Order> {
    return this.http.get<Order>(`${this.apiUrl}/${orderId}`);
  }

  /**
   * Controlla la salute dell'API
   */
  checkHealthStatus(): Observable<{ status: string }> {
    return this.http.get<{ status: string }>(this.healthUrl);
  }
}
