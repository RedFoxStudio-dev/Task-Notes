import 'package:flutter/material.dart';

import 'models.dart';

/// Tema da app, claro e escuro, parametrizado pela cor de destaque e pela
/// fonte escolhida nas definições.
///
/// [fontKey] é uma chave de [kNoteFonts] ('padrao' usa a fonte do sistema).
/// [dynamicScheme], quando presente (Material You), substitui o esquema
/// gerado a partir da cor semente.
ThemeData buildAppTheme(
  Brightness brightness, {
  Color seedColor = Colors.indigo,
  String fontKey = 'padrao',
  ColorScheme? dynamicScheme,
}) {
  final scheme = dynamicScheme ??
      ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final font = kNoteFonts[fontKey]?.build;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: font != null ? font().fontFamily : null,
  );
}
