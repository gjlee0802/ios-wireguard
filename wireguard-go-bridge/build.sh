#! /usr/bin/env bash

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT"

BUILD_ROOT="$ROOT/out/build"
ARTIFACT="../lib/libwg-go.a"

rm -rf "$BUILD_ROOT" "$ARTIFACT"
mkdir -p "$BUILD_ROOT"


REAL_GOROOT="/usr/local/go"
GOROOT="$BUILD_ROOT/goroot"
[ -n "$REAL_GOROOT" ]
mkdir -p "$GOROOT"
rsync -a --delete --exclude=pkg/obj/go-build "$REAL_GOROOT/" "$GOROOT/"
export GOROOT
#cat goruntime-*.diff | patch -p1 -f -N -r- -d "$GOROOT"
#touch "$@"

# Create a patched goroot using patches needed for iOS
#GOROOT="$BUILD_ROOT/goroot/" # Not exported yet, still need the original GOROOT to copy
#echo $GOROOT
#mkdir -p "$GOROOT"
#rsync --exclude="pkg/obj/go-build" -a "$(go env GOROOT)/" "$GOROOT/"
#export GOROOT
##cat goruntime-*.diff | patch -p1 -fN -r- -d "$GOROOT"

BUILD_CFLAGS="-fembed-bitcode -Wno-unused-command-line-argument"

LIPO_INPUT_LIBS=()

# Build the library for each target
function build_arch() {
    local ARCH="$1"
    local GOARCH="$2"
    local SDKNAME="$3"
    # Find the SDK path
    local SDKPATH
    SDKPATH="$(xcrun --sdk "$SDKNAME" --show-sdk-path)"
    local FULL_CFLAGS="$BUILD_CFLAGS -isysroot $SDKPATH -arch $ARCH"
    go get -u golang.org/x/sys
    CGO_ENABLED=1 CGO_CFLAGS="$FULL_CFLAGS" CGO_LDFLAGS="$FULL_CFLAGS" GOOS=darwin GOARCH="$GOARCH" GOROOT="/usr/local/go" \
        go build -tags ios -ldflags=-w -trimpath -v -o "$BUILD_ROOT/libwg-go-$ARCH.a" -buildmode c-archive
    rm -f "$BUILD_ROOT/libwg-go-$ARCH.h"
    LIPO_INPUT_LIBS+=("$BUILD_ROOT/libwg-go-$ARCH.a")
}

build_arch x86_64 amd64 iphonesimulator
#build_arch arm64 arm64 iphoneos
#build_arch armv7 arm iphoneos

# Create the fat static library including all architectures
LIPO="${LIPO:-lipo}"
"$LIPO" -create -output "$ARTIFACT" "${LIPO_INPUT_LIBS[@]}"
