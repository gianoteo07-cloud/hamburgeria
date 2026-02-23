import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiBase = 'https://literate-parakeet-5g6q4xpgp65rcvv9r-5000.app.github.dev/';

void main() {
  runApp(const McDonaldsKioskApp());
}
// ==================== MODELS ====================

enum MenuCategory { panini, menu, patatine, bevande, dessert, insalate }

extension MenuCategoryExtension on MenuCategory {
  String get displayName {
    switch (this) {
      case MenuCategory.panini: return 'Panini';
      case MenuCategory.menu: return 'Menu';
      case MenuCategory.patatine: return 'Patatine';
      case MenuCategory.bevande: return 'Bevande';
      case MenuCategory.dessert: return 'Dessert';
      case MenuCategory.insalate: return 'Insalate';
    }
  }

  String get icon {
    switch (this) {
      case MenuCategory.panini: return '🍔';
      case MenuCategory.menu: return '📦';
      case MenuCategory.patatine: return '🍟';
      case MenuCategory.bevande: return '🥤';
      case MenuCategory.dessert: return '🍦';
      case MenuCategory.insalate: return '🥗';
    }
  }
}

class MenuItem {
  final int id;
  final String name;
  final double price;
  final MenuCategory category;
  final String? description;
  final bool available;

  MenuItem({required this.id, required this.name, required this.price, required this.category, this.description, this.available = true});

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final categoryName = json['categoria']?.toString().toLowerCase() ?? 'panini';
    MenuCategory category = MenuCategory.panini;
    try {
      category = MenuCategory.values.firstWhere((e) => e.toString().split('.').last == categoryName);
    } catch (e) {
      category = MenuCategory.panini;
    }

    return MenuItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['nome'] ?? '',
      price: double.parse(json['prezzo'].toString()),
      category: category,
      description: json['description'],
      available: json['available'] == 1 || json['available'] == true,
    );
  }
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  CartItem({required this.menuItem, this.quantity = 1});
  double get totalPrice => menuItem.price * quantity;

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItem.id,
    'quantity': quantity,
  };
}

class Order {
  final String id;
  final int orderNumber;
  final List<CartItem> items;
  final double total;
  final DateTime timestamp;
  Order({required this.id, required this.orderNumber, required this.items, required this.total, required this.timestamp});
}

// ==================== CART SERVICE ====================

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  int _orderNumber = 101;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  void addItem(MenuItem menuItem) {
    final existingIndex = _items.indexWhere((item) => item.menuItem.id == menuItem.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(menuItem: menuItem));
    }
    notifyListeners();
  }

  void removeItem(int id) {
    _items.removeWhere((item) => item.menuItem.id == id);
    notifyListeners();
  }

  void incrementQuantity(int id) {
    final index = _items.indexWhere((item) => item.menuItem.id == id);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(int id) {
    final index = _items.indexWhere((item) => item.menuItem.id == id);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Future<Order> submitOrder() async {
    final payload = {
      'items': _items.map((ci) => ci.toJson()).toList(),
    };

    final uri = Uri.parse('${apiBase}orders');
    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final serverId = data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final order = Order(
        id: serverId,
        orderNumber: _orderNumber++,
        items: List.from(_items),
        total: totalPrice,
        timestamp: DateTime.now(),
      );
      clear();
      return order;
    } else {
      throw Exception('Errore invio ordine: ${response.body}');
    }
  }
}

// ==================== MENU SERVICE ====================

class MenuService {
  static Future<List<MenuItem>> fetchMenuItems() async {
    try {
      final uri = Uri.parse('${apiBase}menu-items');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MenuItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static List<MenuItem> getItemsByCategory(List<MenuItem> items, MenuCategory category) {
    return items.where((item) => item.category == category).toList();
  }
}

// ==================== MAIN APP ====================

class McDonaldsKioskApp extends StatelessWidget {
  const McDonaldsKioskApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartService(),
      child: MaterialApp(
        title: 'McDonald\'s',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFFFBC0D),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

// ==================== SPLASH SCREEN ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFBC0D), Color(0xFFFFA000)])),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: const Center(child: Text('M', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Color(0xFFDA291C)))),
              ),
              const SizedBox(height: 30),
              const Text('McDonald\'s', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 50),
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MENU SCREEN ====================

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  MenuCategory selectedCategory = MenuCategory.panini;
  List<MenuItem> allMenuItems = [];
  List<MenuItem> menuItems = [];
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    // Avvia polling automatico ogni 2 secondi per aggiornamenti in tempo reale
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadMenuItems(isAutoRefresh: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMenuItems({bool isAutoRefresh = false}) async {
    try {
      final items = await MenuService.fetchMenuItems();
      if (mounted) {
        setState(() {
          final previousItemIds = allMenuItems.map((e) => e.id).toSet();
          final newItemIds = items.map((e) => e.id).toSet();
          
          // Solo aggiorna se ci sono cambiamenti
          if (previousItemIds != newItemIds) {
            allMenuItems = items;
            menuItems = MenuService.getItemsByCategory(allMenuItems, selectedCategory);
          }
          if (!isAutoRefresh) {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Errore caricamento menu: $e');
      if (!isAutoRefresh) {
        setState(() => isLoading = false);
      }
    }
  }

  void _filterByCategory(MenuCategory category) {
    setState(() {
      selectedCategory = category;
      menuItems = MenuService.getItemsByCategory(allMenuItems, selectedCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFBC0D),
        elevation: 2,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('M', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDA291C)))),
            ),
            const SizedBox(width: 12),
            const Text('McDonald\'s', style: TextStyle(color: Color(0xFFDA291C), fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Consumer<CartService>(
            builder: (context, cart, _) {
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.shopping_cart, color: Color(0xFFDA291C), size: 28),
                    if (cart.itemCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFDA291C), shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  if (cart.items.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDA291C))))
          : allMenuItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fastfood, size: 100, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('Nessun prodotto disponibile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                )
              )
              : Column(
                  children: [
                    _buildCategoryTabs(),
                    Expanded(child: _buildProductGrid()),
                    _buildCartFooter(),
                  ],
                ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 110,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: MenuCategory.values.length,
        itemBuilder: (context, index) {
          final category = MenuCategory.values[index];
          final isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _filterByCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFFBC0D), Color(0xFFFFA000)]) : null,
                  color: isSelected ? null : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? const Color(0xFFFFBC0D) : Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 28)),
                    SizedBox(
                      height: 32,
                      child: Text(category.displayName, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? const Color(0xFFDA291C) : Colors.black87, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: menuItems.length,
      itemBuilder: (context, index) => ProductCard(item: menuItems[index]),
    );
  }

  Widget _buildCartFooter() {
    return Consumer<CartService>(
      builder: (context, cart, _) {
        if (cart.items.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))]),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${cart.itemCount} articoli', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Text('€${cart.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart, size: 20), SizedBox(width: 8), Text('Carrello', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== PRODUCT CARD ====================

class ProductCard extends StatelessWidget {
  final MenuItem item;
  const ProductCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cart, _) {
        return GestureDetector(
          onTap: () {
            cart.addItem(item);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text('${item.name} aggiunto!'))]), backgroundColor: const Color(0xFF4CAF50), duration: const Duration(milliseconds: 800), behavior: SnackBarBehavior.floating));
          },
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [_getCategoryColor().withOpacity(0.2), _getCategoryColor().withOpacity(0.05)]), shape: BoxShape.circle),
                  child: Center(child: Text(item.category.icon, style: const TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 6),
                if (item.description != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(item.description!, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text('€${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF45A049)]), borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_shopping_cart, color: Colors.white, size: 16), SizedBox(width: 6), Text('Aggiungi', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor() {
    switch (item.category) {
      case MenuCategory.panini: return Colors.orange.shade700;
      case MenuCategory.menu: return Colors.red.shade700;
      case MenuCategory.patatine: return Colors.amber.shade700;
      case MenuCategory.bevande: return Colors.blue.shade600;
      case MenuCategory.dessert: return Colors.pink.shade400;
      case MenuCategory.insalate: return Colors.green.shade700;
    }
  }
}

// ==================== CART SCREEN ====================

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDA291C),
        title: const Text('Il Tuo Carrello', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          Consumer<CartService>(
            builder: (context, cart, _) {
              if (cart.items.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Svuota carrello'),
                    content: const Text('Sei sicuro?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
                      TextButton(onPressed: () { cart.clear(); Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Svuota', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                child: const Text('Svuota', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text('Carrello vuoto', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFBC0D), foregroundColor: const Color(0xFFDA291C), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    child: const Text('Torna al Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(color: const Color(0xFFFFBC0D).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text(cartItem.menuItem.category.icon, style: const TextStyle(fontSize: 32))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cartItem.menuItem.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text('€${cartItem.menuItem.price.toStringAsFixed(2)} cad.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              IconButton(onPressed: () => cart.removeItem(cartItem.menuItem.id), icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => cart.decrementQuantity(cartItem.menuItem.id),
                                    icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle), child: const Icon(Icons.remove, size: 20)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2)),
                                    child: Text('${cartItem.quantity}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    onPressed: () => cart.incrementQuantity(cartItem.menuItem.id),
                                    icon: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFBC0D), Color(0xFFFFA000)]), shape: BoxShape.circle), child: const Icon(Icons.add, size: 20, color: Colors.white)),
                                  ),
                                ],
                              ),
                              Text('€${cartItem.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))]),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${cart.itemCount} articoli', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)), const Text('Totale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                          Text('€${cart.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, size: 24), SizedBox(width: 12), Text('Conferma Ordine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== CHECKOUT ====================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool isProcessing = false;

  Future<void> _submitOrder() async {
    setState(() => isProcessing = true);
    final cart = context.read<CartService>();
    final order = await cart.submitOrder();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: order)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFFFFBC0D), foregroundColor: const Color(0xFFDA291C), title: const Text('Conferma Ordine')),
      body: Consumer<CartService>(
        builder: (context, cart, _) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                color: const Color(0xFFFFBC0D),
                child: Column(children: [const Icon(Icons.receipt_long, size: 60, color: Color(0xFFDA291C)), const SizedBox(height: 16), const Text('Riepilogo Ordine', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))), Text('${cart.itemCount} articoli', style: const TextStyle(fontSize: 16))]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Row(
                        children: [
                          Container(width: 50, height: 50, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFDA291C), Color(0xFFC41E1A)]), shape: BoxShape.circle), child: Center(child: Text('${item.quantity}x', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                          const SizedBox(width: 16),
                          Expanded(child: Text(item.menuItem.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          Text('€${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDA291C))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTALE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text('€${cart.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFDA291C)))]),
                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: isProcessing ? null : _submitOrder, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text('Invia Ordine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== CONFIRMATION ====================

class OrderConfirmationScreen extends StatefulWidget {
  final Order order;
  const OrderConfirmationScreen({Key? key, required this.order}) : super(key: key);
  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  int countdown = 10;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown > 0) {
        setState(() => countdown--);
      } else {
        t.cancel();
        _returnToMenu();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _returnToMenu() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MenuScreen()), (route) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 120, height: 120, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 80, color: Color(0xFF4CAF50))),
                  const SizedBox(height: 30),
                  const Text('Ordine Confermato!', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Text('Il tuo numero è', style: TextStyle(fontSize: 18, color: Colors.white)), Text('#${widget.order.orderNumber}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white))])),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [const Icon(Icons.restaurant, size: 50, color: Color(0xFFFFBC0D)), const SizedBox(height: 16), const Text('Preparazione in corso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Articoli:'), Text('${widget.order.items.length}', style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Totale:'), Text('€${widget.order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDA291C)))])]),
                  ),
                  const SizedBox(height: 30),
                  Text('Torna al menu tra $countdown secondi', style: const TextStyle(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _returnToMenu, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFBC0D), foregroundColor: const Color(0xFFDA291C), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)), child: const Text('Torna al Menu Ora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== PROVIDER ====================

class ChangeNotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  final T Function(BuildContext) create;
  final Widget child;
  const ChangeNotifierProvider({Key? key, required this.create, required this.child}) : super(key: key);
  @override
  State<ChangeNotifierProvider<T>> createState() => _ChangeNotifierProviderState<T>();
}

class _ChangeNotifierProviderState<T extends ChangeNotifier> extends State<ChangeNotifierProvider<T>> {
  late T notifier;
  @override
  void initState() {
    super.initState();
    notifier = widget.create(context);
  }

  @override
  void dispose() {
    notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InheritedProvider<T>(notifier: notifier, child: widget.child);
}

class _InheritedProvider<T extends ChangeNotifier> extends InheritedWidget {
  final T notifier;
  const _InheritedProvider({required this.notifier, required Widget child}) : super(child: child);
  @override
  bool updateShouldNotify(_InheritedProvider<T> old) => false;
}

class Consumer<T extends ChangeNotifier> extends StatefulWidget {
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;
  const Consumer({Key? key, required this.builder, this.child}) : super(key: key);
  @override
  State<Consumer<T>> createState() => _ConsumerState<T>();
}

class _ConsumerState<T extends ChangeNotifier> extends State<Consumer<T>> {
  late T notifier;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.dependOnInheritedWidgetOfExactType<_InheritedProvider<T>>();
    if (provider != null) {
      notifier = provider.notifier;
      notifier.addListener(_update);
    }
  }

  @override
  void dispose() {
    notifier.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, notifier, widget.child);
}

extension BuildContextExtension on BuildContext {
  T read<T extends ChangeNotifier>() {
    final provider = getElementForInheritedWidgetOfExactType<_InheritedProvider<T>>()?.widget as _InheritedProvider<T>?;
    if (provider == null) throw Exception('Provider not found');
    return provider.notifier;
  }
}