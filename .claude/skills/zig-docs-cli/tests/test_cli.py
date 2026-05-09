import os
import subprocess
from pathlib import Path

import pytest

SKILL_ROOT = Path(__file__).resolve().parent.parent


def run_cli(*args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    cmd = ["uv", "run", "zigdocs", *args]
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    return subprocess.run(
        cmd,
        cwd=SKILL_ROOT,
        env=full_env,
        capture_output=True,
        text=True,
    )


def test_no_args_prints_help_and_exits_nonzero():
    proc = run_cli()
    assert proc.returncode != 0
    assert "usage" in (proc.stdout + proc.stderr).lower()


def test_search_help_lists_flags():
    proc = run_cli("search", "--help")
    assert proc.returncode == 0
    assert "--limit" in proc.stdout
    assert "--version" in proc.stdout
    assert "--refresh" in proc.stdout


def test_builtins_subcommand_help():
    proc = run_cli("builtins", "--help")
    assert proc.returncode == 0
    assert "list" in proc.stdout
    assert "get" in proc.stdout


def test_prefetch_help_lists_flags():
    proc = run_cli("prefetch", "--help")
    assert proc.returncode == 0
    assert "--cache-dir" in proc.stdout
    assert "--version" in proc.stdout
    assert "--refresh" in proc.stdout


def test_search_help_lists_cache_dir():
    proc = run_cli("search", "--help")
    assert proc.returncode == 0
    assert "--cache-dir" in proc.stdout


def test_builtins_get_empty_returns_exit_1(tmp_path):
    proc = run_cli("builtins", "get", "", env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)})
    assert proc.returncode == 1
    assert proc.stdout == ""


def test_search_empty_query_returns_exit_1(tmp_path):
    proc = run_cli("search", "", env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)})
    assert proc.returncode == 1


def test_search_with_corrupt_sources_tar_exits_2(tmp_path):
    cached = tmp_path / "0.16.0" / "sources.tar"
    cached.parent.mkdir(parents=True)
    cached.write_bytes(b"NOT-A-TAR")
    proc = run_cli(
        "search", "ArrayList", env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)}
    )
    assert proc.returncode == 2
    assert "data error" in proc.stderr
    assert "prefetch --refresh" in proc.stderr


SMOKE = pytest.mark.skipif(
    os.environ.get("ZIGDOCS_SMOKE") != "1",
    reason="set ZIGDOCS_SMOKE=1 for network smoke tests",
)


@SMOKE
def test_search_arraylist_returns_markdown(tmp_path):
    proc = run_cli(
        "search", "ArrayList", "--limit", "3",
        env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.startswith("# Search Results")


@SMOKE
def test_get_std_arraylist(tmp_path):
    proc = run_cli(
        "get", "std.ArrayList",
        env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.startswith("#")


@SMOKE
def test_get_unknown_returns_exit_1(tmp_path):
    proc = run_cli(
        "get", "std.does_not_exist_xyz",
        env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)},
    )
    assert proc.returncode == 1
    assert "not found" in proc.stderr.lower()


@SMOKE
def test_builtins_list_runs(tmp_path):
    proc = run_cli(
        "builtins", "list",
        env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    assert "@" in proc.stdout


@SMOKE
def test_builtins_get_atomic(tmp_path):
    proc = run_cli(
        "builtins", "get", "atomic",
        env={"ZIG_DOCS_CACHE_DIR": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    assert "@atomic" in proc.stdout
