#!/bin/bash
#
# avionics_bootloader_build.sh
# Build script for custom avionics bootloader
# Author: Avionics Embedded Expert
# Version: 1.0
# Date: 2024
#
# This script builds a custom bootloader for avionics systems based on U-Boot
# with secure boot and hardware-specific optimizations for Intel SOM platforms.

set -e  # Exit on any error

# Configuration variables
BOOTLOADER_NAME="avionics-bootloader"
TARGET_ARCH="x86_64"
CROSS_COMPILE=""
BUILD_DIR="build"
SOURCE_DIR="src"
CONFIG_FILE="avionics_defconfig"
SECURE_BOOT_ENABLED=true
TPM_SUPPORT=true
VERIFIED_BOOT=true

# Hardware platform configuration
INTEL_SOM_2533=true
ADVANTECH_SOM_DB2510=true
ALDER_LAKE_N_SUPPORT=true

# Build options
OPTIMIZATION_LEVEL="O2"
DEBUG_SYMBOLS=false
VERBOSE_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking build prerequisites..."
    
    # Check for required tools
    local required_tools=("gcc" "make" "git" "python3" "dtc" "openssl")
    
    if [ "$TARGET_ARCH" = "aarch64" ]; then
        required_tools+=("aarch64-linux-gnu-gcc")
        CROSS_COMPILE="aarch64-linux-gnu-"
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    # Check for U-Boot source
    if [ ! -d "u-boot" ]; then
        print_info "Cloning U-Boot source..."
        git clone https://github.com/u-boot/u-boot.git
        cd u-boot
        git checkout v2024.01  # Use stable version
        cd ..
    fi
    
    print_success "Prerequisites check completed"
}

# Function to create build directory structure
setup_build_environment() {
    print_info "Setting up build environment..."
    
    mkdir -p "$BUILD_DIR"/{config,keys,images,logs}
    mkdir -p "$SOURCE_DIR"/{patches,configs,scripts}
    
    # Set environment variables
    export ARCH="$TARGET_ARCH"
    export CROSS_COMPILE="$CROSS_COMPILE"
    export KBUILD_OUTPUT="$(pwd)/$BUILD_DIR"
    
    if [ "$VERBOSE_BUILD" = true ]; then
        export V=1
    fi
    
    print_success "Build environment setup completed"
}

# Function to generate device tree for avionics platforms
generate_device_tree() {
    print_info "Generating device tree for avionics platforms..."
    
    cat > "$SOURCE_DIR/avionics-platform.dts" << 'EOF'
/dts-v1/;

/ {
    model = "Avionics Platform";
    compatible = "avionics,intel-som";
    
    #address-cells = <1>;
    #size-cells = <1>;
    
    chosen {
        bootargs = "console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rw";
        stdout-path = &uart0;
    };
    
    memory@0 {
        device_type = "memory";
        reg = <0x00000000 0x40000000>; /* 1GB RAM */
    };
    
    cpus {
        #address-cells = <1>;
        #size-cells = <0>;
        
        cpu@0 {
            device_type = "cpu";
            compatible = "intel,alder-lake-n";
            reg = <0>;
            clock-frequency = <2400000000>; /* 2.4 GHz */
        };
    };
    
    soc {
        #address-cells = <1>;
        #size-cells = <1>;
        compatible = "simple-bus";
        ranges;
        
        uart0: serial@3f8 {
            compatible = "intel,8250";
            reg = <0x3f8 0x8>;
            interrupts = <4>;
            clock-frequency = <1843200>;
            status = "okay";
        };
        
        pci@0 {
            compatible = "intel,alder-lake-pci";
            device_type = "pci";
            #address-cells = <3>;
            #size-cells = <2>;
            reg = <0x0 0x10000000>;
            ranges = <0x02000000 0x0 0x20000000 0x20000000 0x0 0x10000000>;
            
            /* Intel UHD Graphics */
            gpu@2,0 {
                compatible = "intel,alder-lake-gpu";
                reg = <0x1000 0x0 0x0 0x0 0x0>;
                interrupts = <16>;
            };
        };
        
        ethernet@0 {
            compatible = "intel,i210";
            reg = <0x0 0x1000>;
            interrupts = <17>;
            status = "okay";
        };
        
        usb@1 {
            compatible = "intel,xhci";
            reg = <0x1000 0x1000>;
            interrupts = <18>;
            status = "okay";
        };
    };
    
    avionics {
        compatible = "avionics,peripherals";
        
        /* Avionics-specific hardware */
        can-controllers {
            can0 {
                compatible = "avionics,can-controller";
                reg = <0x40000000 0x1000>;
                interrupts = <20>;
                status = "okay";
            };
            
            can1 {
                compatible = "avionics,can-controller";
                reg = <0x40001000 0x1000>;
                interrupts = <21>;
                status = "okay";
            };
        };
        
        arinc429 {
            compatible = "avionics,arinc429";
            reg = <0x40002000 0x1000>;
            interrupts = <22>;
            status = "okay";
        };
        
        mil-std-1553 {
            compatible = "avionics,mil-std-1553";
            reg = <0x40003000 0x1000>;
            interrupts = <23>;
            status = "okay";
        };
    };
};
EOF
    
    # Compile device tree
    dtc -I dts -O dtb -o "$BUILD_DIR/avionics-platform.dtb" "$SOURCE_DIR/avionics-platform.dts"
    
    print_success "Device tree generation completed"
}

# Function to create custom U-Boot configuration
create_bootloader_config() {
    print_info "Creating custom bootloader configuration..."
    
    cat > "$SOURCE_DIR/configs/$CONFIG_FILE" << 'EOF'
# Avionics Bootloader Configuration
CONFIG_TARGET_X86=y
CONFIG_VENDOR_AVIONICS=y
CONFIG_SYS_BOARD="avionics-platform"
CONFIG_SYS_CONFIG_NAME="avionics_platform"

# Boot options
CONFIG_BOOTDELAY=3
CONFIG_AUTOBOOT_KEYED=y
CONFIG_AUTOBOOT_PROMPT="Press SPACE to abort autoboot in %d seconds\n"
CONFIG_AUTOBOOT_DELAY_STR=" "
CONFIG_AUTOBOOT_STOP_STR="s"

# Memory configuration
CONFIG_SYS_SDRAM_BASE=0x00000000
CONFIG_SYS_TEXT_BASE=0x01000000
CONFIG_SYS_LOAD_ADDR=0x02000000

# Storage support
CONFIG_MMC=y
CONFIG_MMC_SDHCI=y
CONFIG_SATA_SIL=y
CONFIG_SCSI=y
CONFIG_USB=y
CONFIG_USB_STORAGE=y

# Network support
CONFIG_NET=y
CONFIG_NETDEVICES=y
CONFIG_E1000=y
CONFIG_CMD_NET=y
CONFIG_CMD_DHCP=y
CONFIG_CMD_PING=y

# Secure boot features
CONFIG_FIT=y
CONFIG_FIT_SIGNATURE=y
CONFIG_RSA=y
CONFIG_SPL_RSA=y
CONFIG_FIT_VERBOSE=y
CONFIG_OF_CONTROL=y
CONFIG_OF_EMBED=y

# TPM support
CONFIG_TPM=y
CONFIG_TPM_TIS_LPC=y
CONFIG_CMD_TPM=y
CONFIG_CMD_TPM_TEST=y

# Crypto support
CONFIG_SHA1=y
CONFIG_SHA256=y
CONFIG_MD5=y

# Command line interface
CONFIG_CMDLINE_EDITING=y
CONFIG_AUTO_COMPLETE=y
CONFIG_SYS_LONGHELP=y
CONFIG_SYS_PROMPT="Avionics> "

# Environment storage
CONFIG_ENV_IS_IN_MMC=y
CONFIG_ENV_SIZE=0x4000
CONFIG_ENV_OFFSET=0x100000

# Debug options
CONFIG_CONSOLE_MUX=y
CONFIG_SYS_CONSOLE_IS_IN_ENV=y
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_BASE=0x3f8
CONFIG_DEBUG_UART_CLOCK=1843200

# Avionics-specific features
CONFIG_AVIONICS_STARTUP_CHECK=y
CONFIG_AVIONICS_SELF_TEST=y
CONFIG_AVIONICS_WATCHDOG=y
CONFIG_AVIONICS_REDUNDANCY=y
EOF
    
    # Copy configuration to U-Boot configs directory
    cp "$SOURCE_DIR/configs/$CONFIG_FILE" "u-boot/configs/"
    
    print_success "Bootloader configuration created"
}

# Function to apply avionics-specific patches
apply_patches() {
    print_info "Applying avionics-specific patches..."
    
    cd u-boot
    
    # Create patch for avionics startup sequence
    cat > "../$SOURCE_DIR/patches/0001-avionics-startup.patch" << 'EOF'
--- a/common/board_f.c
+++ b/common/board_f.c
@@ -1000,6 +1000,10 @@ static const init_fnc_t init_sequence_f[] = {
 #ifdef CONFIG_POST
 	post_run,
 #endif
+#ifdef CONFIG_AVIONICS_STARTUP_CHECK
+	avionics_startup_check,
+	avionics_self_test,
+#endif
 	INIT_FUNC_WATCHDOG_RESET
 	/*
 	 * Now that we have DRAM mapped and working, we can
EOF
    
    # Apply patches
    if [ -d "../$SOURCE_DIR/patches" ]; then
        for patch in "../$SOURCE_DIR/patches"/*.patch; do
            if [ -f "$patch" ]; then
                print_info "Applying patch: $(basename "$patch")"
                git apply "$patch" || print_warning "Failed to apply patch: $(basename "$patch")"
            fi
        done
    fi
    
    cd ..
    
    print_success "Patches applied"
}

# Function to generate secure boot keys
generate_keys() {
    if [ "$SECURE_BOOT_ENABLED" = true ]; then
        print_info "Generating secure boot keys..."
        
        # Create RSA key pair for FIT image signing
        openssl genrsa -out "$BUILD_DIR/keys/key.key" 2048
        openssl req -batch -new -x509 -key "$BUILD_DIR/keys/key.key" \
                   -out "$BUILD_DIR/keys/key.crt" -days 365 \
                   -subj "/C=US/ST=State/L=City/O=Avionics/OU=Security/CN=BootLoader"
        
        # Generate device tree blob with public key
        cat > "$BUILD_DIR/keys/keys.dts" << 'EOF'
/dts-v1/;

/ {
    signature {
        key-avionics {
            required = "image";
            algo = "sha256,rsa2048";
            key-name-hint = "avionics";
        };
    };
};
EOF
        
        dtc -I dts -O dtb -o "$BUILD_DIR/keys/keys.dtb" "$BUILD_DIR/keys/keys.dts"
        
        print_success "Secure boot keys generated"
    fi
}

# Function to build the bootloader
build_bootloader() {
    print_info "Building avionics bootloader..."
    
    cd u-boot
    
    # Configure build
    make O="../$BUILD_DIR" "$CONFIG_FILE"
    
    # Build bootloader
    make O="../$BUILD_DIR" -j$(nproc) 2>&1 | tee "../$BUILD_DIR/logs/build.log"
    
    # Check build success
    if [ ! -f "../$BUILD_DIR/u-boot.bin" ]; then
        print_error "Bootloader build failed"
        exit 1
    fi
    
    cd ..
    
    # Create final bootloader image
    cp "$BUILD_DIR/u-boot.bin" "$BUILD_DIR/images/$BOOTLOADER_NAME.bin"
    
    print_success "Bootloader build completed"
}

# Function to create bootable image
create_bootable_image() {
    print_info "Creating bootable image..."
    
    # Create bootloader with environment
    cat "$BUILD_DIR/images/$BOOTLOADER_NAME.bin" > "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin"
    
    # Add device tree if available
    if [ -f "$BUILD_DIR/avionics-platform.dtb" ]; then
        cat "$BUILD_DIR/avionics-platform.dtb" >> "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin"
    fi
    
    # Create flash layout description
    cat > "$BUILD_DIR/images/flash-layout.txt" << EOF
Flash Layout for Avionics Bootloader:
=====================================

0x00000000 - 0x000FFFFF: Bootloader (1MB)
0x00100000 - 0x00103FFF: Environment (16KB)
0x00104000 - 0x00107FFF: Device Tree (16KB)
0x00108000 - 0x0010FFFF: Reserved (32KB)
0x00110000 - 0x00FFFFFF: Available for kernel/recovery

Total bootloader size: $(stat -c%s "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin") bytes
Maximum allowed size: 1048576 bytes (1MB)
EOF
    
    # Generate checksums
    md5sum "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin" > "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin.md5"
    sha256sum "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin" > "$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin.sha256"
    
    print_success "Bootable image created"
}

# Function to run post-build verification
verify_build() {
    print_info "Running post-build verification..."
    
    local image="$BUILD_DIR/images/$BOOTLOADER_NAME-with-env.bin"
    local max_size=1048576  # 1MB
    local actual_size=$(stat -c%s "$image")
    
    # Check image size
    if [ "$actual_size" -gt "$max_size" ]; then
        print_error "Bootloader image too large: $actual_size bytes (max: $max_size bytes)"
        exit 1
    fi
    
    # Verify checksums
    cd "$BUILD_DIR/images"
    md5sum -c "$BOOTLOADER_NAME-with-env.bin.md5"
    sha256sum -c "$BOOTLOADER_NAME-with-env.bin.sha256"
    cd - > /dev/null
    
    print_success "Build verification completed"
}

# Function to display build summary
display_summary() {
    print_info "Build Summary"
    echo "============="
    echo "Bootloader: $BOOTLOADER_NAME"
    echo "Target Architecture: $TARGET_ARCH"
    echo "Cross Compile: ${CROSS_COMPILE:-native}"
    echo "Secure Boot: $SECURE_BOOT_ENABLED"
    echo "TPM Support: $TPM_SUPPORT"
    echo "Output Directory: $BUILD_DIR/images"
    echo ""
    echo "Generated Files:"
    ls -la "$BUILD_DIR/images/"
    echo ""
    print_success "Avionics bootloader build completed successfully!"
}

# Main build function
main() {
    print_info "Starting avionics bootloader build process..."
    
    check_prerequisites
    setup_build_environment
    generate_device_tree
    create_bootloader_config
    apply_patches
    generate_keys
    build_bootloader
    create_bootable_image
    verify_build
    display_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target-arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        --cross-compile)
            CROSS_COMPILE="$2"
            shift 2
            ;;
        --debug)
            DEBUG_SYMBOLS=true
            shift
            ;;
        --verbose)
            VERBOSE_BUILD=true
            shift
            ;;
        --no-secure-boot)
            SECURE_BOOT_ENABLED=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --target-arch ARCH    Target architecture (default: x86_64)"
            echo "  --cross-compile PREFIX Cross-compilation prefix"
            echo "  --debug               Enable debug symbols"
            echo "  --verbose             Enable verbose build output"
            echo "  --no-secure-boot      Disable secure boot features"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main build process
main