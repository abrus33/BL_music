#!/usr/bin/env python3
"""Android 构建验证工具：开发者在部署前检查 ARM64 ELF 或 APK 内的两个 OpenSSL 库。

本工具读取程序头，不调用 adb，也不把静态通过等同于真机成功。
用于捕获本项目曾出现的 patchelf + strip 段布局损坏；不参与 Qt/C++ 业务调用链。
"""
import struct
import sys
from pathlib import Path
from zipfile import ZipFile, is_zipfile


def check_elf(data, name):
    if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01":
        raise ValueError(f"{name}: expected little-endian ELF64")
    if struct.unpack_from("<HH", data, 16) != (3, 183):
        raise ValueError(f"{name}: expected AArch64 shared library")
    offset = struct.unpack_from("<Q", data, 32)[0]
    entry_size, count = struct.unpack_from("<HH", data, 54)
    if entry_size != 56 or offset + count * entry_size > len(data):
        raise ValueError(f"{name}: invalid program header table")
    loads = 0
    for index in range(count):
        kind, _, file_offset, address, _, file_size, memory_size, align = struct.unpack_from(
            "<IIQQQQQQ", data, offset + index * entry_size
        )
        if kind != 1:  # PT_LOAD：Android loader 按这些段把文件映射到进程地址空间。
            continue
        loads += 1
        # 只检查 p_align 数字不足够；文件偏移和虚拟地址还必须对该对齐值同余。
        # 否则 mmap 按页映射后，动态字符串表可能被读成错误内容，甚至导致启动崩溃。
        if align < 16384 or align & (align - 1) or file_offset % align != address % align:
            raise ValueError(
                f"{name}: LOAD[{index}] invalid alignment: "
                f"offset={file_offset:#x}, vaddr={address:#x}, align={align:#x}"
            )
        if file_size > memory_size or file_offset + file_size > len(data):
            raise ValueError(f"{name}: LOAD[{index}] invalid size")
    if not loads:
        raise ValueError(f"{name}: no LOAD segments")


def main(paths):
    checked = 0
    for path in map(Path, paths):
        if is_zipfile(path):
            with ZipFile(path) as archive:
                names = ["lib/arm64-v8a/libcrypto_3.so", "lib/arm64-v8a/libssl_3.so"]
                if not all(name in archive.namelist() for name in names):
                    raise ValueError(f"{path}: missing Android OpenSSL runtime")
                for name in names:
                    check_elf(archive.read(name), f"{path}!/{name}")
                    checked += 1
        else:
            check_elf(path.read_bytes(), str(path))
            checked += 1
    print(f"PASS: {checked} ARM64 ELF libraries have consistent 16 KiB-compatible LOAD segments")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Usage: python3 scripts/check-android-elf.py LIBRARY.so | APPLICATION.apk [...]")
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, struct.error) as error:
        sys.exit(str(error))
