!/bin/bash
# Ultra-Aggressive Valgrind Cross-Compilation with Maximum Optimizations

echo "🚀 Starting ULTRA-OPTIMIZED Valgrind build..."

# Setup environment  
export OSXCROSS_ROOT=$(pwd)/osxcross
export PATH="$OSXCROSS_ROOT/target/bin:$PATH"

# Ultra-aggressive optimization flags
ULTRA_CFLAGS="-O3 -flto=full -march=skylake -mtune=skylake \
              -mavx2 -mfma -mbmi -mbmi2 -mlzcnt -madx \
              -mfsgsbase -mrdrnd -mrdseed -mf16c \
              -funroll-loops -fvect-cost-model=cheap \
              -finline-functions -finline-limit=2000 \
              -ffunction-sections -fdata-sections \
              -fvisibility=hidden -fno-rtti \
              -fomit-frame-pointer -ffast-math"

ULTRA_CXXFLAGS="$ULTRA_CFLAGS \
                -fwhole-program-vtables \
                -fvirtual-function-elimination \
                -fno-exceptions"

ULTRA_LDFLAGS="-flto=full \
               -Wl,-dead_strip \
               -Wl,-x \
               -Wl,--gc-sections \
               -Wl,-O3 \
               -s"

echo "📊 Optimization flags:"
echo "CFLAGS: $ULTRA_CFLAGS"
echo "LDFLAGS: $ULTRA_LDFLAGS"

cd valgrind-3.25.1

# Clean previous build
make clean 2>/dev/null || true

# Configure with ultra-aggressive optimization
env -i \
    PATH="/tmp/fake_uname:$OSXCROSS_ROOT/target/bin:/usr/bin:/bin" \
    HOME=$HOME SHELL=/bin/bash OSXCROSS_ROOT=$OSXCROSS_ROOT \
    CFLAGS="$ULTRA_CFLAGS" \
    CXXFLAGS="$ULTRA_CXXFLAGS" \
    LDFLAGS="$ULTRA_LDFLAGS" \
    ./configure \
        --host=x86_64-apple-darwin17 \
        --target=x86_64-apple-darwin17 \
        CC=x86_64-apple-darwin17-clang \
        CXX=x86_64-apple-darwin17-clang++ \
        --enable-only64bit \
        --prefix=/usr/local \
        --disable-dependency-tracking \
        --enable-tls \
        2>&1 | tee configure-ultra.log

# Apply our path fixes
sed -i "s|/usr/include/mach/|$OSXCROSS_ROOT/MacOSX10.13.sdk/usr/include/mach/|g" coregrind/Makefile
sed -i 's|my $cmd = "/usr/bin/ld";|my $cmd = "x86_64-apple-darwin17-ld";|' coregrind/link_tool_exe_darwin
sed -i '/cd m_mach && mig.*defs/d' coregrind/Makefile

# Ultra-aggressive build
echo "🔥 Building with MAXIMUM optimization..."
env -i \
    PATH="/tmp/fake_uname:$OSXCROSS_ROOT/target/bin:/usr/bin:/bin" \
    HOME=$HOME SHELL=/bin/bash OSXCROSS_ROOT=$OSXCROSS_ROOT \
    make -j$(nproc) 2>&1 | tee make-ultra.log

# Check results
if [ -f coregrind/valgrind ]; then
    echo "✅ Ultra-optimized build SUCCESS!"
    echo "📊 Size comparison:"
    ls -lh coregrind/valgrind
    file coregrind/valgrind
    x86_64-apple-darwin17-otool -L coregrind/valgrind
    echo "Symbol count: $(x86_64-apple-darwin17-nm coregrind/valgrind | wc -l)"
else
    echo "❌ Ultra-optimized build failed - check logs"
fi
EOF

chmod +x ultra-optimized-build.sh && echo "Ultra-optimization script created!"