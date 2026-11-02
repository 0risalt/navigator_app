import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ВСТАВЬТЕ СЮДА ВАШИ ДАННЫЕ ИЗ SUPABASE
  await Supabase.initialize(
    url: 'https://iqsetzkvefsccbrtkksp.supabase.co',
    publishableKey: 'sb_publishable_pzZ8IGRvTpQ9eLLGiirNfg_1Qq2BvPG',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PickMe Navigator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4081),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF2F5),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4081),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}