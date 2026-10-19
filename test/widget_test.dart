import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_note/main.dart';

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Future<void> _addTaskViaPopup(WidgetTester tester, String title) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
  });

  testWidgets('Botão de reset desmarca todas as tarefas na hora',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    await _addTaskViaPopup(tester, 'Tarefa 1');
    await _addTaskViaPopup(tester, 'Tarefa 2');

    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox).first, checked(true));

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), everyCheckbox(false));

    final prefs = await SharedPreferences.getInstance();
    final tasks =
        (jsonDecode(prefs.getString('tasks')!) as List<dynamic>).cast<Map>();
    expect(tasks.every((t) => t['done'] == false), isTrue);
  });

  testWidgets('Reseta tarefas desmarcando-as num novo dia',
      (WidgetTester tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'tasks': jsonEncode([
        {'id': '1', 'title': 'Tarefa antiga', 'done': true},
      ]),
      'last_reset': _dateKey(yesterday),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), everyCheckbox(false));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_reset'), _dateKey(DateTime.now()));
  });

  testWidgets('Não reseta as tarefas no mesmo dia',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'tasks': jsonEncode([
        {'id': '1', 'title': 'Tarefa de hoje', 'done': true},
      ]),
      'last_reset': _dateKey(DateTime.now()),
    });

    await tester.pumpWidget(const TaskNoteApp());
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), everyCheckbox(true));
  });
}
