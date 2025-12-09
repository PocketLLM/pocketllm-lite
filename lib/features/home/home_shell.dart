import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// We need to define the shell logic properly to work with GoRouter
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Determine the current index based on the route.
    // This requires access to the current route match.
    // Since this is a child of ShellRoute, 'child' is the screen.
    // We need to wrap 'child' in a Scaffold with BottomNavBar.

    // To get the current index, we can look at the path.
    // But GoRouter doesn't easily expose "current path" inside the builder without context magic.
    // A common pattern is using a stateful shell route, but we used ShellRoute.

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int idx) => _onItemTapped(idx, context),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/history');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }
}
