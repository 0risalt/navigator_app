import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationScreen extends StatelessWidget {
  final String routeId;

  const NavigationScreen({super.key, required this.routeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink
                              .withValues(alpha: 0.3), // <-- Исправлено
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.turn_left,
                        size: 80, color: Color(0xFFD81B60)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Через 200 м',
                      style: TextStyle(fontSize: 24, color: Colors.black54)),
                  const Text('Поверните налево',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('на ул. Пионовую',
                      style: TextStyle(fontSize: 20, color: Colors.black87)),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF4081),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '60',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('км/ч',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('15 мин',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('4.2 км', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
