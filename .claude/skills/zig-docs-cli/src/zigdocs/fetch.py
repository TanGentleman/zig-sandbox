import os
from pathlib import Path

import httpx

_CACHE_ENV = "ZIG_DOCS_CACHE_DIR"
_DEFAULT_CACHE_ROOT = Path("/tmp/zigdocs-cache")


def sources_tar_url(zig_version: str) -> str:
    return f"https://ziglang.org/documentation/{zig_version}/std/sources.tar"


def langref_url(zig_version: str) -> str:
    return f"https://ziglang.org/documentation/{zig_version}/"


def cache_dir_for(zig_version: str) -> Path:
    root = os.environ.get(_CACHE_ENV)
    base = Path(root) if root else _DEFAULT_CACHE_ROOT
    return base / zig_version


def _http_get_bytes(url: str) -> bytes:
    with httpx.Client(follow_redirects=True, timeout=60.0) as client:
        r = client.get(url)
        r.raise_for_status()
        return r.content


def _read_or_fetch(url: str, cache_path: Path, refresh: bool) -> bytes:
    if cache_path.exists() and not refresh:
        return cache_path.read_bytes()
    data = _http_get_bytes(url)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_bytes(data)
    return data


def fetch_sources_tar(zig_version: str, refresh: bool = False) -> bytes:
    return _read_or_fetch(
        sources_tar_url(zig_version),
        cache_dir_for(zig_version) / "sources.tar",
        refresh,
    )


def fetch_langref_html(zig_version: str, refresh: bool = False) -> str:
    data = _read_or_fetch(
        langref_url(zig_version),
        cache_dir_for(zig_version) / "langref.html",
        refresh,
    )
    return data.decode("utf-8")
