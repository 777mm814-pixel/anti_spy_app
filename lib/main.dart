import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intruder Shield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isPowerOn = false;
  double _opacity = 0.85;
  double _sensitivity = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Shield'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _isPowerOn = !_isPowerOn),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPowerOn ? Colors.green : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPowerOn ? Colors.green : Colors.redAccent).withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isPowerOn ? Icons.shield : Icons.shield_outlined,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text('Overlay Opacity: ${(_opacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _opacity,
            min: 0.2,
            max: 1.0,
            onChanged: (v) => setState(() => _opacity = v),
          ),
          const SizedBox(height: 20),
          Text('Sensor Sensitivity: ${(_sensitivity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _sensitivity,
            min: 0.1,
            max: 1.0,
            onChanged: (v) => setState(() => _sensitivity = v),
          ),
        ],
      ),
    );
  }
}
