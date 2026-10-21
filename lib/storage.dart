import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AppStorage {
  static const _dataKey = 'app_data';
  static const _legacyTasksKey = 'tasks';
  static const _legacyLastResetKey = 'last_reset';

  static const _uuid = Uuid();

  /// Carrega os dados, aplica a migração v1→v2 (se necessário) e o reset
  /// diário, e mantém o histórico de hoje atualizado.
  Future<AppData> loadAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dataKey);

    AppData data;
    if (raw != null) {
      try {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        data = _migrateLegacy(prefs);
        await _write(prefs, data);
      }
    } else {
      data = _migrateLegacy(prefs);
      await _write(prefs, data);
    }

    _applyDailyReset(data);
    _recordToday(data);
    await _write(prefs, data);
    return data;
  }

  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, data);
  }

  /// Converte os dados da v1 (chaves 'tasks' e 'last_reset') para o novo
  /// formato: as tarefas passam para o dia da semana atual.
  AppData _migrateLegacy(SharedPreferences prefs) {
    final data = AppData();
    final raw = prefs.getString(_legacyTasksKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final weekday = DateTime.now().weekday;
        data.days[weekday] = decoded
            .whereType<Map<String, dynamic>>()
            .map(Task.fromJson)
            .toList();
        for (final task in data.days[weekday]!) {
          if (task.id.isEmpty) task.id = _uuid.v4();
        }
      } catch (_) {
        // Dados legados corrompidos: recomeçar do zero.
      }
    }

    // Na v1, se o último reset não foi hoje, as tarefas estão desmarcadas.
    final legacyReset = prefs.getString(_legacyLastResetKey);
    if (legacyReset != null && legacyReset != dateKey(DateTime.now())) {
      for (final task in data.tasksFor(DateTime.now().weekday)) {
        task.done = false;
      }
    }

    prefs.remove(_legacyTasksKey);
    prefs.remove(_legacyLastResetKey);
    return data;
  }

  /// No novo dia da semana, as tarefas desse dia voltam a ficar desmarcadas.
  void _applyDailyReset(AppData data) {
    final now = DateTime.now();
    final today = dateKey(now);
    if (data.lastReset[now.weekday] == today) return;
    for (final task in data.tasksFor(now.weekday)) {
      task.done = false;
    }
    data.lastReset[now.weekday] = today;
  }

  /// Mantém o histórico de hoje atualizado (base dos streaks).
  void _recordToday(AppData data) {
    final now = DateTime.now();
    final tasks = data.tasksFor(now.weekday);
    if (tasks.isEmpty) return;
    data.history[dateKey(now)] = DayEntry(
      done: tasks.where((t) => t.done).length,
      total: tasks.length,
    );
  }

  Future<void> _write(SharedPreferences prefs, AppData data) {
    return prefs.setString(_dataKey, jsonEncode(data.toJson()));
  }

  /// JSON de backup com tudo: rotina, histórico, notas, arquivo e tema.
  String exportJson(AppData data) =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  /// Reconstrói os dados a partir de um backup; null se for inválido.
  AppData? importJson(String raw) => AppData.tryParseBackup(raw);

  String newId() => _uuid.v4();
}

DateTime _noon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

bool _isComplete(DayEntry? entry) => entry != null && entry.isComplete;

/// Streak diário: dias consecutivos com pelo menos 80% das tarefas
/// concluídas. Hoje conta se já estiver completo; dias sem registo não
/// quebram o streak.
int dailyStreak(Map<String, DayEntry> history) {
  var streak = 0;
  var cursor = _noon(DateTime.now());

  if (_isComplete(history[dateKey(cursor)])) streak++;
  cursor = cursor.subtract(const Duration(days: 1));

  for (var i = 0; i < 1100; i++) {
    final entry = history[dateKey(cursor)];
    if (entry != null && entry.total > 0) {
      if (!entry.isComplete) break;
      streak++;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Streak semanal: semanas (segunda a domingo) consecutivas, terminando na
/// semana anterior à atual, em que todos os dias com tarefas ficaram com
/// pelo menos 80% concluído. A semana atual, ainda em curso, não conta.
int weeklyStreak(Map<String, DayEntry> history) {
  final today = _noon(DateTime.now());
  var weekStart = today.subtract(Duration(days: today.weekday - 1 + 7));
  var streak = 0;

  for (var week = 0; week < 520; week++) {
    var hasTasks = false;
    for (var d = 0; d < 7; d++) {
      final entry = history[dateKey(weekStart.add(Duration(days: d)))];
      if (entry == null || entry.total == 0) continue;
      hasTasks = true;
      if (!entry.isComplete) return streak;
    }
    if (!hasTasks) break;
    streak++;
    weekStart = weekStart.subtract(const Duration(days: 7));
  }
  return streak;
}
