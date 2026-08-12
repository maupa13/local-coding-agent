"""Dependency-free benchmark lint checks; not a replacement for project linters."""

import ast
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"LINT FAIL: {message}")


root = Path(sys.argv[1])
source = root / "src" / "rate_limiter.py"
tests = root / "tests" / "test_rate_limiter.py"
source_text = source.read_text(encoding="utf-8-sig")
test_text = tests.read_text(encoding="utf-8-sig")
source_tree = ast.parse(source_text, source)
test_tree = ast.parse(test_text, tests)

imports = []
for tree in (source_tree, test_tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.append(node.module or "")
if any(name not in {"time", "collections.abc", "pytest", "src.rate_limiter"} for name in imports):
    fail("unexpected dependency")
if "sleep(" in test_text:
    fail("tests must use an injected clock, not sleep")
test_count = sum(isinstance(node, ast.FunctionDef) and node.name.startswith("test_") for node in test_tree.body)
if not 6 <= test_count <= 10:
    fail(f"expected 6-10 tests, found {test_count}")
if "test_placeholder" in test_text or "assert True" in test_text:
    fail("placeholder/trivial assertion remains")
if not any(isinstance(node, ast.ClassDef) and node.name == "RateLimiter" for node in source_tree.body):
    fail("RateLimiter class missing")
print(f"LINT PASS: syntax, dependencies, determinism and test quality ({test_count} tests)")
