import struct


def unpack_string(memory: bytes, ptr: int, length: int) -> str:
    if length == 0:
        return ""
    return memory[ptr : ptr + length].decode("utf-8", errors="replace")


def unpack_slice32(memory: bytes, ptr: int, length: int) -> list[int]:
    if length == 0:
        return []
    return list(struct.unpack_from(f"<{length}I", memory, ptr))


def unpack_slice64(memory: bytes, ptr: int, length: int) -> list[int]:
    if length == 0:
        return []
    return list(struct.unpack_from(f"<{length}Q", memory, ptr))


def split_packed(packed: int) -> tuple[int, int]:
    """Decode the JS BigInt packing: low32 = ptr, high32 = length."""
    return packed & 0xFFFFFFFF, packed >> 32
