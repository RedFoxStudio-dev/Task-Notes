# Task-Notes

App de rotina semanal, tarefas e notas pessoais, feito em Flutter.

## Funcionalidades

### Rotina semanal
- Um conjunto de tarefas por dia da semana (segunda a domingo), com o dia atual selecionado por defeito
- Ao chegar um novo dia, as tarefas desse dia voltam a ficar desmarcadas
- Tarefas organizadas por período: manhã, tarde e noite
- Ícone opcional por tarefa
- Barra de progresso do dia ("3 de 8 concluídas")
- Copiar as tarefas de um dia para outro (adicionar ou substituir)
- Reordenar tarefas com toque longo
- Arquivar tarefas (restaurar ou eliminar definitivamente nas definições)

### Notas
- Bloco de notas com notas separadas (título + conteúdo)
- Tipo e tamanho de letra por nota, com guarda automática

### Estatísticas
- Streak diário: dias seguidos com pelo menos 80% das tarefas concluídas
- Streak semanal: semanas completas consecutivas
- Heatmap das últimas 12 semanas

### Geral
- Tema claro, escuro ou do sistema
- **Personalização** nas definições (secção "Aspeto"):
  - Cor de destaque: paleta de 10 cores + opção **Dinâmica (Material You)** (Android 12+), com pré-visualização em tempo real
  - Tamanho do texto: pequeno, normal ou grande
  - Fonte da app: padrão, Lato, Merriweather, Playfair Display, Roboto Mono ou Caveat
- Backup completo: exportar (partilhar ou copiar JSON) e importar
- Dados guardados localmente (SharedPreferences), com migração automática dos dados da v1

## Estrutura

```
lib/
  main.dart            — app, tema e navegação (Rotina · Estatísticas · Notas)
  models.dart          — Task, Note, AppData (JSON + migração v1→v2)
  storage.dart         — persistência, reset diário, streaks, backup
  theme.dart           — tema claro/escuro
  pages/routine.dart   — rotina semanal
  pages/notes.dart     — bloco de notas
  pages/stats.dart     — streaks e heatmap
  pages/settings.dart  — aparência, arquivo e backup
  popups.dart          — pop-ups (tarefas, copiar dia, importar, confirmações)
test/
  widget_test.dart     — testes de widget e unitários
```

## Packages

- `shared_preferences` — persistência local
- `google_fonts` — tipos de letra das notas e da app
- `share_plus` — partilha do backup
- `uuid` — identificadores de tarefas/notas
- `dynamic_color` — cores dinâmicas do Android (Material You)

## Comandos

```bash
flutter run
flutter test
flutter analyze
```



menu lateral
categorias (para agrupar notas)
