import 'package:flutter/material.dart';

/// Contract shell so routing can land before the screen does. The login track
/// owns this file and replaces the body; the class name and the const
/// no-argument constructor are the contract.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Login')),
  );
}
