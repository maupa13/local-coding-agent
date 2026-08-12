import pytest

from src.rate_limiter import RateLimiter


def test_limit_and_rejection():
    limiter = RateLimiter(2, 10)
    assert [limiter.allow("a") for _ in range(3)] == [True, True, False]


def test_keys_are_independent():
    limiter = RateLimiter(1, 10)
    assert limiter.allow("a") is True
    assert limiter.allow("a") is False
    assert limiter.allow("b") is True


def test_exact_boundary_opens_new_window():
    now = [100.0]
    limiter = RateLimiter(1, 10, lambda: now[0])
    assert limiter.allow("a") is True
    now[0] = 110.0
    assert limiter.allow("a") is True


def test_constructor_validation():
    for args in ((0, 1), (1, 0), (True, 1), (1, False)):
        with pytest.raises((TypeError, ValueError)):
            RateLimiter(*args)


def test_key_validation():
    limiter = RateLimiter(1, 1)
    for key in ("", "  ", None, 42):
        with pytest.raises((TypeError, ValueError)):
            limiter.allow(key)


def test_reset_is_selective_and_reports_presence():
    limiter = RateLimiter(1, 60)
    limiter.allow("a")
    limiter.allow("b")
    assert limiter.reset("a") is True
    assert limiter.reset("a") is False
    assert limiter.allow("a") is True
    assert limiter.allow("b") is False
