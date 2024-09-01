import 'package:flutter/material.dart';

Icon getDefaultIconWidget(BuildContext context, IconData iconToSet) {
  return Icon(iconToSet, color: Theme.of(context).colorScheme.inversePrimary, size: 24.0);
}