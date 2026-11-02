import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/navigation_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'navigate/:id',
          builder: (context, state) =>
              NavigationScreen(routeId: state.pathParameters['id'] ?? '1'),
        ),
      ],
    ),
  ],
);
