import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'modules/teacher_training_tracker/views/training_dashboard_view.dart';
import 'firebase_options.dart';

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
      ),
      // Mock Context Authentication: Replace with your dynamic account management variables
      home: TrainingDashboardView(
        teacherId: 'TC-09-SKUDAI', // Assigned teacher account sequence template
        userRole: 'Teacher', // Toggle to 'Admin' to simulate the Principal view context
      ), 
    );
  }
}