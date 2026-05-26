import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Basic Flutter Tutorial',
      theme: ThemeData(primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color.fromARGB(255, 201, 230, 255)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int counter = 0;

  void incrementCounter() {
    setState(() {
      counter++;
    });
  }

  void decrementCounter() {
    setState(() {
      if (counter > 0) {
        counter--;
      }
    });
  }

  void resetCounter() {
    setState(() {
      counter = 0;
    });
  }

  String getMessage() {
    if (counter == 0) {
      return 'Counter is empty';
    } else if (counter < 5) {
      return 'Keep going';
    } else {
      return 'Great job';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My First Flutter App - testing')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 60),
              const Text('Counter Value', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              Text(
                '$counter',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(getMessage(), style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: incrementCounter,
                    child: const Text('Add 1'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: decrementCounter,
                    child: const Text('Minus 1'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: resetCounter,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
