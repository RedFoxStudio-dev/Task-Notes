import 'package:flutter/material.dart';

/// Tema da app, claro e escuro, a partir da mesma cor semente.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
  );
}
