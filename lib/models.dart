import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chave de data 'yyyy-MM-dd', usada nos resets diários e no histórico.
String dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Nomes curtos dos dias da semana, indexados por `weekday - 1`.
const kWeekdayLabels = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Períodos do dia, indexados por `Task.period`.
const kPeriodLabels = <String>['Manhã', 'Tarde', 'Noite'];

const kPeriodIcons = <IconData>[
  Icons.wb_twilight_outlined,
  Icons.wb_sunny_outlined,
  Icons.dark_mode_outlined,
];

/// Ícones disponíveis para as tarefas (guarda-se a chave no JSON).
const Map<String, IconData> kTaskIcons = {
  'home': Icons.home_outlined,
  'work': Icons.work_outline,
  'fitness': Icons.fitness_center,
  'study': Icons.school_outlined,
  'health': Icons.favorite_outline,
  'water': Icons.water_drop_outlined,
  'food': Icons.restaurant_outlined,
  'clean': Icons.cleaning_services_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'pet': Icons.pets_outlined,
  'money': Icons.savings_outlined,
  'car': Icons.directions_car_outlined,
};

IconData? taskIcon(String? key) => key == null ? null : kTaskIcons[key];

typedef NoteFontBuilder = TextStyle Function({
  TextStyle? textStyle,
  double? fontSize,
});

/// Fontes disponíveis nas notas. 'padrao' usa a fonte do tema (sem download).
final Map<String, ({String label, NoteFontBuilder? build})> kNoteFonts = {
  'padrao': (label: 'Padrão', build: null),
  'lato': (label: 'Lato', build: GoogleFonts.lato),
  'merriweather': (label: 'Merriweather', build: GoogleFonts.merriweather),
  'caveat': (label: 'Caveat', build: GoogleFonts.caveat),
  'roboto_mono': (label: 'Roboto Mono', build: GoogleFonts.robotoMono),
  'playfair_display': (label: 'Playfair Display', build: GoogleFonts.playfairDisplay),
};

/// Cores de destaque disponíveis nas definições (chave → cor).
const Map<String, Color> kSeedColors = {
  'indigo': Colors.indigo,
  'azul': Colors.blue,
  'teal': Colors.teal,
  'verde': Colors.green,
  'laranja': Colors.orange,
  'ambar': Colors.amber,
  'rosa': Colors.pink,
  'roxo': Colors.purple,
  'castanho': Colors.brown,
  'cinza': Colors.blueGrey,
};

/// Valor especial de `settings.seed` que ativa as cores dinâmicas (Material You).
const kDynamicSeed = 'dynamic';

/// Escalas de texto disponíveis (chave → fator).
const Map<String, double> kTextScales = {
  'small': 0.9,
  'normal': 1.0,
  'large': 1.15,
};

class Task {
  String id;
  String title;
  bool done;

  /// 0 = manhã, 1 = tarde, 2 = noite.
  int period;

  /// Chave em [kTaskIcons], ou null para não mostrar ícone.
  String? icon;

  /// Dia da semana de origem (1..7). Só se usa em tarefas arquivadas.
  int? day;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.period = 0,
    this.icon,
    this.day,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'period': period,
        'icon': icon,
        'day': day,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        period: ((json['period'] as num?)?.toInt() ?? 0).clamp(0, 2),
        icon: json['icon'] as String?,
        day: (json['day'] as num?)?.toInt(),
      );
}

class Note {
  String id;
  String title;
  String content;

  /// Chave em [kNoteFonts].
  String fontFamily;
  double fontSize;

  /// Última alteração, em milissegundos desde a época.
  int updatedAt;

  Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.fontFamily = 'padrao',
    this.fontSize = 16,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'updatedAt': updatedAt,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        fontFamily: json['fontFamily'] as String? ?? 'padrao',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Resultado diário guardado no histórico (base dos streaks e do heatmap).
class DayEntry {
  final int done;
  final int total;

  const DayEntry({required this.done, required this.total});

  /// Dia completo = pelo menos 80% das tarefas concluídas.
  bool get isComplete => total > 0 && done * 5 >= total * 4;

  double get ratio => total == 0 ? 0 : done / total;

  Map<String, dynamic> toJson() => {'done': done, 'total': total};

  factory DayEntry.fromJson(Map<String, dynamic> json) => DayEntry(
        done: (json['done'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

class AppData {
  static const int currentVersion = 2;

  int version;

  /// Tarefas por dia da semana: 1 = segunda ... 7 = domingo.
  final Map<int, List<Task>> days;

  /// Última data (yyyy-MM-dd) em que as tarefas de cada dia foram repostas.
  final Map<int, String> lastReset;

  /// Histórico diário, por data 'yyyy-MM-dd'.
  final Map<String, DayEntry> history;

  List<Task> archive;
  List<Note> notes;

  /// 'system' | 'light' | 'dark'
  String themeMode;

  /// Ordenação da lista de notas: 'recent' | 'title'
  String noteSort;

  /// Cor de destaque: chave em [kSeedColors] ou [kDynamicSeed].
  String seed;

  /// Escala de texto: chave em [kTextScales].
  String textScale;

  /// Fonte global da app: chave em [kNoteFonts].
  String appFont;

  AppData({
    this.version = currentVersion,
    Map<int, List<Task>>? days,
    Map<int, String>? lastReset,
    Map<String, DayEntry>? history,
    List<Task>? archive,
    List<Note>? notes,
    this.themeMode = 'system',
    this.noteSort = 'recent',
    this.seed = 'indigo',
    this.textScale = 'normal',
    this.appFont = 'padrao',
  })  : days = days ?? {for (var i = 1; i <= 7; i++) i: <Task>[]},
        lastReset = lastReset ?? {},
        history = history ?? {},
        archive = archive ?? [],
        notes = notes ?? [];

  List<Task> tasksFor(int weekday) =>
      days.putIfAbsent(weekday, () => <Task>[]);

  /// Regista no histórico o estado atual do dia indicado.
  /// Só faz sentido para o dia de hoje.
  void recordDay(int weekday) {
    final now = DateTime.now();
    final tasks = tasksFor(weekday);
    history[dateKey(now)] = DayEntry(
      done: tasks.where((t) => t.done).length,
      total: tasks.length,
    );
  }

  ThemeMode get theme => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final data = AppData(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
    );

    final days = json['days'];
    if (days is Map<String, dynamic>) {
      days.forEach((key, value) {
        final weekday = int.tryParse(key);
        if (weekday == null || weekday < 1 || weekday > 7) return;
        if (value is! List<dynamic>) return;
        data.days[weekday] = value
            .whereType<Map<String, dynamic>>()
            .map(Task.fromJson)
            .toList();
      });
    }

    final lastReset = json['lastReset'];
    if (lastReset is Map<String, dynamic>) {
      lastReset.forEach((key, value) {
        final weekday = int.tryParse(key);
        if (weekday != null && weekday >= 1 && weekday <= 7 && value is String) {
          data.lastReset[weekday] = value;
        }
      });
    }

    final history = json['history'];
    if (history is Map<String, dynamic>) {
      history.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          data.history[key] = DayEntry.fromJson(value);
        }
      });
    }

    if (json['archive'] is List<dynamic>) {
      data.archive = (json['archive'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Task.fromJson)
          .toList();
    }

    if (json['notes'] is List<dynamic>) {
      data.notes = (json['notes'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();
    }

    final settings = json['settings'];
    if (settings is Map<String, dynamic>) {
      if (settings['themeMode'] is String) {
        data.themeMode = settings['themeMode'] as String;
      }
      if (settings['noteSort'] is String) {
        data.noteSort = settings['noteSort'] as String;
      }
      if (settings['seed'] is String) {
        data.seed = settings['seed'] as String;
      }
      if (settings['textScale'] is String) {
        data.textScale = settings['textScale'] as String;
      }
      if (settings['appFont'] is String) {
        data.appFont = settings['appFont'] as String;
      }
    }

    return data;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'days': {
          for (final e in days.entries)
            e.key.toString(): e.value.map((t) => t.toJson()).toList(),
        },
        'lastReset': {
          for (final e in lastReset.entries) e.key.toString(): e.value,
        },
        'history': {
          for (final e in history.entries) e.key: e.value.toJson(),
        },
        'archive': archive.map((t) => t.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'settings': {
          'themeMode': themeMode,
          'noteSort': noteSort,
          'seed': seed,
          'textScale': textScale,
          'appFont': appFont,
        },
      };

  /// Reconstrói os dados a partir de um backup exportado.
  /// Devolve null se o JSON não tiver o formato esperado.
  static AppData? tryParseBackup(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['days'] is! Map<String, dynamic>) return null;
      return AppData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
