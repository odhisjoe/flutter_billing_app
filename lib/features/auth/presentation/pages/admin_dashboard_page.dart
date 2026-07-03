import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mpesa/presentation/pages/mpesa_config_page.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/auth_bloc.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ShopBloc, ShopState>(
          builder: (context, shopState) {
            final name = shopState is ShopLoaded ? shopState.shop.name : 'Admin';
            return Text(name, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return PopupMenuButton<void>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                itemBuilder: (context) => <PopupMenuEntry<void>>[
                  const PopupMenuItem<void>(
                    enabled: false,
                    child: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<void>(
                    child: const ListTile(
                      leading: Icon(Icons.point_of_sale),
                      title: Text('POS Terminal'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => context.go('/'),
                  ),
                  PopupMenuItem<void>(
                    child: const ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Logout', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => context.read<AuthBloc>().add(LogoutEvent()),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width < 400 ? 2 : width < 600 ? 3 : width < 900 ? 4 : 5;
          final aspectRatio = width < 400 ? 1.2 : width < 600 ? 1.5 : 1.8;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: aspectRatio,
            children: [
              _card(context, Icons.inventory_2, 'Products', '/products', const Color(0xFF6C63FF)),
              _card(context, Icons.people, 'Customers', '/customers', Colors.teal),
              _card(context, Icons.business, 'Suppliers', '/suppliers', Colors.orange),
              _card(context, Icons.assessment, 'Reports', '/reports', Colors.green),
              _card(context, Icons.storefront, 'Shop', '/shop', Colors.purple),
              _card(context, Icons.inventory, 'Receive Stock', '/purchase-receiving', Colors.brown),
              _card(context, Icons.swap_vert, 'Movement', '/inventory-movement', Colors.indigo),
              _card(context, Icons.warning_amber, 'Reorder', '/reorder-alerts', Colors.red),
              _cardWithAction(context, Icons.payments, 'M-Pesa', () => showMpesaConfigModal(context), Colors.green),
              _card(context, Icons.print, 'Settings', '/settings', Colors.blueGrey),
              _card(context, Icons.group_add, 'Users', '/users', Colors.deepOrange),
              _card(context, Icons.point_of_sale, 'POS', '/', AppTheme.primaryColor),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, IconData icon, String title, String route, Color color) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: _cardContent(icon, title, color),
    );
  }

  Widget _cardWithAction(BuildContext context, IconData icon, String title, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: _cardContent(icon, title, color),
    );
  }

  Widget _cardContent(IconData icon, String title, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
        ],
      ),
    );
  }
}
