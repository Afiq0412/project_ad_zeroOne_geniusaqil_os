import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/leave_management/providers/leave_provider.dart';
import 'modules/manage_users/providers/manage_users_provider.dart';
import 'modules/task_duty_manager/providers/duty_provider.dart';
import 'modules/auth/views/login_view.dart';
import 'modules/home/views/home_view.dart';
import 'modules/teacher_training_tracker/providers/training_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed. Please make sure you have run 'flutterfire configure'. Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => ManageUsersProvider()),
        ChangeNotifierProvider(create: (_) => DutyProvider()),
        ChangeNotifierProvider(create: (_) => TrainingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GENIUSAQILOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (authProvider.isAuthenticated) {
            return const HomeView();
          } else {
            return const LoginView();
          }
        },
      ),
    );
  }
}
