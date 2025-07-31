# Valgrind 3.25.1 - Cross-Compiled for macOS x86_64

## Package Details
- Target: macOS 10.15.7+ (Darwin 19+) Intel x86_64
- Built on: Linux using osxcross toolchain
- Optimizations: Skylake CPU optimizations (-march=skylake -mtune=skylake)
- Size: 240KB portable package

## Contents
- valgrind: Main launcher executable (36KB)
- vgpreload_core-amd64-darwin.so: Core preload library (9.7KB)
- vgpreload_memcheck-amd64-darwin.so: Memcheck tool library (27KB)
- darwin*.supp: macOS-specific suppression files
- default.supp: General suppression file

## Usage Instructions

### Basic Memory Checking
./valgrind --tool=memcheck your_program

### Advanced Leak Detection
./valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all your_program

### With macOS-Specific Suppressions
./valgrind --tool=memcheck --suppressions=darwin17.supp your_program

## System Requirements
- macOS 10.15.7 (Catalina) or later
- Intel x86_64 processor (optimized for Skylake)
- Compatible with your macOS version Darwin suppression file

## Notes
- This is a statically-linked build optimized for portability
- Only depends on system libSystem.B.dylib
- Cross-compiled on Linux using revolutionary MIG solution
- Memcheck tool is available; other tools may require additional compilation

## Troubleshooting
If you encounter platform issues, ensure you're running on macOS 10.15.7+.
For older macOS versions, use the appropriate darwin*.supp file.

Build completed: August 1, 2025
Cross-compilation: ✅ SUCCESS
