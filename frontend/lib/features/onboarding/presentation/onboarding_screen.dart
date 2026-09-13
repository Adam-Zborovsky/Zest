import 'package:flutter/material.dart';

/// Contract shell so routing can land before the screen does. The onboarding
/// track owns this file and replaces the body; the class name and the const
/// no-argument constructor are the contract.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Onboarding')),
  );
}
