import 'package:flutter/material.dart';
import 'models/artwork.dart';
import 'screens/home_screen.dart';
import 'state/huepop_app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HuePopApp());
}

class HuePopApp extends StatefulWidget {
  const HuePopApp({super.key});

  @override
  State<HuePopApp> createState() => _HuePopAppState();
}

class _HuePopAppState extends State<HuePopApp> {
  final HuePopAppState appState = HuePopAppState();

  @override
  void initState() {
    super.initState();
    appState.initialize();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HuePop',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: huePopPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6FC),
        cardTheme: const CardThemeData(elevation: 0, clipBehavior: Clip.antiAlias),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        ),
      ),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (!appState.initialized) {
            return const _Splash();
          }
          return HomeScreen(appState: appState);
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand-image.png', width: 300, fit: BoxFit.contain),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
