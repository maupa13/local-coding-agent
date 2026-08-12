"""A small fixed-window rate limiter used as the benchmark gold baseline."""

import time
from collections.abc import Callable


class RateLimiter:
    def __init__(
        self,
        limit: int,
        window_seconds: float,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if isinstance(limit, bool) or not isinstance(limit, int) or limit <= 0:
            raise ValueError("limit must be a positive integer")
        if isinstance(window_seconds, bool) or not isinstance(window_seconds, (int, float)) or window_seconds <= 0:
            raise ValueError("window_seconds must be positive")
        if not callable(clock):
            raise TypeError("clock must be callable")
        self._limit = limit
        self._window_seconds = float(window_seconds)
        self._clock = clock
        self._windows: dict[str, tuple[float, int]] = {}

    def allow(self, key: str) -> bool:
        if not isinstance(key, str) or not key.strip():
            raise ValueError("key must be a non-blank string")
        now = self._clock()
        start, count = self._windows.get(key, (now, 0))
        if now - start >= self._window_seconds:
            start, count = now, 0
        if count >= self._limit:
            self._windows[key] = (start, count)
            return False
        self._windows[key] = (start, count + 1)
        return True

    def reset(self, key: str) -> bool:
        if not isinstance(key, str) or not key.strip():
            raise ValueError("key must be a non-blank string")
        return self._windows.pop(key, None) is not None
