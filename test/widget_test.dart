import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_note/main.dart';
import 'package:task_note/models.dart';
import 'package:task_note/storage.dart';

Task _task(String title, {bool done = false}) =>
    Task(id: 'id-$title', title: title, done: done);

AppData _seedData({
  Map<int, List<Task>>? days,
  Map<int, String>? lastReset,
  Map<String, DayEntry>? history,
}) {
  final data = AppData();
  days?.forEach((weekday, tasks) => data.days[weekday] = tasks);
  lastReset?.forEach((weekday, date) => data.lastReset[weekday] = date);
  history?.forEach((date, entry) => data.history[date] = entry);
  return data;
}

Map<String, dynamic> _stored(SharedPreferences prefs) =>
    jsonDecode(prefs.getString('app_data')!) as Map<String, dynamic>;

Future<void> _addTaskViaPopup(WidgetTester tester, String title) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
}

bool _checkboxValue(WidgetTester tester, int index) =>
    tester.widget<Checkbox>(find.byType(Checkbox).at(index)).value!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Migra os dados da v1 e desmarca as tarefas num novo dia',
      (WidgetTester tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'tasks': jsonEncode([
        {'id': '1', 'title': 'Tarefa antiga', 'done': true},
      ]),
      'last_reset': dateKey(yesterday),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Tarefa antiga'), findsOneWidget);
    expect(_checkboxValue(tester, 0), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tasks'), isNull);
    expect(prefs.getString('last_reset'), isNull);
    expect(prefs.getString('app_data'), isNotNull);
  });

  testWidgets('Mostra estado vazio quando não há tarefas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Task Notes'), findsOneWidget);
    expect(find.text('Sem tarefas'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Adiciona uma tarefa através do pop-up',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Beber 2L de água');

    expect(find.text('Beber 2L de água'), findsOneWidget);
    expect(find.text('Sem tarefas'), findsNothing);
  });

  testWidgets('Tarefa aparece riscada ao marcar como feita',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa teste');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Tarefa teste'));
    expect(text.style?.decoration, TextDecoration.lineThrough);

    // O histórico de hoje fica atualizado (base dos streaks).
    final prefs = await SharedPreferences.getInstance();
    final history =
        (_stored(prefs)['history'] as Map<String, dynamic>)[dateKey(DateTime.now())]
            as Map<String, dynamic>?;
    expect(history, isNotNull);
    expect(history!['done'], 1);
    expect(history['total'], 1);
  });

  testWidgets('Botão alternar: com algumas marcadas, ativa todas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa 1');
    await _addTaskViaPopup(tester, 'Tarefa 2');

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(_checkboxValue(tester, 0), isTrue);
    expect(_checkboxValue(tester, 1), isFalse);

    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pumpAndSettle();

    expect(_checkboxValue(tester, 0), isTrue);
    expect(_checkboxValue(tester, 1), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final today = (_stored(prefs)['days'] as Map<String, dynamic>)
        [DateTime.now().weekday.toString()] as List<dynamic>;
    expect(today.every((t) => (t as Map<String, dynamic>)['done'] == true),
        isTrue);
  });

  testWidgets('Botão alternar: com todas marcadas, desativa todas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa 1');
    await _addTaskViaPopup(tester, 'Tarefa 2');

    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pumpAndSettle();

    expect(_checkboxValue(tester, 0), isFalse);
    expect(_checkboxValue(tester, 1), isFalse);
  });

  testWidgets('Eliminar tudo pede confirmação e apaga as tarefas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa 1');
    await _addTaskViaPopup(tester, 'Tarefa 2');

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar Tudo'), findsOneWidget);
    expect(find.text('Queres eliminar todas as tarefas?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa 1'), findsOneWidget);
    expect(find.text('Tarefa 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Sem tarefas'), findsOneWidget);
    expect(find.text('Tarefa 1'), findsNothing);
    expect(find.text('Tarefa 2'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final today = (_stored(prefs)['days'] as Map<String, dynamic>)
        [DateTime.now().weekday.toString()] as List<dynamic>;
    expect(today, isEmpty);
  });

  testWidgets('Organiza as tarefas por manhã, tarde e noite',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tomar café');

    // Segunda tarefa no período da tarde.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Estudar');
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Tarde'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Manhã'), findsOneWidget);
    expect(find.text('Tarde'), findsOneWidget);
    expect(find.text('Noite'), findsNothing);
    expect(find.text('Tomar café'), findsOneWidget);
    expect(find.text('Estudar'), findsOneWidget);
  });

  testWidgets('Tarefa pode ter um ícone', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ir ao ginásio');
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.fitness_center),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Ir ao ginásio'), findsOneWidget);
    // O ícone aparece apenas no cartão da tarefa (o pop-up já fechou).
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });

  testWidgets('Mostra o progresso do dia', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa 1');
    await _addTaskViaPopup(tester, 'Tarefa 2');

    expect(find.text('0 de 2 concluídas'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('1 de 2 concluídas'), findsOneWidget);
  });

  testWidgets('Copia as tarefas de outro dia (adicionar)',
      (WidgetTester tester) async {
    final today = DateTime.now();
    final source = today.weekday % 7 + 1;
    SharedPreferences.setMockInitialValues({
      'app_data': jsonEncode(_seedData(
        days: {
          source: [_task('Tarefa importada')],
        },
      ).toJson()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copiar de outro dia'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(kWeekdayLabels[source - 1]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Copiar'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tarefa importada'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final todayTasks = (_stored(prefs)['days'] as Map<String, dynamic>)
        [today.weekday.toString()] as List<dynamic>;
    expect(todayTasks, hasLength(1));
    expect((todayTasks.first as Map<String, dynamic>)['title'],
        'Tarefa importada');
  });

  testWidgets('Copia as tarefas de outro dia (substituir)',
      (WidgetTester tester) async {
    final today = DateTime.now();
    final source = today.weekday % 7 + 1;
    SharedPreferences.setMockInitialValues({
      'app_data': jsonEncode(_seedData(
        days: {
          today.weekday: [_task('Tarefa atual')],
          source: [_task('Importada 1'), _task('Importada 2')],
        },
      ).toJson()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copiar de outro dia'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(kWeekdayLabels[source - 1]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Substituir as existentes'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Copiar'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Importada 1'), findsOneWidget);
    expect(find.text('Importada 2'), findsOneWidget);
    expect(find.text('Tarefa atual'), findsNothing);
  });

  testWidgets('Separador de estatísticas mostra streaks e o dia de hoje',
      (WidgetTester tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'app_data': jsonEncode(_seedData(
        days: {
          today.weekday: [
            _task('Tarefa de hoje', done: true),
            _task('Outra tarefa', done: true),
          ],
        },
        lastReset: {today.weekday: dateKey(today)},
      ).toJson()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Estatísticas'),
    ));
    await tester.pumpAndSettle();

    // Streak diário: hoje ficou completo → 1 dia seguido.
    expect(find.text('dia seguido'), findsOneWidget);
    expect(find.text('semanas completas'), findsOneWidget);
    expect(find.text('2 de 2 concluídas'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('Reseta as tarefas do dia num novo dia da semana',
      (WidgetTester tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'app_data': jsonEncode(_seedData(
        days: {today.weekday: [_task('Tarefa de hoje', done: true)]},
        lastReset: {
          today.weekday: dateKey(today.subtract(const Duration(days: 7))),
        },
      ).toJson()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Tarefa de hoje'), findsOneWidget);
    expect(_checkboxValue(tester, 0), isFalse);

    final prefs = await SharedPreferences.getInstance();
    final lastReset = _stored(prefs)['lastReset'] as Map<String, dynamic>;
    expect(lastReset[today.weekday.toString()], dateKey(today));
  });

  testWidgets('Não reseta as tarefas no mesmo dia',
      (WidgetTester tester) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'app_data': jsonEncode(_seedData(
        days: {today.weekday: [_task('Tarefa de hoje', done: true)]},
        lastReset: {today.weekday: dateKey(today)},
      ).toJson()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(_checkboxValue(tester, 0), isTrue);
  });

  group('streaks', () {
    String k(int daysAgo) =>
        dateKey(DateTime.now().subtract(Duration(days: daysAgo)));

    test('80% é o limiar de dia completo', () {
      expect(dailyStreak({k(0): const DayEntry(done: 8, total: 10)}), 1);
      expect(dailyStreak({k(0): const DayEntry(done: 7, total: 10)}), 0);
    });

    test('streak diário conta dias consecutivos e salta dias sem registo',
        () {
      expect(dailyStreak({
        k(0): const DayEntry(done: 4, total: 4),
        k(2): const DayEntry(done: 5, total: 5),
      }), 2);
    });

    test('dia com tarefas incompletas quebra o streak', () {
      expect(dailyStreak({
        k(0): const DayEntry(done: 4, total: 4),
        k(1): const DayEntry(done: 1, total: 5),
        k(2): const DayEntry(done: 5, total: 5),
      }), 1);
    });

    test('hoje incompleto não quebra o streak anterior', () {
      expect(dailyStreak({
        k(0): const DayEntry(done: 0, total: 4),
        k(1): const DayEntry(done: 5, total: 5),
        k(2): const DayEntry(done: 5, total: 5),
      }), 2);
    });

    test('streak semanal conta semanas completas consecutivas', () {
      final today = DateTime.now();
      final lastMonday =
          today.subtract(Duration(days: today.weekday - 1 + 7));
      final history = <String, DayEntry>{
        for (var d = 0; d < 5; d++)
          dateKey(lastMonday.add(Duration(days: d))):
              const DayEntry(done: 5, total: 5),
      };
      expect(weeklyStreak(history), 1);

      // Há duas semanas, um dia incompleto interrompe a contagem.
      final twoWeeksAgo = lastMonday.subtract(const Duration(days: 7));
      history[dateKey(twoWeeksAgo.add(const Duration(days: 2)))] =
          const DayEntry(done: 3, total: 10);
      expect(weeklyStreak(history), 1);
    });

    test('streak semanal é zero sem histórico', () {
      expect(weeklyStreak(const {}), 0);
    });
  });
}
