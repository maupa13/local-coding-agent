import importlib.util
import os
from pathlib import Path

path = Path(os.environ["EVAL_PROJECT"]) / "src" / "rate_limiter.py"
spec = importlib.util.spec_from_file_location("rate_limiter", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
RateLimiter = module.RateLimiter

def test_independent_keys_and_boundary():
    now = [100.0]
    limiter = RateLimiter(limit=2, window_seconds=10, clock=lambda: now[0])
    assert limiter.allow("a") is True
    assert limiter.allow("a") is True
    assert limiter.allow("a") is False
    assert limiter.allow("b") is True
    now[0] = 110.0
    assert limiter.allow("a") is True

def test_constructor_and_key_validation():
    import pytest
    for kwargs in ({"limit": 0, "window_seconds": 1}, {"limit": 1, "window_seconds": 0}):
        with pytest.raises((TypeError, ValueError)):
            RateLimiter(**kwargs)
    limiter = RateLimiter(1, 1)
    with pytest.raises((TypeError, ValueError)):
        limiter.allow("")

def test_reset_is_selective_and_reports_presence():
    limiter = RateLimiter(1, 60)
    limiter.allow("a"); limiter.allow("b")
    assert limiter.reset("a") is True
    assert limiter.reset("a") is False
    assert limiter.allow("a") is True
    assert limiter.allow("b") is False

