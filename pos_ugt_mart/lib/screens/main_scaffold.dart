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
import '../services/tour_service.dart';

class MainScaffold extends StatefulWidget {
  final int initialTab;
  const MainScaffold({super.key, this.initialTab = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentTab;
  late List<Widget> _screens;

  // GlobalKeys untuk coach mark tour
  final _keyBeranda = GlobalKey();
  final _keyUsahaku = GlobalKey();
  final _keyKasir   = GlobalKey();
  final _keyRiwayat = GlobalKey();
  final _keyProfil  = GlobalKey();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<AppProvider>();
      if (prov.isPremium && prov.activeShift == null) {
        showBukaShiftDialog(context, prov);
      }
      // Tunjukkan tour kalau user baru
      if (await TourService.shouldShow()) {
        if (mounted) _startTour();
      }
    });
  }

  void _startTour() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final isTablet = MediaQuery.of(context).size.width > 600;
      TourService.show(
        context:    context,
        keyBeranda: _keyBeranda,
        keyUsahaku: _keyUsahaku,
        keyKasir:   _keyKasir,
        keyRiwayat: _keyRiwayat,
        keyProfil:  _keyProfil,
        isSideNav:  isTablet,
      );
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
              keyBeranda: _keyBeranda,
              keyUsahaku: _keyUsahaku,
              keyKasir:   _keyKasir,
              keyRiwayat: _keyRiwayat,
              keyProfil:  _keyProfil,
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
        currentTab:  _currentTab,
        cartCount:   prov.cartItemCount,
        onTap:       (i) => _handleTabTap(i, context),
        keyBeranda:  _keyBeranda,
        keyUsahaku:  _keyUsahaku,
        keyKasir:    _keyKasir,
        keyRiwayat:  _keyRiwayat,
        keyProfil:   _keyProfil,
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTap;
  final GlobalKey keyBeranda;
  final GlobalKey keyUsahaku;
  final GlobalKey keyKasir;
  final GlobalKey keyRiwayat;
  final GlobalKey keyProfil;

  const _SideNav({
    required this.currentTab,
    required this.cartCount,
    required this.onTap,
    required this.keyBeranda,
    required this.keyUsahaku,
    required this.keyKasir,
    required this.keyRiwayat,
    required this.keyProfil,
  });

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
        NavigationRailDestination(
          icon: KeyedSubtree(key: keyBeranda, child: Opacity(opacity: 0.38, child: Image.asset('assets/icons/ic_home.png', width: 28, fit: BoxFit.contain))),
          selectedIcon: KeyedSubtree(key: keyBeranda, child: Image.asset('assets/icons/ic_home.png', width: 28, fit: BoxFit.contain)),
          label: const Text('Beranda'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(key: keyUsahaku, child: Opacity(opacity: 0.38, child: Image.asset('assets/icons/ic_store.png', width: 28, fit: BoxFit.contain))),
          selectedIcon: KeyedSubtree(key: keyUsahaku, child: Image.asset('assets/icons/ic_store.png', width: 28, fit: BoxFit.contain)),
          label: const Text('Usahaku'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(key: keyKasir, child: Stack(
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
                child: Center(child: Image.asset('assets/icons/ic_cart.png', width: 28, fit: BoxFit.contain)),
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
          )),
          label: const Text('Kasir'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(key: keyRiwayat, child: Opacity(opacity: 0.38, child: Image.asset('assets/icons/ic_riwayat.png', width: 28, fit: BoxFit.contain))),
          selectedIcon: KeyedSubtree(key: keyRiwayat, child: Image.asset('assets/icons/ic_riwayat.png', width: 28, fit: BoxFit.contain)),
          label: const Text('Riwayat'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(key: keyProfil, child: Opacity(opacity: 0.38, child: Image.asset('assets/icons/ic_profil.png', width: 28, fit: BoxFit.contain))),
          selectedIcon: KeyedSubtree(key: keyProfil, child: Image.asset('assets/icons/ic_profil.png', width: 28, fit: BoxFit.contain)),
          label: const Text('Profil'),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTap;
  final GlobalKey keyBeranda;
  final GlobalKey keyUsahaku;
  final GlobalKey keyKasir;
  final GlobalKey keyRiwayat;
  final GlobalKey keyProfil;

  const _BottomNav({
    required this.currentTab,
    required this.cartCount,
    required this.onTap,
    required this.keyBeranda,
    required this.keyUsahaku,
    required this.keyKasir,
    required this.keyRiwayat,
    required this.keyProfil,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(asset: 'assets/icons/ic_home.png',    label: 'Beranda', tourKey: keyBeranda),
      _NavItem(asset: 'assets/icons/ic_store.png',   label: 'Usahaku', tourKey: keyUsahaku),
      null, // center FAB slot
      _NavItem(asset: 'assets/icons/ic_riwayat.png', label: 'Riwayat', tourKey: keyRiwayat),
      _NavItem(asset: 'assets/icons/ic_profil.png',  label: 'Profil',  tourKey: keyProfil),
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
          height: 68,
          child: Row(
            children: List.generate(items.length, (i) {
              if (items[i] == null) {
                // Center Kasir FAB — icon 3D cart
                return Expanded(
                  child: GestureDetector(
                    key: keyKasir,
                    onTap: () => onTap(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Image.asset(
                              'assets/icons/ic_cart.png',
                              width: 54,
                              fit: BoxFit.contain,
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
                        const SizedBox(height: 2),
                        Text(
                          'Kasir',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                  key: item.tourKey,
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: isActive ? 1.0 : 0.38,
                        child: Image.asset(
                          item.asset,
                          width: 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 3),
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
  final String asset;
  final String label;
  final GlobalKey tourKey;
  const _NavItem({required this.asset, required this.label, required this.tourKey});
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
