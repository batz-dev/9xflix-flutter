import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'providers/movies_provider.dart';
import 'services/download_manager.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark navigation & status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize download manager & persistence
  final downloadManager = DownloadManager();
  await downloadManager.init();

  runApp(const FlixDirectApp());
}

class FlixDirectApp extends StatelessWidget {
  const FlixDirectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MoviesProvider()..init(),
        ),
        ChangeNotifierProvider.value(
          value: DownloadManager(),
        ),
      ],
      child: MaterialApp(
        title: 'FlixDirect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
