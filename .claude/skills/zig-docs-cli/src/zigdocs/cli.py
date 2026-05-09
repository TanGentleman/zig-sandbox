"""argparse entrypoint for `zigdocs`. Five subcommands matching the MCP tools
plus a prefetch helper for offline-first workflows.

Exit codes:
  0 — success (markdown on stdout)
  1 — bad input or "not found" (message on stderr)
  2 — network or cache failure (message on stderr)
"""

import argparse
import sys
from pathlib import Path

import httpx

from zigdocs import builtins as builtins_mod
from zigdocs.fetch import (
    fetch_langref_html,
    fetch_sources_tar,
    langref_url,
    prefetch as fetch_prefetch,
)
from zigdocs.stdlib import render_get_item, render_search
from zigdocs.version import resolve_version
from zigdocs.wasm import WasmStd

_SKILL_ROOT = Path(__file__).resolve().parent.parent.parent
_VENDOR_WASM = _SKILL_ROOT / "vendor" / "main.wasm"


def _err(msg: str, code: int) -> int:
    print(msg, file=sys.stderr)
    return code


def _load_std(version: str, refresh: bool, cache_dir: str | None) -> WasmStd:
    if not _VENDOR_WASM.exists():
        raise FileNotFoundError(
            f"vendor/main.wasm not found at {_VENDOR_WASM}. "
            "See vendor/PROVENANCE.md for build instructions."
        )
    sources = fetch_sources_tar(version, refresh=refresh, cache_dir=cache_dir)
    return WasmStd(_VENDOR_WASM.read_bytes(), sources)


def _load_builtins(
    version: str, refresh: bool, cache_dir: str | None
) -> tuple[list[builtins_mod.BuiltinFunction], str]:
    html = fetch_langref_html(version, refresh=refresh, cache_dir=cache_dir)
    base = langref_url(version)
    return builtins_mod.parse_builtin_functions_html(html, link_base_url=base), base


def _cmd_search(args: argparse.Namespace) -> int:
    if not args.query:
        return _err("query cannot be empty", 1)
    try:
        version = resolve_version(args.version)
        std = _load_std(version, args.refresh, args.cache_dir)
        sys.stdout.write(render_search(std, args.query, limit=args.limit))
        sys.stdout.write("\n")
        return 0
    except (httpx.HTTPError, OSError) as e:
        return _err(f"network/cache error: {e}", 2)


def _cmd_get(args: argparse.Namespace) -> int:
    if not args.fqn:
        return _err("fully-qualified name cannot be empty", 1)
    try:
        version = resolve_version(args.version)
        std = _load_std(version, args.refresh, args.cache_dir)
        md = render_get_item(std, args.fqn, get_source_file=args.source_file)
        if md.startswith("# Error"):
            print(md, file=sys.stderr)
            return 1
        sys.stdout.write(md)
        sys.stdout.write("\n")
        return 0
    except (httpx.HTTPError, OSError) as e:
        return _err(f"network/cache error: {e}", 2)


def _cmd_builtins_list(args: argparse.Namespace) -> int:
    try:
        version = resolve_version(args.version)
        fns, base = _load_builtins(version, args.refresh, args.cache_dir)
        lines = "\n".join(f"- {fn.signature}" for fn in fns)
        sys.stdout.write(
            f"Available {len(fns)} builtin functions "
            f"(full docs: {base}):\n\n{lines}\n"
        )
        return 0
    except (httpx.HTTPError, OSError) as e:
        return _err(f"network/cache error: {e}", 2)


def _cmd_builtins_get(args: argparse.Namespace) -> int:
    if not args.query:
        return _err("query cannot be empty", 1)
    try:
        version = resolve_version(args.version)
        fns, _ = _load_builtins(version, args.refresh, args.cache_dir)
        ranked = builtins_mod.rank_builtin_functions(fns, args.query)
        if not ranked:
            return _err(
                f'No builtin functions found matching "{args.query}". '
                "Try `zigdocs builtins list` to see all functions.",
                1,
            )
        chunks = [
            f"**{fn.func}**\n```zig\n{fn.signature}\n```\n\n{fn.docs}"
            for fn in ranked
        ]
        body = "\n\n---\n\n".join(chunks)
        if len(ranked) == 1:
            sys.stdout.write(body + "\n")
        else:
            sys.stdout.write(f"Found {len(ranked)} matching functions:\n\n{body}\n")
        return 0
    except (httpx.HTTPError, OSError) as e:
        return _err(f"network/cache error: {e}", 2)


def _cmd_prefetch(args: argparse.Namespace) -> int:
    try:
        version = resolve_version(args.version)
        paths = fetch_prefetch(
            version, refresh=args.refresh, cache_dir=args.cache_dir
        )
        sys.stdout.write(
            f"Prefetched docs for Zig {version}:\n"
            f"  sources.tar  → {paths['sources.tar']}\n"
            f"  langref.html → {paths['langref.html']}\n"
        )
        return 0
    except (httpx.HTTPError, OSError) as e:
        return _err(f"network/cache error: {e}", 2)


def _add_common(p: argparse.ArgumentParser) -> None:
    p.add_argument("--version", default=None, help="Zig version (default: 0.16.0)")
    p.add_argument(
        "--refresh",
        action="store_true",
        help="Force re-download of cached resources",
    )
    p.add_argument(
        "--cache-dir",
        default=None,
        help=(
            "Cache directory root (overrides ZIG_DOCS_CACHE_DIR; "
            "default: /tmp/zigdocs-cache)"
        ),
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="zigdocs", description="Zig 0.16 docs CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_search = sub.add_parser("search", help="Search the standard library")
    p_search.add_argument("query")
    p_search.add_argument("--limit", type=int, default=20)
    _add_common(p_search)
    p_search.set_defaults(func=_cmd_search)

    p_get = sub.add_parser("get", help="Get docs for a fully-qualified stdlib name")
    p_get.add_argument("fqn")
    p_get.add_argument(
        "--source-file",
        action="store_true",
        help="Return the entire source file for the item",
    )
    _add_common(p_get)
    p_get.set_defaults(func=_cmd_get)

    p_builtins = sub.add_parser("builtins", help="Builtin function lookups")
    builtins_sub = p_builtins.add_subparsers(dest="builtins_cmd", required=True)

    p_blist = builtins_sub.add_parser("list", help="List all builtin functions")
    _add_common(p_blist)
    p_blist.set_defaults(func=_cmd_builtins_list)

    p_bget = builtins_sub.add_parser("get", help="Look up a builtin by name/keyword")
    p_bget.add_argument("query")
    _add_common(p_bget)
    p_bget.set_defaults(func=_cmd_builtins_get)

    p_pre = sub.add_parser(
        "prefetch",
        help="Download sources.tar + langref.html so other commands run offline",
    )
    _add_common(p_pre)
    p_pre.set_defaults(func=_cmd_prefetch)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
