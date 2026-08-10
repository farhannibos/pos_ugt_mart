import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';
import 'dashboard_screen.dart';
import 'product_screen.dart';
import 'usaha_screen.dart';
import 'cart_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'member_screen.dart';
import 'kas_screen.dart';
import 'payment_screen.dart';
import 'pembelian_screen.dart';
import 'shift_screen.dart';
import 'upgrade_screen.dart';

class MainScaffold extends StatefulWidget {
  final int initialTab;
  const MainScaffold({super.key, this.initialTab = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentTab;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab < 2 ? widget.initialTab : widget.initialTab - 1;
    _screens = [
      const DashboardScreen(),
      const UsahaScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AppProvider>();
      if (prov.isPremium && prov.activeShift == null) {
        showBukaShiftDialog(context, prov);
      }
    });
  }

  void _handleTabTap(int i, BuildContext context) {
    if (i == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CartScreen()))
          .then((result) {
        if (result == 'goto_products' && mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductScreen()),
          );
        }
      });
    } else {
      setState(() => _currentTab = i < 2 ? i : i - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    final stack = Stack(
      children: [
        IndexedStack(index: _currentTab, children: _screens),
        ToastWidget(message: prov.toast),
      ],
    );

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(
              currentTab: _currentTab,
              cartCount: prov.cartItemCount,
              onTap: (i) => _handleTabTap(i, context),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppColors.borderLight),
            Expanded(child: stack),
          ],
        ),
      );
    }

    return Scaffold(
      body: stack,
      bottomNavigationBar: _BottomNav(
        currentTab: _currentTab,
        cartCount: prov.cartItemCount,
        onTap: (i) => _handleTabTap(i, context),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _SideNav({required this.currentTab, required this.cartCount, required this.onTap});

  int get _railIndex => currentTab <= 1 ? currentTab : currentTab + 1;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: _railIndex,
      onDestinationSelected: onTap,
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primaryLight,
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      selectedLabelTextStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textDim),
      unselectedLabelTextStyle: GoogleFonts.inter(fontSize: 10, color: AppColors.textDim),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Beranda'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('Usahaku'),
        ),
        NavigationRailDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
              ),
              if (cartCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$cartCount',
                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          label: const Text('Kasir'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time),
          label: Text('Riwayat'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profil'),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentTab, required this.cartCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Beranda'),
      _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Usahaku'),
      null, // center FAB slot
      _NavItem(icon: Icons.access_time_outlined, activeIcon: Icons.access_time, label: 'Riwayat'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              if (items[i] == null) {
                // Center cart FAB
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(17),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.34),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 23),
                            ),
                            if (cartCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.red,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$cartCount',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Kasir',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Convert tab index: skip slot 2 (FAB), remap 3→2, 4→3
              final tabIdx = i < 2 ? i : i - 1;
              final isActive = currentTab == tabIdx;
              final item = items[i]!;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 21,
                        color: isActive ? AppColors.primary : AppColors.textDim,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isActive ? AppColors.primary : AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// Route generator for named routes
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const MainScaffold());
    case '/produk':
      return MaterialPageRoute(builder: (_) => const ProductScreen());
    case '/payment':
      return MaterialPageRoute(builder: (_) => const PaymentScreen());
    case '/member':
      return MaterialPageRoute(builder: (_) => const MemberScreen());
    case '/kas-masuk':
      return MaterialPageRoute(builder: (_) => const KasScreen(initialType: 'masuk'));
    case '/kas-keluar':
      return MaterialPageRoute(builder: (_) => const KasScreen(initialType: 'keluar'));
    case '/pembelian':
      return MaterialPageRoute(builder: (_) => const PembelianScreen());
    case '/upgrade':
      return MaterialPageRoute(builder: (_) => const UpgradeScreen());
    default:
      return null;
  }
}
