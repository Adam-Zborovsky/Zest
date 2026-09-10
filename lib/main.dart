import 'package:flutter/material.dart';

void main() {
  runApp(const ZestApp());
}

class ZestApp extends StatelessWidget {
  const ZestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffec8a2d)),
        useMaterial3: true,
      ),
      home: const ZestHomePage(),
    );
  }
}

class ZestHomePage extends StatelessWidget {
  const ZestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zest', style: theme.textTheme.displayMedium),
                const SizedBox(height: 12),
                Text(
                  'A cocktail companion, beginning with a bright foundation.',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
