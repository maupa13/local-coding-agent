# Железо, профили и корректное использование

Local Coding Agent выполняет код, тесты и lint локально. Качество зависит от модели, доступного контекста, инструментов проекта и бюджета turns/tokens. Профиль регулирует ресурсы, но не отменяет quality gates.

## Профили

| Профиль | Ориентир | Подходящие задачи | Ограничения |
|---|---|---|---|
| `low-vram` | до 8 ГБ VRAM, 16 ГБ RAM | анализ, небольшие Python/JS bugfix, 1–2 файла | контекст 8k; крупные JVM-задачи лучше дробить |
| `balanced-12gb` | 10–12 ГБ VRAM, 32 ГБ RAM, SSD/NVMe | основной режим: Java/Kotlin/Python/Rust/frontend, Maven/Gradle | одна активная модель; monorepo требует точных границ |
| `large-vram` | 16–24+ ГБ VRAM, 48–64+ ГБ RAM | Spring/Android, большие diff и длительная диагностика | 32k context требует больше памяти и времени |

CPU-only допустим для коротких задач, но model loop будет существенно медленнее. VRAM ускоряет модель, а Maven, Gradle, Cargo, Docker и Android build зависят также от CPU, RAM и диска.

## Настройка

Редактируйте `config/hardware-profiles.json`:

```json
{
  "mode": "balanced-12gb",
  "overrides": {
    "contextTokens": 16384,
    "outputTokens": 4096,
    "runTokens": 200000,
    "turns": 36,
    "toolCalls": 48,
    "shellCalls": 12,
    "repairCycles": 3,
    "noProgressActions": 6,
    "sameActionRepeats": 3,
    "commandTimeoutSeconds": 180,
    "parallelModels": 1
  }
}
```

- `mode`: `auto`, `low-vram`, `balanced-12gb`, `large-vram`.
- `contextTokens`: окно одного запроса; не превышайте возможности модели/VRAM.
- `outputTokens`: размер ответа или edit payload; для JVM multi-file рекомендуется 4096.
- `runTokens`: общий предохранитель запуска, не цель расхода.
- `turns`: число model → tool → evidence циклов; повторы runtime останавливает отдельно.
- `toolCalls`: общий лимит file/search/edit/shell действий.
- `shellCalls`: отдельный лимит build/test/lint/Git-команд.
- `repairCycles`: сколько неуспешных verification → repair циклов допустимо.
- `noProgressActions`: сколько действий без нового evidence допускается подряд.
- `sameActionRepeats`: порог одинаковых действий; changing edits переводятся к verification, пустые повторы останавливаются.
- `commandTimeoutSeconds`: верхняя граница для одной build/test команды; tool может запросить меньше.
- `recentMessages`: недавняя история; repository/evidence остаются источником истины.
- `snapshotFiles` и `snapshotCharacters`: стартовый компактный repo context.
- `parallelModels`: для 8–12 ГБ VRAM оставляйте `1`.

В `auto` профиль выбирается по доступной VRAM. Фактические значения сохраняются в evidence. После изменения установленной конфигурации выполните `agent-doctor -Deep`.

## Что происходит при превышении

Runtime работает fail-closed:

| Лимит | Результат превышения |
|---|---|
| `turns` | `BLOCKED: turn budget exhausted`; незавершённые изменения остаются видимыми в Git/evidence |
| `runTokens` | текущий ответ учитывается, затем run останавливается как `BLOCKED` |
| `toolCalls` / `shellCalls` | tools закрываются; ложный `TASK_COMPLETE` не принимается |
| `repairCycles` | после повторных failing verification run блокируется с последней ошибкой |
| `noProgressActions` | прекращается цикл чтений/no-op без инженерного прогресса |
| `sameActionRepeats` | runtime требует другую стратегию или verification; бесконечный повтор блокируется |
| command timeout | процесс завершается, timeout записывается как failed verification и запускает repair при наличии бюджета |

Runtime не делает commit, reset или автоматический rollback пользовательских файлов. После `BLOCKED` изучите `final-result.txt`, `run.json`, transcript и `git diff`. Исправьте внешнюю причину или настройки и используйте `/continue`; увеличивать следует конкретный достигнутый лимит, а не все значения сразу.

Диапазоны валидируются при запуске. Нулевые, отрицательные и чрезмерные значения отклоняются до работы модели, чтобы опечатка не создала бесконечный или неконтролируемый run.

## Java, Spring и Android

`config/toolchains.json` задаёт локальные пути. Основной baseline:

- Temurin JDK 21, Maven, актуальный Gradle;
- Spring Boot 3, `jakarta.persistence`, Hibernate 6;
- Java + Checkstyle, Kotlin + Detekt;
- Rust + Clippy, frontend typecheck/lint;
- Android compileSdk 36 и Android lint.

Линии проверяются раздельно:

- primary: Spring Boot 3 на Temurin 21;
- forward: Spring Boot 4, Hibernate 7, Android API 36/37;
- legacy: Spring Boot 2, `javax.persistence`, Gradle 7 и JDK 17 при необходимости.

Legacy и modern API нельзя смешивать в одном oracle. Если wrapper проекта требует JDK 17 или Gradle 7, используйте его и фиксируйте версии в verification evidence.

## Корректная постановка задачи

Укажите цель, границы, acceptance criteria и команды проверки:

```text
/bugfix Исправь optimistic-lock конфликт в orders. Не меняй public API и migrations.
Добавь regression test. Проверки: mvnw.cmd test и Checkstyle. Покажи Git diff и evidence.
```

Для Spring/SQL укажите Boot, БД, транзакции и допустимость migrations. Для Android — module, min/target/compile SDK и необходимость instrumentation. Для frontend — browser support, typecheck/lint/build и accessibility criteria.

Рабочий цикл:

1. `agent-init -Project <path>` и ручная проверка project rules.
2. Отдельная Git-ветка и понятный исходный `git status`.
3. `/analysis` для неясной причины; `/feature`, `/bugfix`, `/refactor`, `/test` или `/deliver` для изменения.
4. Принимать только `FINAL RESULT: PASS` с фактически исполненными test/lint/build evidence и ожидаемым diff.
5. `/review`, ручной `git diff`, затем commit/push пользователем.

Больший budget не превращает слабую модель в надёжную. При повторах сначала уточните task, project rules и focused verification, затем выбирайте более сильную модель или профиль.
