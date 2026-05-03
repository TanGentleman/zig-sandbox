from pathlib import Path

import pytest

SKILL_ROOT = Path(__file__).resolve().parent.parent
VENDOR_WASM = SKILL_ROOT / "vendor" / "main.wasm"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


@pytest.fixture
def vendor_wasm_path() -> Path:
    if not VENDOR_WASM.exists():
        pytest.skip(f"vendor/main.wasm not present at {VENDOR_WASM}")
    return VENDOR_WASM


@pytest.fixture
def fixture_path():
    def _loader(name: str) -> Path:
        return FIXTURES / name
    return _loader
