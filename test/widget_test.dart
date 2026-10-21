import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_note/main.dart';
import 'package:task_note/models.dart';

Task _task(String title, {bool done = false}) =>
    Task(id: 'id-$title', title: title, done: done);

AppData _seedData({
  Map<int, List<Task>>? days,
  Map<int, String>? lastReset,
}) {
  final data = AppData();
  days?.forEach((weekday, tasks) => data.days[weekday] = tasks);
  lastReset?.forEach((weekday, date) => data.lastReset[weekday] = date);
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
}
