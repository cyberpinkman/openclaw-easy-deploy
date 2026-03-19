#!/bin/bash

# ============================================
# 🦞 Node.js 安装脚本 (macOS)
# 自动检测系统版本并安装合适的 Node.js
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认 Node.js 版本（会被自动调整）
NODE_VERSION="24.14.0"

# 检测系统架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ARCH_NAME="Apple Silicon (M系列芯片)"
else
    ARCH_NAME="Intel (x86_64)"
fi

# 检测 macOS 版本
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "10.0")
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
MACOS_MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)

# Node.js 版本兼容性：
# - Node.js 24.x: macOS 12+ (Monterey)
# - Node.js 22.x: macOS 10.15+ (Catalina)
# - Node.js 18.x: macOS 10.13+ (High Sierra) - 最后支持旧系统的LTS
if [ "$MACOS_MAJOR" -lt 10 ] || ([ "$MACOS_MAJOR" -eq 10 ] && [ "$MACOS_MINOR" -lt 15 ]); then
    # macOS 10.14 或更早
    NODE_VERSION="18.20.8"
    COMPAT_MODE="old"
elif [ "$MACOS_MAJOR" -lt 12 ]; then
    # macOS 10.15-11.x
    NODE_VERSION="22.22.1"
    COMPAT_MODE="medium"
else
    NODE_VERSION="24.14.0"
    COMPAT_MODE="modern"
fi

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 Node.js 安装脚本 (macOS)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}系统架构: ${ARCH_NAME}${NC}"
    echo -e "${BLUE}macOS 版本: ${MACOS_VERSION}${NC}"
    if [ "$COMPAT_MODE" = "old" ]; then
        echo -e "${YELLOW}Node.js 22+ 需要 macOS 10.15+，将安装 18.x LTS${NC}"
        echo -e "${YELLOW}⚠ Node.js 18 将于 2025年4月结束支持，建议升级 macOS${NC}"
    elif [ "$COMPAT_MODE" = "medium" ]; then
        echo -e "${YELLOW}Node.js 24.x 需要 macOS 12+，将安装 22.x LTS${NC}"
    fi
    echo -e "${BLUE}将安装: Node.js ${NODE_VERSION}${NC}"
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

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# 安全读取用户输入
safe_read() {
    local prompt="$1"
    if [ -t 0 ]; then
        read -p "$prompt" choice
    else
        read -p "$prompt" choice < /dev/tty
    fi
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

# 验证 Node.js 是否能正常运行
verify_node_works() {
    print_step "验证 Node.js 运行状态"

    if ! command -v node &> /dev/null; then
        print_error "Node.js 未找到"
        return 1
    fi

    # 测试 node 是否能正常执行
    if node -e "console.log('OK')" 2>/dev/null; then
        print_ok "Node.js 运行正常"
        return 0
    else
        print_error "Node.js 无法运行，可能是架构不匹配"
        
        # 检查 node 二进制的架构
        local node_path=$(which node 2>/dev/null)
        if [ -n "$node_path" ]; then
            local node_arch=$(file "$node_path" 2>/dev/null | grep -o 'arm64\|x86_64' | head -1)
            print_info "Node.js 二进制架构: $node_arch"
            print_info "系统架构: $ARCH"
            
            if [ "$node_arch" != "$ARCH" ] && [ "$node_arch" != "arm64" ] && [ "$ARCH" = "arm64" ]; then
                print_error "架构不匹配! 你安装了 Intel 版 Node.js，但系统是 Apple Silicon"
            elif [ "$node_arch" = "arm64" ] && [ "$ARCH" != "arm64" ]; then
                print_error "架构不匹配! 你安装了 ARM 版 Node.js，但系统是 Intel Mac"
            fi
        fi
        
        return 1
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

    # 禁用 Homebrew 自动更新（brew install 会自动触发 brew update）
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_FROM_API=1

    print_info "正在安装 Node.js..."
    brew install node

    if [ $? -eq 0 ]; then
        # 验证架构和运行状态
        if verify_node_works; then
            print_ok "Node.js 安装成功且运行正常"
            return 0
        else
            print_warn "Homebrew 安装的 Node.js 无法运行，尝试使用官方安装包..."
            return 1
        fi
    else
        print_error "Homebrew 安装失败"
        return 1
    fi
}

# 使用官方安装包安装（.pkg 是通用二进制，不需要架构后缀）
install_via_official() {
    print_step "下载官方安装包"

    # .pkg 是通用安装包，支持 Intel 和 Apple Silicon
    local download_url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"

    print_info "系统架构: $ARCH_NAME"
    print_info "下载地址: $download_url"
    print_info "正在下载..."

    local tmp_file="/tmp/node-installer.pkg"

    if ! curl -fsSL "$download_url" -o "$tmp_file" 2>/dev/null; then
        print_error "下载失败"
        print_info "请手动下载: https://nodejs.org"
        return 1
    fi

    print_info "正在安装..."
    print_info "请输入管理员密码以继续安装..."

    if sudo installer -pkg "$tmp_file" -target / 2>/dev/null; then
        rm -f "$tmp_file"
        
        # 刷新 PATH
        export PATH="/usr/local/bin:$PATH"
        
        # 验证运行状态
        if verify_node_works; then
            print_ok "Node.js 安装成功且运行正常"
            return 0
        else
            print_error "安装成功但 Node.js 无法运行"
            print_error "可能存在系统兼容性问题"
            return 1
        fi
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

        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

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

        # 验证运行状态
        if verify_node_works; then
            print_ok "Node.js 运行正常"
            return 0
        else
            print_warn "nvm 安装的 Node.js 无法运行"
            return 1
        fi
    else
        print_error "Node.js 安装失败"
        return 1
    fi
}

# 验证安装
verify_installation() {
    print_step "最终验证"

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
            
            # 测试运行
            if node -e "console.log('OK')" 2>/dev/null; then
                print_ok "Node.js 运行正常"
                return 0
            else
                print_error "Node.js 无法运行"
                return 1
            fi
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

    if [ $current_major -ge 18 ]; then
        print_info "当前 Node.js 版本: $(node -v 2>/dev/null || echo '未知')"
        
        # 验证是否能运行
        if node -e "console.log('OK')" 2>/dev/null; then
            print_ok "Node.js 运行正常"
            
            # 检查是否满足最低要求
            local required_major=$(echo "$NODE_VERSION" | cut -d. -f1)
            if [ $current_major -ge $required_major ]; then
                print_ok "版本满足要求，无需重复安装"
                exit 0
            fi
            
            print_info "建议升级到 Node.js ${NODE_VERSION}"
            echo ""
            safe_read "是否升级? (y/n): "
            if [[ $choice != "y" && $choice != "Y" ]]; then
                print_info "跳过安装"
                exit 0
            fi
        else
            print_error "Node.js 已安装但无法运行"
            print_warn "可能是架构不匹配或系统版本不兼容"
            print_info "将卸载并重新安装..."
            
            # 尝试卸载
            sudo pkgutil --forget org.nodejs.pkg 2>/dev/null || true
            sudo rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/lib/node_modules 2>/dev/null || true
            sudo rm -rf /opt/homebrew/bin/node /opt/homebrew/bin/npm /opt/homebrew/lib/node_modules 2>/dev/null || true
            print_ok "已清理旧安装"
        fi
    else
        print_info "当前 Node.js 版本过低或未安装"
    fi

    # 选择安装方式
    echo ""
    echo -e "${YELLOW}请选择安装方式：${NC}"
    echo "  1) Homebrew (推荐，最简单)"
    echo "  2) 官方安装包 (自动适配架构)"
    echo "  3) nvm (适合开发者)"
    echo ""
    safe_read "请输入选项 (1-3): "

    case $choice in
        1)
            if ! install_via_homebrew; then
                print_warn "Homebrew 安装失败或 Node.js 无法运行，尝试官方安装包..."
                if ! install_via_official; then
                    print_error "所有安装方式都失败了"
                    exit 1
                fi
            fi
            ;;
        2)
            if ! install_via_official; then
                print_error "官方安装包安装失败"
                exit 1
            fi
            ;;
        3)
            if ! install_via_nvm; then
                print_error "nvm 安装失败"
                exit 1
            fi
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
