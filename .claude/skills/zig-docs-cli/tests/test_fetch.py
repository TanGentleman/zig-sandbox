from pathlib import Path

from zigdocs.fetch import (
    cache_dir_for,
    fetch_langref_html,
    fetch_sources_tar,
    langref_url,
    sources_tar_url,
)


def test_url_builders():
    assert (
        sources_tar_url("0.16.0")
        == "https://ziglang.org/documentation/0.16.0/std/sources.tar"
    )
    assert langref_url("0.16.0") == "https://ziglang.org/documentation/0.16.0/"


def test_cache_dir_uses_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv("ZIG_DOCS_CACHE_DIR", str(tmp_path))
    d = cache_dir_for("0.16.0")
    assert d == tmp_path / "0.16.0"


def test_default_cache_dir_is_tmp_zigdocs_cache(monkeypatch):
    monkeypatch.delenv("ZIG_DOCS_CACHE_DIR", raising=False)
    assert cache_dir_for("0.16.0") == Path("/tmp/zigdocs-cache/0.16.0")


def test_fetch_sources_uses_cache_when_present(tmp_path, monkeypatch):
    monkeypatch.setenv("ZIG_DOCS_CACHE_DIR", str(tmp_path))
    cached = tmp_path / "0.16.0" / "sources.tar"
    cached.parent.mkdir(parents=True)
    cached.write_bytes(b"PRE-CACHED")

    data = fetch_sources_tar("0.16.0", refresh=False)
    assert data == b"PRE-CACHED"


def test_fetch_sources_refresh_overwrites_cache(tmp_path, monkeypatch):
    monkeypatch.setenv("ZIG_DOCS_CACHE_DIR", str(tmp_path))
    cached = tmp_path / "0.16.0" / "sources.tar"
    cached.parent.mkdir(parents=True)
    cached.write_bytes(b"OLD")

    calls: list[str] = []

    def fake_get(url: str) -> bytes:
        calls.append(url)
        return b"NEW"

    monkeypatch.setattr("zigdocs.fetch._http_get_bytes", fake_get)
    data = fetch_sources_tar("0.16.0", refresh=True)
    assert data == b"NEW"
    assert cached.read_bytes() == b"NEW"
    assert calls == [sources_tar_url("0.16.0")]


def test_fetch_langref_caches_text(tmp_path, monkeypatch):
    monkeypatch.setenv("ZIG_DOCS_CACHE_DIR", str(tmp_path))

    def fake_get(url: str) -> bytes:
        return b"<html>hello</html>"

    monkeypatch.setattr("zigdocs.fetch._http_get_bytes", fake_get)

    html = fetch_langref_html("0.16.0", refresh=False)
    assert html == "<html>hello</html>"
    assert (tmp_path / "0.16.0" / "langref.html").read_bytes() == (
        b"<html>hello</html>"
    )
