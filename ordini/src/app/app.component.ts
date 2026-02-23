import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { OrderService, Order } from './services/order.service';

@Component({
  selector: 'app-root',
  imports: [CommonModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent implements OnInit {
  orders: Order[] = [];
  isLoading = true;
  error: string | null = null;

  constructor(private orderService: OrderService) {}

  ngOnInit() {
    this.loadOrders();
  }

  /**
   * Carica tutti gli ordini
   */
  loadOrders() {
    this.isLoading = true;
    this.error = null;
    this.orderService.getOrders().subscribe({
      next: (data) => {
        this.orders = data;
        this.isLoading = false;
      },
      error: (err) => {
        this.handleError('Impossibile caricare gli ordini', err);
        this.isLoading = false;
      }
    });
  }

  /**
   * Aggiorna lo stato di un ordine
   */
  updateOrderStatus(orderId: number, newStatus: string) {
    this.orderService.updateOrderStatus(orderId, newStatus).subscribe({
      next: () => this.loadOrders(),
      error: (err) => this.handleError('Errore nell\'aggiornamento dello stato', err)
    });
  }

  onStatusChange(event: Event, orderId: number) {
    const value = (event.target as HTMLSelectElement).value;
    this.updateOrderStatus(orderId, value);
  }

  /**
   * Elimina un ordine
   */
  deleteOrder(orderId: number) {
    if (confirm('Sei sicuro di voler eliminare questo ordine?')) {
      this.orderService.deleteOrder(orderId).subscribe({
        next: () => this.loadOrders(),
        error: (err) => this.handleError('Errore nell\'eliminazione dell\'ordine', err)
      });
    }
  }

  private handleError(message: string, err: any) {
    console.error(message, err);
    this.error = message;
  }
}
