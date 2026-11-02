import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/auth_state.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthState();
  runApp(
      ChangeNotifierProvider.value(value: auth, child: EggFarmApp(auth: auth)));
  unawaited(auth.init());
}

class EggFarmApp extends StatefulWidget {
  final AuthState auth;
  const EggFarmApp({super.key, required this.auth});
  @override
  State<EggFarmApp> createState() => _EggFarmAppState();
}

class _EggFarmAppState extends State<EggFarmApp> {
  late final GoRouter _router = buildRouter(widget.auth);
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Egg Farm Management',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      );
}
