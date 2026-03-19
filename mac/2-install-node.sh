#!/bin/bash

# ============================================
# 🦞 Node.js 安装脚本 (macOS)
# 自动检测并安装 Node.js 24
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 Node.js 安装脚本 (macOS)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# 检查当前 Node.js 版本
check_current_node() {
    if command -v node &> /dev/null; then
        local version=$(node -v)
        local major=$(echo $version | sed 's/v\([0-9]*\).*/\1/')
        echo $major
    else
        echo "0"
    fi
}

# 使用 Homebrew 安装 Node.js
install_via_homebrew() {
    print_step "使用 Homebrew 安装 Node.js 24"

    if ! command -v brew &> /dev/null; then
        print_info "Homebrew 未安装，正在安装..."

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [ $? -ne 0 ]; then
            print_error "Homebrew 安装失败"
            return 1
        fi

        # 添加到 PATH
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    print_info "正在更新 Homebrew..."
    brew update

    print_info "正在安装 Node.js..."
    brew install node

    if [ $? -eq 0 ]; then
        print_ok "Node.js 安装成功"
        return 0
    else
        print_error "Node.js 安装失败"
        return 1
    fi
}

# 使用官方安装包安装
install_via_official() {
    print_step "下载官方安装包"

    local download_url="https://nodejs.org/dist/v24.0.0/node-v24.0.0.pkg"

    # 检测芯片类型
    if [[ $(uname -m) == "arm64" ]]; then
        download_url="https://nodejs.org/dist/v24.0.0/node-v24.0.0.pkg"
    fi

    print_info "下载地址: $download_url"
    print_info "正在下载..."

    local tmp_file="/tmp/node-installer.pkg"

    curl -fsSL "$download_url" -o "$tmp_file"

    if [ $? -ne 0 ]; then
        print_error "下载失败"
        print_info "请手动下载: https://nodejs.org"
        return 1
    fi

    print_info "正在安装..."
    print_info "请输入管理员密码以继续安装..."

    sudo installer -pkg "$tmp_file" -target /

    if [ $? -eq 0 ]; then
        print_ok "Node.js 安装成功"
        rm -f "$tmp_file"
        return 0
    else
        print_error "安装失败"
        rm -f "$tmp_file"
        return 1
    fi
}

# 使用 nvm 安装（推荐给开发者）
install_via_nvm() {
    print_step "使用 nvm 安装 Node.js 24"

    if [ ! -d "$HOME/.nvm" ]; then
        print_info "nvm 未安装，正在安装..."

        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

        if [ $? -ne 0 ]; then
            print_error "nvm 安装失败"
            return 1
        fi

        # 加载 nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    else
        # 加载 nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fi

    print_info "正在安装 Node.js 24..."
    if nvm install 24 && nvm use 24 && nvm alias default 24; then
        print_ok "Node.js 安装成功"

        # 确保当前 shell 能使用 node
        export PATH="$HOME/.nvm/versions/node/$(nvm current)/bin:$PATH"

        return 0
    else
        print_error "Node.js 安装失败"
        return 1
    fi
}

# 验证安装
verify_installation() {
    print_step "验证安装"

    # 重新加载 shell 环境
    if [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    elif [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi

    if command -v node &> /dev/null; then
        local version=$(node -v)
        local npm_version=$(npm -v)

        print_ok "Node.js 版本: $version"
        print_ok "npm 版本: $npm_version"

        local major=$(echo $version | sed 's/v\([0-9]*\).*/\1/')
        if [ $major -ge 22 ]; then
            print_ok "版本满足要求"
            return 0
        else
            print_error "版本仍然过低"
            return 1
        fi
    else
        print_error "Node.js 未找到，可能需要重启终端"
        print_info "请关闭当前终端窗口，重新打开后再试"
        return 1
    fi
}

# 主函数
main() {
    clear
    print_header

    # 检查当前版本
    local current_major=$(check_current_node)

    if [ $current_major -ge 24 ]; then
        print_ok "Node.js 24 已安装 ($(node -v))"
        print_info "无需重复安装"
        exit 0
    elif [ $current_major -ge 22 ]; then
        print_info "当前 Node.js 版本: $(node -v)"
        print_info "版本满足最低要求，建议升级到 24"
        echo ""
        read -p "是否升级到 Node.js 24? (y/n): " choice
        if [[ $choice != "y" && $choice != "Y" ]]; then
            print_info "跳过安装"
            exit 0
        fi
    else
        print_info "当前 Node.js 版本过低或未安装"
    fi

    # 选择安装方式
    echo ""
    echo -e "${YELLOW}请选择安装方式：${NC}"
    echo "  1) Homebrew (推荐，最简单)"
    echo "  2) 官方安装包"
    echo "  3) nvm (适合开发者)"
    echo ""
    read -p "请输入选项 (1-3): " choice

    case $choice in
        1)
            install_via_homebrew
            ;;
        2)
            install_via_official
            ;;
        3)
            install_via_nvm
            ;;
        *)
            print_error "无效选项"
            exit 1
            ;;
    esac

    # 验证安装
    verify_installation

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Node.js 安装完成${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "下一步: 运行 ${YELLOW}3-install-git.sh${NC} 安装/配置 Git"
    echo ""
}

# 运行
main
下一步: 运行 ${YELLOW}3-install-git.sh${NC} 安装/配置 Git"
    echo ""
}

# 运行
main
