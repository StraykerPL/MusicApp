import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(child: Text('Unexpected application error: $error')),
    );
  }
}
