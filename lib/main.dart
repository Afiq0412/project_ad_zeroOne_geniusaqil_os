import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
<<<<<<< HEAD
import 'modules/teacher_training_tracker/views/training_dashboard_view.dart';
import 'firebase_options.dart';
=======
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/leave_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
>>>>>>> parent of bf6b2ba (refactor: restructure project into modular directories (auth, leave_management, home) and setup unified app theme)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure your firebase options parameters are properly linked here
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GeniusAqilOS());
}

class GeniusAqilOS extends StatelessWidget {
  const GeniusAqilOS({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeniusAqilOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
<<<<<<< HEAD
        useMaterial3: true,
        // A warm, playful orange/peach tone for the app
        colorSchemeSeed: Colors.orangeAccent, 
        scaffoldBackgroundColor: Colors.orange.shade50,
        appBarTheme: AppBarThemeData(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.orange.shade900,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.orange.shade900),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Bubbly, friendly corners
          ),
        ),
=======
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5480),
          primary: const Color(0xFF1E5480),
          secondary: const Color(0xFFED7E24),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
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
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
>>>>>>> parent of bf6b2ba (refactor: restructure project into modular directories (auth, leave_management, home) and setup unified app theme)
      ),
      // Mock Context Authentication: Replace with your dynamic account management variables
      home: TrainingDashboardView(
        teacherId: 'TC-09-SKUDAI', // Assigned teacher account sequence template
        userRole: 'Teacher', // Toggle to 'Admin' to simulate the Principal view context
      ), 
    );
  }
}