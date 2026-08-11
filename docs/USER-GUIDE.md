# Local Coding Agent — руководство пользователя

Local Coding Agent — локальный coding assistant для Windows, Continue CLI, Ollama и IntelliJ IDEA. Управляемый режим исследует один выбранный проект, изменяет файлы только в его границах, запускает проверки и завершает работу структурированным результатом.

## Первый запуск

Требуются Git for Windows, Node.js 20+, Continue CLI и доступный Ollama.

```powershell
Set-Location "C:\AI\local-coding-agent"
.\SETUP.ps1
. .\ACTIVATE.ps1
agent-doctor -Deep
```

Если Continue требует первичную авторизацию:

```powershell
.\SETUP.ps1 -LoginContinue
```

После установки откройте новое окно PowerShell либо выполните `. .\ACTIVATE.ps1`.

## Подготовка проекта

Один раз создайте проверенные project rules:

```powershell
agent-init -Project "C:\Projects\my-project"
```

Команда определяет стек, manifests, module roots и доступные build/test scripts и создаёт `.continue\rules\00-project.md`. Просмотрите оставшиеся `TODO` и заполните только подтверждённые факты: границы модулей, правила миграций, совместимость API и обязательные release checks.

Перед работой рекомендуется отдельная Git-ветка и понятный `git status`. Агент не выполняет commit или push в управляемом режиме.

## Ежедневная работа

```powershell
agent -Project "C:\Projects\my-project"
```

Можно писать задачу обычным текстом:

```text
Исправь потерю refresh token при повторном входе, добавь regression test и проверь модуль auth.
```

Для явного управления используйте:

- `/analysis <вопрос>` — исследование без изменений;
- `/feature <задача>` — реализация функции;
- `/bugfix <дефект>` — поиск причины, минимальное исправление и regression test;
- `/deliver <задача + путь к спецификации>` — полный цикл реализации и проверки;
- `/test` — тестовая работа;
- `/review` — независимая проверка текущего diff;
- `/result` — восстановить достоверный итог предыдущего запуска;
- `/status` — проект, модель, permissions и последний результат;
- `/continue` — продолжить незавершённый workflow с текущего состояния.
- `/continue <ответ>` — передать уточнение заблокированному или незавершённому workflow;
- `/team <задача>` — Planner и Reviewer работают на быстрой модели, Implementer — на основной, Tester запускает детерминированные проверки; состояние всех стадий сохраняется.
- `agent-team -Fast -Project "C:\path\to\project" <задача>` — ускоренный прогон, где и Implementer использует быструю модель; удобен для fixture/smoke-тестов, но для сложных изменений лучше обычный `/team`.

## Безопасный рабочий цикл

1. Запустите `/analysis`, если причина или границы задачи неясны.
2. Используйте `/bugfix`, `/feature` или `/deliver` для изменения.
3. Проверьте `CHANGED FILES`, `VERIFICATION`, `ACCEPTANCE` и `RISKS / NOT VERIFIED`.
4. Запустите `/review`.
5. Самостоятельно просмотрите `git diff` и результаты тестов.
6. Выполните commit вручную.

## Модели и скорость

- `/model` показывает и выбирает work, fast и review модели.
- `/fast on` включает быструю модель для текущей оболочки.
- `/effort` и `/budget` регулируют глубину работы.
- Выбранная work-модель предварительно проверяется настоящим Edit/Write smoke, а не только метаданными Ollama.

Для Qwen управляемая конфигурация отключает reasoning, поскольку в некоторых сочетаниях Continue/Ollama tool calls иначе остаются внутри thinking.

## Разрешения и зависимости

- `project` — рекомендуемый ежедневный режим;
- `readonly` — только исследование;
- `safe` и `ask` — более строгие варианты;
- `trusted` — расширенный режим, использовать временно.

Dependency manifests и lockfiles защищены. Если задача действительно требует изменить зависимости:

```text
/deps on
```

После задачи верните `/deps off`. Destructive Git, push, системные команды и широкие удаления остаются заблокированы.

## IntelliJ IDEA

Установщик создаёт Run configuration `Local Coding Agent` для найденных IDEA-проектов. Управление интеграцией:

```powershell
agent-idea -Project "C:\Projects\my-project" install
agent-idea -Project "C:\Projects\my-project" status
agent-idea -Project "C:\Projects\my-project" remove
```

## Диагностика

```powershell
agent-doctor -Deep
```

В интерактивной оболочке доступны `/log`, `/verbose`, `/status` и `/result`. Evidence хранится вне исходного проекта в установленном runtime. Пустой ответ модели или изменение без проверяемого результата не превращается в ложный PASS.

## Критерий готовности результата

Считайте задачу завершённой только если итог содержит `FINAL RESULT: PASS`, требуемые acceptance criteria подтверждены, проверки действительно запускались и итоговый diff соответствует задаче. `PARTIAL`, `BLOCKED`, `FAIL` и `NOT VERIFIED` требуют решения указанных рисков.
