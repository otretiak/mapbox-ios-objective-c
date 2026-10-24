#!/bin/zsh
# Builds MapboxMapObjC.xcframework with swiftc directly against the official Mapbox
# direct-download XCFrameworks (the same binaries the .NET packages embed).
#
# usage: scripts/build-xcframework-swiftc.sh <path-to-unzipped-MapboxMaps.zip>/artifacts [version]
set -euo pipefail

SDK_ARTIFACTS=${1:?path to the official SDK artifacts folder (contains MapboxMaps.xcframework)}
VERSION=${2:-11.33.0}
MIN_IOS=15.0
ROOT=${0:A:h:h}
OUT=$ROOT/.build/swiftc
MODULE=MapboxMapObjC
SRCS=(${(f)"$(find $ROOT/$MODULE -name '*.swift' | sort)"})

rm -rf $OUT && mkdir -p $OUT/mc

build_slice() {
    local sdk=$1 triple=$2 slice=$3
    local sdkpath=$(xcrun --sdk $sdk --show-sdk-path)
    local dir=$OUT/$triple
    mkdir -p $dir
    local fw=()
    for f in MapboxMaps MapboxCoreMaps MapboxCommon Turf; do fw+=(-F $SDK_ARTIFACTS/$f.xcframework/$slice); done
    echo "==> $triple"
    xcrun swiftc -sdk $sdkpath -target $triple -swift-version 5 -O -whole-module-optimization \
        -module-name $MODULE -parse-as-library -enable-library-evolution \
        -emit-library -emit-module -emit-module-path $dir/$MODULE.swiftmodule \
        -emit-module-interface-path $dir/$MODULE.swiftinterface \
        -emit-private-module-interface-path $dir/$MODULE.private.swiftinterface \
        -emit-objc-header -emit-objc-header-path $dir/$MODULE-Swift.h \
        -module-cache-path $OUT/mc $fw \
        -framework MapboxMaps -framework MapboxCoreMaps -framework MapboxCommon -framework Turf \
        -Xlinker -install_name -Xlinker @rpath/$MODULE.framework/$MODULE \
        -Xlinker -rpath -Xlinker @executable_path/Frameworks -Xlinker -rpath -Xlinker @loader_path/Frameworks \
        -g -debug-info-format=dwarf \
        -o $dir/$MODULE $SRCS
}

assemble() {
    local name=$1; shift
    local fwdir=$OUT/$name/$MODULE.framework
    mkdir -p $fwdir/Headers $fwdir/Modules/$MODULE.swiftmodule
    local first=$1
    if (( $# > 1 )); then
        lipo -create $(for t in $@; do echo $OUT/$t/$MODULE; done) -output $fwdir/$MODULE
    else
        cp $OUT/$first/$MODULE $fwdir/$MODULE
    fi
    cp $ROOT/$MODULE/$MODULE.h $fwdir/Headers/
    if (( $# > 1 )); then
        # Merge per-arch generated headers the way Xcode does for fat frameworks.
        {
            echo "#if 0"; echo "#elif defined(__arm64__) && __arm64__"; cat $OUT/arm64-apple-ios$MIN_IOS-simulator/$MODULE-Swift.h
            echo "#elif defined(__x86_64__) && __x86_64__"; cat $OUT/x86_64-apple-ios$MIN_IOS-simulator/$MODULE-Swift.h
            echo "#else"; echo "#error unsupported Swift architecture"; echo "#endif"
        } > $fwdir/Headers/$MODULE-Swift.h
    else
        cp $OUT/$first/$MODULE-Swift.h $fwdir/Headers/
    fi
    for t in $@; do
        local mt=${t/$MIN_IOS/}
        for ext in swiftmodule swiftinterface private.swiftinterface swiftdoc; do
            cp $OUT/$t/$MODULE.$ext $fwdir/Modules/$MODULE.swiftmodule/$mt.$ext
        done
    done
    cat > $fwdir/Modules/module.modulemap <<MM
framework module $MODULE {
  umbrella header "$MODULE.h"
  export *

  module * { export * }
}

module $MODULE.Swift {
  header "$MODULE-Swift.h"
  requires objc
}
MM
    cat > $fwdir/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$MODULE</string>
  <key>CFBundleIdentifier</key><string>com.tuyenvuduc.$MODULE</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$MODULE</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$PLATFORM_NAME</string></array>
</dict>
</plist>
PL
    xcrun dsymutil $fwdir/$MODULE -o $OUT/$name/$MODULE.framework.dSYM
    xcrun strip -x -S $fwdir/$MODULE
    codesign --force --sign - --timestamp=none $fwdir
}

build_slice iphoneos arm64-apple-ios$MIN_IOS ios-arm64
build_slice iphonesimulator arm64-apple-ios$MIN_IOS-simulator ios-arm64_x86_64-simulator
build_slice iphonesimulator x86_64-apple-ios$MIN_IOS-simulator ios-arm64_x86_64-simulator

PLATFORM_NAME=iPhoneOS assemble device arm64-apple-ios$MIN_IOS
PLATFORM_NAME=iPhoneSimulator assemble simulator arm64-apple-ios$MIN_IOS-simulator x86_64-apple-ios$MIN_IOS-simulator

rm -rf $OUT/$MODULE.xcframework
xcodebuild -create-xcframework \
    -framework $OUT/device/$MODULE.framework -debug-symbols $OUT/device/$MODULE.framework.dSYM \
    -framework $OUT/simulator/$MODULE.framework -debug-symbols $OUT/simulator/$MODULE.framework.dSYM \
    -output $OUT/$MODULE.xcframework

(cd $OUT && rm -f $MODULE-$VERSION.zip && /usr/bin/zip -qry $MODULE-$VERSION.zip $MODULE.xcframework)
echo "==> $OUT/$MODULE-$VERSION.zip"
