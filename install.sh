#!/bin/bash

# Portable Valgrind for macOS - Installation Script
# This script downloads and installs the cross-compiled Valgrind build

set -e  # Exit on any error

# Configuration
VALGRIND_URL="https://github.com/TheValiant/valgrind/releases/download/3.25.1/valgrind_3.25.1.tar.gz"
INSTALL_DIR="$HOME/bin/valgrind"
TEMP_DIR="/tmp/valgrind_install_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Add PATH to shell config if not already present
add_to_path() {
    local shell_config="$1"
    local path_line="export PATH=\"\$HOME/bin/valgrind:\$PATH\""
    
    if [[ -f "$shell_config" ]]; then
        if grep -q "bin/valgrind" "$shell_config"; then
            log_info "PATH already configured in $shell_config"
            return 0
        fi
    fi
    
    log_info "Adding PATH to $shell_config"
    echo "" >> "$shell_config"
    echo "# Added by Valgrind installer" >> "$shell_config"
    echo "$path_line" >> "$shell_config"
    log_success "PATH added to $shell_config"
}

# Main installation function
main() {
    log_info "Starting Portable Valgrind installation..."
    
    # Check for required tools
    if ! command_exists curl && ! command_exists wget; then
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if ! command_exists tar; then
        log_error "tar command not found. Please install tar."
        exit 1
    fi
    
    # Create temporary directory
    log_info "Creating temporary directory: $TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Ensure cleanup on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Check if already installed and up to date
    if [[ -f "$INSTALL_DIR/valgrind" ]]; then
        log_warning "Valgrind already installed at $INSTALL_DIR"
        log_info "Proceeding with reinstallation to ensure latest version..."
    fi
    
    # Create installation directory
    log_info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Download the release
    log_info "Downloading Valgrind from: $VALGRIND_URL"
    cd "$TEMP_DIR"
    
    if command_exists curl; then
        curl -L -o valgrind.tar.gz "$VALGRIND_URL"
    else
        wget -O valgrind.tar.gz "$VALGRIND_URL"
    fi
    
    if [[ ! -f "valgrind.tar.gz" ]]; then
        log_error "Failed to download Valgrind"
        exit 1
    fi
    
    log_success "Download completed"
    
    # Extract the archive
    log_info "Extracting Valgrind to $INSTALL_DIR"
    tar -xzf valgrind.tar.gz -C "$INSTALL_DIR" --strip-components=1
    
    # Verify installation
    if [[ -f "$INSTALL_DIR/valgrind" ]]; then
        log_success "Valgrind extracted successfully"
        
        # Make sure valgrind executable has proper permissions
        chmod +x "$INSTALL_DIR/valgrind"
        
        # Make preload libraries executable
        find "$INSTALL_DIR" -name "*.so" -exec chmod +x {} \;
        
        log_info "File permissions updated"
    else
        log_error "Installation failed - valgrind executable not found"
        exit 1
    fi
    
    # Configure shell PATH
    log_info "Configuring shell PATH..."
    
    # Add to .bashrc if it exists or if bash is the current shell
    if [[ -f "$HOME/.bashrc" ]] || [[ "$SHELL" == */bash ]]; then
        add_to_path "$HOME/.bashrc"
    fi
    
    # Add to .zshrc if it exists or if zsh is the current shell
    if [[ -f "$HOME/.zshrc" ]] || [[ "$SHELL" == */zsh ]]; then
        add_to_path "$HOME/.zshrc"
    fi
    
    # Add to current session PATH if not already there
    if [[ ":$PATH:" != *":$HOME/bin/valgrind:"* ]]; then
        export PATH="$HOME/bin/valgrind:$PATH"
        log_info "PATH updated for current session"
    fi
    
    # Final verification
    log_info "Verifying installation..."
    
    if [[ -x "$INSTALL_DIR/valgrind" ]]; then
        local version_info
        if version_info=$(file "$INSTALL_DIR/valgrind" 2>/dev/null); then
            log_success "Valgrind installation completed successfully!"
            log_info "Installed at: $INSTALL_DIR"
            log_info "Binary info: $version_info"
        else
            log_success "Valgrind installation completed!"
            log_info "Installed at: $INSTALL_DIR"
        fi
        
        echo ""
        log_info "🎉 Installation Summary:"
        echo "   • Valgrind installed to: $INSTALL_DIR"
        echo "   • PATH configured in shell profiles"
        echo "   • Ready to use with: valgrind --tool=memcheck your_program"
        echo ""
        log_warning "⚠️  Please restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc) to use valgrind command"
        
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Run main function
main "$@"
