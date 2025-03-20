import 'package:flutter/material.dart';

Icon getDefaultIconWidget(BuildContext context, IconData iconToSet) {
  return Icon(iconToSet, color: Theme.of(context).colorScheme.inversePrimary, size: 24.0);
}

Icon getColoredIconWidget(BuildContext context, Color color, IconData iconToSet) {
  return Icon(iconToSet, color: color, size: 24.0);
}