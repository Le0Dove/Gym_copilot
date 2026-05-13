import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await NotificationService.instance.init();
    UpdateService.instance.checkAndUpdateOnStartup();
  }

  runApp(const GymCopilotProApp());
}

class GymCopilotProApp extends StatelessWidget {
  const GymCopilotProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Copilot Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      navigatorObservers: [routeObserver],
      home: const MainNavigationScreen(),
      // 全局页面转场动画
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) {
            final Widget page;
            switch (settings.name) {
              case '/':
                page = const MainNavigationScreen();
                break;
              default:
                page = const MainNavigationScreen();
            }
            return page;
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = Color(0xFFF97316);
    const onPrimary = Color(0xFF0F172A);
    const secondary = Color(0xFFFB923C);
    const background = Color(0xFF0B0F19);
    const surface = Color(0xFF1A1F2E);
    const surfaceVariant = Color(0xFF242B3D);
    const foreground = Color(0xFFF8FAFC);
    const muted = Color(0xFF64748B);
    const border = Color(0xFF2D3748);
    const error = Color(0xFFEF4444);

    final baseTextTheme = ThemeData.dark().textTheme;
    final displayTextTheme = ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: foreground,
        surface: surface,
        onSurface: foreground,
        surfaceContainerHighest: surfaceVariant,
        onSurfaceVariant: muted,
        outline: border,
        error: error,
      ),
      textTheme: TextTheme(
        displayLarge: displayTextTheme.displayLarge?.copyWith(
          fontSize: 64,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: -2,
          height: 1.0,
        ),
        displayMedium: displayTextTheme.displayMedium?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displaySmall: displayTextTheme.displaySmall?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: -1,
          height: 1.1,
        ),
        headlineLarge: displayTextTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: displayTextTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        headlineSmall: displayTextTheme.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 0,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 0.1,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: muted,
          letterSpacing: 0.2,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: foreground,
          letterSpacing: 0.2,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: foreground,
          letterSpacing: 0.25,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
          letterSpacing: 0.4,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.5,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.5,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(76),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: foreground),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
        highlightElevation: 8,
        splashColor: primary.withAlpha(51),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: primary.withAlpha(102),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          fontSize: 16,
          color: muted,
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: _homeKey),
          const ExerciseLibraryScreen(),
          const StatsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2D3748), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 0) {
              _homeKey.currentState?.loadData();
            }
          },
          backgroundColor: const Color(0xFF0B0F19),
          indicatorColor: const Color(0xFFF97316).withAlpha(38),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 24),
              selectedIcon: Icon(Icons.home, size: 24),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined, size: 24),
              selectedIcon: Icon(Icons.fitness_center, size: 24),
              label: '动作库',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, size: 24),
              selectedIcon: Icon(Icons.bar_chart, size: 24),
              label: '统计',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, size: 24),
              selectedIcon: Icon(Icons.person, size: 24),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
