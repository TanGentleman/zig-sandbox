from pathlib import Path

import pytest

VENDOR_WASM = Path(__file__).resolve().parent.parent / "vendor" / "main.wasm"


@pytest.fixture
def vendor_wasm_path() -> Path:
    if not VENDOR_WASM.exists():
        pytest.skip(f"vendor/main.wasm not present at {VENDOR_WASM}")
    return VENDOR_WASM
