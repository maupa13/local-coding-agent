# Позиционирование и развитие

Local Coding Agent — не локальная копия Cline, Aider или OpenHands. Это Windows/PowerShell-first runtime для одного разработчика, где завершение определяется исполненными tests/lint/build, Git safety и evidence, а не заявлением модели.

## Возможности и ориентиры

| Уровень | Близкие ориентиры | Наш акцент |
|---|---|---|
| Agent + tools | Aider, Cline, SWE-agent | ограниченные file/shell/Git tools, project boundary, реальные тесты |
| Memory/context | Cline Memory Bank, Aider repo-map | project rules, компактный snapshot, transcript/evidence |
| Runtime control | OpenHands SDK, SWE-agent | lifecycle, budgets, repair/retries, Windows execution policy |
| Deterministic delivery | частично OpenHands/Aider | отдельные test/lint/build gates, hidden oracle, Git acceptance |
| Multi-role engineering | Aider Architect/Editor, OpenHands custom agents | analysis, feature, bugfix, refactor, test, review, release, system-analysis |

Design references:

- Aider: editing strategy, repo map и benchmark methodology;
- Cline: IDE UX, tools и небольшая durable project memory;
- OpenHands: runtime/execution abstractions, retries, sandbox и telemetry;
- SWE-agent: task-oriented tools и воспроизводимые fixtures;
- LSDA/SDD: constraints, traceability, memory и deterministic completion.

Это не runtime dependencies и не заявление о полном паритете. Идея принимается только после улучшения hidden-oracle completion, safety или verified completions per token.

## Чем отличаемся

- Автономность ограничена project policy и deterministic gates, а не постоянными ручными подтверждениями.
- PASS нельзя получить только красивым diff или тестами, написанными самой моделью.
- Test, lint и build — разные evidence; Git HEAD/status и побочные файлы проверяются отдельно.
- Основной путь рассчитан на Ollama, PowerShell, IntelliJ IDEA и один репозиторий за запуск.
- Все участники benchmark получают изолированные одинаковые fixtures и одинаковые public/hidden/lint oracle. Runner failure отмечается как infrastructure error.

Codex, Cline или Aider могут быть сильнее на отдельных моделях, UX или editing patterns. Цель — не маркетинговое «равенство Codex», а воспроизводимая автономная разработка на локальном железе с честным GO/NO-GO.

## Направления 8–12

### 8. Self-improving orchestration

Агрегация причин repair/stall и выбор доказанной editing policy. Автоматическое изменение policy допускается только через фиксированную regression matrix.

### 9. Adaptive routing

Routing по роли, стеку, сложности, VRAM, цене и verified history; раздельные work/fast/review модели и fallback после tool-call smoke.

### 10. Durable engineering memory

Версионируемые project facts и решения с provenance. Memory не подменяет чтение текущего кода.

### 11. Broader execution isolation

Единый execution interface для Windows process, Docker и sandbox backends; resource/network/dependency policy и воспроизводимые toolchains.

### 12. Continuous qualification

Расширение language/role matrix, mutation testing, flaky detection, benchmark trends и automatic release blocking. Полное сочетание локальности, адаптивности и deterministic delivery остаётся направлением развития, а не готовым обещанием.

Новая функция принимается, только если повышает подтверждённые completions, не ослабляет safety, не скрывает infrastructure failures и проходит Quick, Full, Release и autonomous comparison.
