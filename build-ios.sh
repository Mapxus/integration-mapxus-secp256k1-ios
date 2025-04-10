#!/bin/bash

# 设置环境变量
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export SDK_DIR="$DEVELOPER_DIR/Platforms/iPhoneOS.platform/Developer/SDKs"
export SIMULATOR_SDK_DIR="$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform/Developer/SDKs"
export TOOLCHAIN_DIR="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"

# 签发证书
CER_SHA_1='3237CC2300F47D6DF17367B086B164D21D7AB28B'

# 输出目录
OUTPUT_DIR="ios-build"
RELEASE_DIR="$OUTPUT_DIR/release"
FRAMEWORK_NAME="Secp256k1"

# 清理之前的构建
rm -rf "$OUTPUT_DIR"

# 创建输出目录
mkdir -p "$OUTPUT_DIR/frameworks/static"
mkdir -p "$OUTPUT_DIR/frameworks/dynamic"
mkdir -p "$RELEASE_DIR/static"
mkdir -p "$RELEASE_DIR/dynamic"

# 构建函数
build_for_platform() {
    local PLATFORM=$1
    local ARCH=$2
    local SDK_PATH=$3
    local HOST=$4
    local OUTPUT_PATH="$OUTPUT_DIR/frameworks/$5/$6"
    local LIB_TYPE=$7  # "static" or "dynamic"
    
    echo "Building for $ARCH ($PLATFORM) - $LIB_TYPE library"
    
    # 设置编译标志
    local CFLAGS="-arch $ARCH -isysroot $SDK_PATH -mios-version-min=9.0 -Os -fvisibility=hidden -ffunction-sections -fdata-sections"
    local LDFLAGS="-isysroot $SDK_PATH -dead_strip"
    
    if [ "$PLATFORM" = "iphonesimulator" ]; then
        CFLAGS="$CFLAGS -target $ARCH-apple-ios-simulator"
        LDFLAGS="$LDFLAGS -target $ARCH-apple-ios-simulator"
        HOST="$ARCH-apple-darwin"
    fi
    
    # 清理之前的构建
    make clean || true
    
    # 配置和构建
    ./configure \
        --host=$HOST \
        --enable-module-ecdh \
        --enable-module-recovery \
        --enable-module-extrakeys \
        --enable-module-schnorrsig \
        --enable-module-musig \
        --enable-module-ellswift \
        --disable-tests \
        --disable-benchmark \
        --disable-exhaustive-tests \
        --disable-examples \
        --enable-static \
        --disable-shared \
        --prefix="$PWD/$OUTPUT_DIR" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS"
    
    make -j$(sysctl -n hw.ncpu)

    # 创建framework目录结构
    mkdir -p "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers"
    mkdir -p "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Modules"
    
    # 复制头文件到Headers目录
    cp include/secp256k1.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_ecdh.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_recovery.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_extrakeys.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_schnorrsig.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_musig.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    cp include/secp256k1_ellswift.h "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Headers/"
    
    # 复制PrivacyInfo.xcprivacy到framework目录
    if [ -f "build-files/PrivacyInfo.xcprivacy" ]; then
        cp build-files/PrivacyInfo.xcprivacy "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/"
    fi
    
    # 创建模块映射文件
    cat > "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Modules/module.modulemap" << EOF
framework module Secp256k1 {
    umbrella header "secp256k1.h"
    header "secp256k1_ecdh.h"
    header "secp256k1_recovery.h"
    header "secp256k1_extrakeys.h"
    header "secp256k1_schnorrsig.h"
    header "secp256k1_musig.h"
    header "secp256k1_ellswift.h"
    
    export *
    module * { export * }
}
EOF
    
    # 生成所有符号的列表文件
    if [ "$PLATFORM" = "iphoneos" ]; then
        $TOOLCHAIN_DIR/nm -g .libs/libsecp256k1.a | grep " T " | cut -d ' ' -f 3 > "$OUTPUT_DIR/exported_symbols.txt"
        # 添加额外的必要符号
        echo "_secp256k1_context_create" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_context_destroy" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_ec_pubkey_create" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_ec_pubkey_parse" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_ec_pubkey_serialize" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_ec_seckey_verify" >> "$OUTPUT_DIR/exported_symbols.txt"
        echo "_secp256k1_ecdh" >> "$OUTPUT_DIR/exported_symbols.txt"
    fi
    
    local LIB_FILE=".libs/libsecp256k1.a"
    
    if [ -f "$LIB_FILE" ]; then
        if [ "$LIB_TYPE" = "dynamic" ]; then
            # 创建动态库
            if [ "$PLATFORM" = "iphoneos" ]; then
                $TOOLCHAIN_DIR/clang -dynamiclib -arch $ARCH \
                    -isysroot $SDK_PATH \
                    -install_name @rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME \
                    -dead_strip \
                    -mios-version-min=9.0 \
                    -compatibility_version 1.0.0 -current_version 1.0.0 \
                    -exported_symbols_list "$OUTPUT_DIR/exported_symbols.txt" \
                    -o "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
                    $LIB_FILE
            else
                $TOOLCHAIN_DIR/clang -dynamiclib -arch $ARCH \
                    -isysroot $SDK_PATH \
                    -install_name @rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME \
                    -dead_strip \
                    -mios-version-min=9.0 \
                    -target $ARCH-apple-ios-simulator \
                    -compatibility_version 1.0.0 -current_version 1.0.0 \
                    -exported_symbols_list "$OUTPUT_DIR/exported_symbols.txt" \
                    -o "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
                    $LIB_FILE
            fi
        else
            # 创建静态库
            cp $LIB_FILE "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
        fi
    else
        echo "Error: Library not found at $LIB_FILE"
        exit 1
    fi
    
    # 创建Info.plist
    cat > "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>org.bitcoin.secp256k1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>9.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>${PLATFORM}</string>
    </array>
</dict>
</plist>
EOF

    # 检查库是否包含所需的符号
    if [ "$PLATFORM" = "iphoneos" ]; then
        echo "Checking symbols in the generated library..."
        $TOOLCHAIN_DIR/nm -gU "$OUTPUT_PATH/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" | grep "secp256k1_"
    fi
    
    echo "✅ Successfully built for $ARCH ($PLATFORM) - $LIB_TYPE library"
}

# 构建静态库版本
echo "Building static library version..."
build_for_platform "iphoneos" "arm64" "$SDK_DIR/iPhoneOS18.4.sdk" "arm64-apple-ios" "static" "ios-arm64" "static"
build_for_platform "iphonesimulator" "arm64" "$SIMULATOR_SDK_DIR/iPhoneSimulator18.4.sdk" "arm64-apple-ios-simulator" "static" "ios-arm64-simulator" "static"
build_for_platform "iphonesimulator" "x86_64" "$SIMULATOR_SDK_DIR/iPhoneSimulator18.4.sdk" "x86_64-apple-ios-simulator" "static" "ios-x86_64-simulator" "static"

# 合并静态库模拟器架构
echo "Merging static simulator architectures..."
mkdir -p "$OUTPUT_DIR/frameworks/static/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework"
cp -R "$OUTPUT_DIR/frameworks/static/ios-arm64-simulator/$FRAMEWORK_NAME.framework/"* "$OUTPUT_DIR/frameworks/static/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework/"
lipo -create \
    "$OUTPUT_DIR/frameworks/static/ios-arm64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    "$OUTPUT_DIR/frameworks/static/ios-x86_64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    -output "$OUTPUT_DIR/frameworks/static/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"

# 创建静态库XCFramework
echo "Creating static XCFramework..."
xcodebuild -create-xcframework \
    -framework "$OUTPUT_DIR/frameworks/static/ios-arm64/$FRAMEWORK_NAME.framework" \
    -framework "$OUTPUT_DIR/frameworks/static/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework" \
    -output "$RELEASE_DIR/static/$FRAMEWORK_NAME.xcframework"

# 签名静态库XCFramework
echo "Signing static XCFramework..."
codesign --timestamp -v --sign ${CER_SHA_1} "$RELEASE_DIR/static/$FRAMEWORK_NAME.xcframework"

# 构建动态库版本
echo "Building dynamic library version..."
build_for_platform "iphoneos" "arm64" "$SDK_DIR/iPhoneOS18.4.sdk" "arm64-apple-ios" "dynamic" "ios-arm64" "dynamic"
build_for_platform "iphonesimulator" "arm64" "$SIMULATOR_SDK_DIR/iPhoneSimulator18.4.sdk" "arm64-apple-ios-simulator" "dynamic" "ios-arm64-simulator" "dynamic"
build_for_platform "iphonesimulator" "x86_64" "$SIMULATOR_SDK_DIR/iPhoneSimulator18.4.sdk" "x86_64-apple-ios-simulator" "dynamic" "ios-x86_64-simulator" "dynamic"

# 合并动态库模拟器架构
echo "Merging dynamic simulator architectures..."
mkdir -p "$OUTPUT_DIR/frameworks/dynamic/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework"
cp -R "$OUTPUT_DIR/frameworks/dynamic/ios-arm64-simulator/$FRAMEWORK_NAME.framework/"* "$OUTPUT_DIR/frameworks/dynamic/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework/"
lipo -create \
    "$OUTPUT_DIR/frameworks/dynamic/ios-arm64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    "$OUTPUT_DIR/frameworks/dynamic/ios-x86_64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    -output "$OUTPUT_DIR/frameworks/dynamic/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"

# 创建动态库XCFramework
echo "Creating dynamic XCFramework..."
xcodebuild -create-xcframework \
    -framework "$OUTPUT_DIR/frameworks/dynamic/ios-arm64/$FRAMEWORK_NAME.framework" \
    -framework "$OUTPUT_DIR/frameworks/dynamic/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework" \
    -output "$RELEASE_DIR/dynamic/$FRAMEWORK_NAME.xcframework"

# 签名动态库XCFramework
echo "Signing dynamic XCFramework..."
codesign --timestamp -v --sign ${CER_SHA_1} "$RELEASE_DIR/dynamic/$FRAMEWORK_NAME.xcframework"

# 复制文档文件到release目录
echo "Copying documentation files..."
if [ -f "build-files/README.md" ]; then
    cp build-files/README.md "$RELEASE_DIR/"
fi
if [ -f "build-files/LICENSE" ]; then
    cp build-files/LICENSE "$RELEASE_DIR/"
fi

echo "✅ Static XCFramework created and signed at: $RELEASE_DIR/static/$FRAMEWORK_NAME.xcframework"
echo "✅ Dynamic XCFramework created and signed at: $RELEASE_DIR/dynamic/$FRAMEWORK_NAME.xcframework"
