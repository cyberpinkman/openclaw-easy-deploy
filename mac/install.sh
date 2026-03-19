#!/bin/bash

# ============================================
# 🦞 小龙虾一键安装脚本 (macOS)
# 用户只需要运行这一条命令即可完成所有安装
# ============================================

# 不使用 set -e，我们自己处理错误

# 确定输入来源：如果 stdin 是管道，用 /dev/tty
get_tty_input() {
    if [ -t 0 ]; then
        cat
    else
        cat /dev/tty
    fi
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本版本
SCRIPT_VERSION="1.0.1"

# Node.js 目标版本
NODE_VERSION="24.14.0"

# 镜像源列表
MIRROR_URLS=(
    "https://gitclone.com"
    "https://mirror.ghproxy.com"
    "https://ghproxy.net"
)

MIRROR_NAMES=(
    "gitclone.com"
    "mirror.ghproxy.com"
    "ghproxy.net"
)

# npm 源列表
NPM_URLS=(
    "https://registry.npmmirror.com"
    "https://mirrors.cloud.tencent.com/npm/"
    "https://registry.npmjs.org"
)

NPM_NAMES=(
    "淘宝源 (推荐)"
    "腾讯源"
    "官方源 (需要代理)"
)

# 状态追踪
NEED_NODE=false
NEED_GIT_MIRROR=false
NEED_OPENCLAW=false

# 打印函数
print_header() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║                                           ║"
    echo "  ║    🦞 小龙虾 OpenClaw 一键安装脚本        ║"
    echo "  ║                                           ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_substep() {
    echo -e "\n${BLUE}▶ $1${NC}"
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

print_success_box() {
    echo ""
    echo -e "${GREEN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║                                           ║"
    echo "  ║           ✅ 安装完成！                   ║"
    echo "  ║                                           ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_fail_box() {
    echo ""
    echo -e "${RED}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║                                           ║"
    echo "  ║           ❌ 安装失败                     ║"
    echo "  ║                                           ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# macOS 兼容的 timeout 函数
run_with_timeout() {
    local timeout_sec=$1
    shift
    perl -e 'alarm shift; exec @ARGV' "$timeout_sec" "$@" 2>/dev/null
}

# 等待用户确认（兼容管道运行）
wait_continue() {
    local msg="${1:-按 Enter 继续...}"
    echo ""
    if [ -t 0 ]; then
        read -p "$msg" dummy
    else
        echo "$msg"
        read dummy < /dev/tty
    fi
}

# 询问用户 y/n（兼容管道运行）
ask_yes_no() {
    local prompt="$1"
    local answer

    if [ -t 0 ]; then
        read -p "$prompt (y/n): " answer
    else
        echo "$prompt (y/n): "
        read answer < /dev/tty
    fi

    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# 读取数字选项（带验证和重试）
read_number_choice() {
    local prompt="$1"
    local min="$2"
    local max="$3"
    local default="$4"
    local max_attempts=5
    local attempt=1
    local choice

    while [ $attempt -le $max_attempts ]; do
        # 直接读取，不通过子 shell
        if [ -t 0 ]; then
            read -p "$prompt" choice
        else
            echo "$prompt" >&2
            read choice < /dev/tty
        fi

        # 去除前后空白字符
        choice=$(echo "$choice" | tr -d '[:space:]')

        # 空输入，使用默认值
        if [ -z "$choice" ]; then
            echo "$default"
            return 0
        fi

        # 验证是否为数字
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            # 验证范围
            if [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ]; then
                echo "$choice"
                return 0
            else
                print_warn "请输入 $min 到 $max 之间的数字 (当前: $choice)"
            fi
        else
            print_warn "请输入数字，而不是: '$choice'"
        fi

        attempt=$((attempt + 1))
    done

    # 超过重试次数，使用默认值
    print_warn "已达到最大尝试次数，使用默认选项: $default"
    echo "$default"
    return 0
}

# 检测系统环境
detect_environment() {
    print_step "📋 第 1 步：检测系统环境"

    # 系统信息
    local os_version=$(sw_vers -productVersion 2>/dev/null || echo "未知")
    local chip=$(uname -m)
    local macos_major=$(echo "$os_version" | cut -d. -f1)
    local macos_minor=$(echo "$os_version" | cut -d. -f2)

    print_info "macOS 版本: $os_version"
    print_info "芯片: $([ "$chip" = "arm64" ] && echo "Apple Silicon" || echo "Intel")"

    # ========== 系统兼容性检查（关键）==========
    # OpenClaw 需要 Node.js 22.16+
    # Node.js 22.x 需要 macOS 10.15+ (Catalina)
    if [ "$macos_major" -lt 10 ] || ([ "$macos_major" -eq 10 ] && [ "$macos_minor" -lt 15 ]); then
        echo ""
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_error "  ⛔ 系统版本过低，无法安装 OpenClaw"
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_error "你的系统: macOS $os_version"
        print_error "最低要求: macOS 10.15 (Catalina)"
        echo ""
        print_info "原因：OpenClaw 需要 Node.js 22.16+，而 Node.js 22.x"
        print_info "      仅支持 macOS 10.15 及以上版本"
        echo ""
        echo -e "${YELLOW}解决方案：${NC}"
        echo ""
        echo "  1. 升级 macOS（推荐）"
        echo "     - 系统偏好设置 → 软件更新"
        echo "     - 或访问: https://support.apple.com/zh-cn/HT201372"
        echo ""
        echo "  2. 使用其他电脑"
        echo "     - macOS 10.15+ 的 Mac"
        echo "     - Windows 10/11"
        echo "     - Linux"
        echo ""
        echo "  3. 使用云服务器"
        echo "     - 阿里云、腾讯云等 VPS"
        echo ""
        return 1
    fi
    print_ok "系统版本兼容 (macOS $os_version >= 10.15)"

    # ========== Xcode Command Line Tools 检查 ==========
    # 升级 macOS 后经常损坏，导致 npm install 失败
    print_info "检查 Xcode Command Line Tools..."
    if ! xcode-select -p &> /dev/null; then
        print_warn "Xcode Command Line Tools 未安装"
        print_info "正在安装..."
        xcode-select --install 2>/dev/null
        echo ""
        print_info "请在弹出的窗口中完成安装，然后重新运行此脚本"
        return 1
    fi
    
    # 检查 xcrun 是否可用（升级 macOS 后经常损坏）
    if ! xcrun --version &> /dev/null; then
        print_warn "Xcode Command Line Tools 损坏（升级 macOS 后常见问题）"
        print_info "正在修复..."
        sudo xcode-select --reset 2>/dev/null
        sudo xcode-select --install 2>/dev/null
        echo ""
        print_info "请在弹出的窗口中完成安装，然后重新运行此脚本"
        return 1
    fi
    print_ok "Xcode Command Line Tools 正常"

    # 内存检查
    local total_mem=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    if [ -z "$total_mem" ] || [ "$total_mem" = "0" ]; then
        print_warn "无法检测内存大小，跳过检查"
    else
        local mem_gb=$((total_mem / 1024 / 1024 / 1024))
        if [ "$mem_gb" -lt 4 ]; then
            print_error "内存过低 (${mem_gb}GB)，建议至少 4GB"
            return 1
        fi
        print_ok "内存: ${mem_gb}GB"
    fi

    # 硬盘空间检查
    local free_space=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$free_space" ]; then
        print_warn "无法检测硬盘空间，跳过检查"
    elif [ "$free_space" -lt 2 ] 2>/dev/null; then
        print_error "硬盘空间不足 (${free_space}GB)，建议至少 2GB"
        return 1
    else
        print_ok "可用空间: ${free_space}GB"
    fi

    return 0
}

# 检测 Node.js
check_node() {
    print_substep "检测 Node.js"

    if ! command -v node &> /dev/null; then
        print_warn "未安装 Node.js"
        NEED_NODE=true
        return 1
    fi

    local version=$(node -v 2>/dev/null)
    print_info "已安装: $version"

    # 测试 Node.js 是否能正常运行
    if ! node -e "console.log('OK')" &> /dev/null; then
        print_warn "Node.js 已安装但无法运行"
        print_info "可能是架构不匹配或系统版本不兼容"
        print_info "将重新安装兼容版本..."
        NEED_NODE=true
        return 1
    fi

    local major=$(echo "$version" | sed 's/v\([0-9]*\).*/\1/')

    if [ "$major" -lt 22 ]; then
        print_warn "版本过低 (需要 22+)，需要升级"
        NEED_NODE=true
        return 1
    fi

    print_ok "版本满足要求，运行正常"
    return 0
}

# 安装 Node.js
install_node() {
    # 检测 macOS 版本，决定使用哪个 Node.js 版本
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "10.0")
    local macos_major=$(echo "$macos_version" | cut -d. -f1)
    local macos_minor=$(echo "$macos_version" | cut -d. -f2)
    
    # 如果已安装但无法运行，先卸载
    if command -v node &> /dev/null; then
        if ! node -e "console.log('OK')" &> /dev/null; then
            print_warn "检测到无法运行的 Node.js，正在卸载..."
            # 尝试通过 pkg 卸载
            sudo pkgutil --forget org.nodejs.pkg 2>/dev/null || true
            # 删除常见安装路径
            sudo rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/lib/node_modules 2>/dev/null || true
            sudo rm -rf /opt/homebrew/bin/node /opt/homebrew/bin/npm /opt/homebrew/lib/node_modules 2>/dev/null || true
            print_ok "已清理旧安装"
        fi
    fi
    
    # Node.js 版本兼容性：
    # - Node.js 24.x: macOS 12+ (Monterey)
    # - Node.js 22.x: macOS 10.15+ (Catalina)
    # - Node.js 18.x: macOS 10.13+ (High Sierra) - 最后支持旧系统的LTS
    
    if [ "$macos_major" -lt 10 ] || ([ "$macos_major" -eq 10 ] && [ "$macos_minor" -lt 15 ]); then
        # macOS 10.14 或更早
        print_step "📦 第 2 步：安装 Node.js 18.x LTS"
        print_warn "检测到 macOS $macos_version，Node.js 22+ 需要 macOS 10.15+"
        print_info "将安装 Node.js 18.x LTS（最后一个支持你系统的版本）"
        print_info "⚠ Node.js 18 将于 2025年4月结束支持，建议升级 macOS"
        NODE_VERSION="18.20.8"
    elif [ "$macos_major" -lt 12 ]; then
        # macOS 10.15-11.x
        print_step "📦 第 2 步：安装 Node.js 22.x LTS"
        print_warn "检测到 macOS $macos_version，Node.js 24.x 需要 macOS 12+"
        print_info "将安装 Node.js 22.x LTS（兼容你的系统）"
        NODE_VERSION="22.22.1"
    else
        print_step "📦 第 2 步：安装 Node.js $NODE_VERSION"
    fi

    # 检测系统架构
    local arch=$(uname -m)
    local arch_name="未知"

    if [ "$arch" = "arm64" ]; then
        arch_name="Apple Silicon (M系列芯片)"
    else
        arch_name="Intel (x86_64)"
    fi

    print_info "系统架构: $arch_name"
    print_info "macOS 版本: $macos_version"

    # 检查 Homebrew
    if ! command -v brew &> /dev/null; then
        print_info "Homebrew 未安装，正在安装..."
        print_info "这可能需要几分钟，请耐心等待..."

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [ $? -ne 0 ]; then
            print_error "Homebrew 安装失败"
            show_node_install_help
            return 1
        fi

        # 添加到 PATH
        if [[ "$arch" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        print_ok "Homebrew 安装成功"
    fi

    # 跳过 Homebrew 更新（对小白用户来说经常卡住，且非必须）
    # 禁用 Homebrew 自动更新（brew install 会自动触发 brew update）
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_FROM_API=1

    print_info "正在通过 Homebrew 安装 Node.js..."
    print_info "这可能需要几分钟..."

    if brew install node 2>&1; then
        # 验证安装和架构兼容性
        if command -v node &> /dev/null; then
            local node_path=$(which node)
            local node_arch=$(file "$node_path" 2>/dev/null | grep -o 'arm64\|x86_64' | head -1)
            
            # 检查架构是否匹配
            if [[ "$node_arch" == *"arm64"* && "$arch" == "arm64" ]] || [[ "$node_arch" == *"x86_64"* && "$arch" != "arm64" ]]; then
                local version=$(node -v)
                print_ok "Node.js 安装成功: $version"
                print_ok "npm 版本: $(npm -v)"
                # 测试 Node.js 是否能正常运行
                if node -e "console.log('OK')" &> /dev/null; then
                    print_ok "Node.js 运行正常"
                    return 0
                else
                    print_warn "Node.js 已安装但无法运行，可能是架构不匹配"
                    print_info "尝试使用官方安装包..."
                fi
            else
                print_warn "检测到架构不匹配，尝试使用官方安装包..."
            fi
        fi
    fi

    # Homebrew 失败或架构不匹配，尝试官方安装包
    print_warn "Homebrew 安装失败，尝试使用官方安装包..."

    # Node.js .pkg 是通用安装包，支持 Intel 和 Apple Silicon
    local download_url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"
    local tmp_file="/tmp/node-installer.pkg"

    print_info "下载地址: $download_url"
    print_info "正在下载..."

    if curl -fsSL "$download_url" -o "$tmp_file" 2>&1; then
        print_info "正在安装... (需要输入管理员密码)"
        if sudo installer -pkg "$tmp_file" -target / 2>&1; then
            rm -f "$tmp_file"
            # 刷新 PATH
            export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
            
            if command -v node &> /dev/null; then
                local version=$(node -v)
                print_ok "Node.js 安装成功: $version"
                print_ok "npm 版本: $(npm -v)"
                
                # 测试 Node.js 是否能正常运行
                if node -e "console.log('OK')" &> /dev/null 2>&1; then
                    print_ok "Node.js 运行正常"
                    return 0
                else
                    print_error "Node.js 安装成功但无法运行"
                    print_error "可能存在系统兼容性问题，请联系技术支持"
                    show_node_install_help
                    return 1
                fi
            fi
        fi
        rm -f "$tmp_file"
    fi

    print_error "Node.js 安装失败"
    show_node_install_help
    return 1
}

# 显示 Node.js 手动安装帮助
show_node_install_help() {
    echo ""
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  手动安装 Node.js 的方法：${NC}"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    echo ""
    echo "  方法 1: 下载官方安装包"
    echo "    访问: https://nodejs.org"
    echo "    下载 LTS 版本并安装"
    echo ""
    echo "  方法 2: 手动运行安装脚本"
    echo "    curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/2-install-node.sh | bash"
    echo ""
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
}

# 检测 Git 和 GitHub 连接
check_git() {
    print_substep "检测 Git 和 GitHub 连接"

    if ! command -v git &> /dev/null; then
        print_warn "未安装 Git，正在安装..."

        if command -v brew &> /dev/null; then
            # 禁用 Homebrew 自动更新
            export HOMEBREW_NO_AUTO_UPDATE=1
            export HOMEBREW_NO_INSTALL_FROM_API=1
            brew install git
        else
            xcode-select --install 2>/dev/null
            print_info "请在弹出的窗口中完成 Xcode 命令行工具安装"
            print_info "安装完成后，重新运行此脚本"
            return 1
        fi
    fi

    print_ok "Git: $(git --version | awk '{print $3}')"

    # 测试 GitHub 连接
    print_info "测试 GitHub 连接..."
    if run_with_timeout 15 git ls-remote https://github.com &> /dev/null; then
        print_ok "可以连接 GitHub"
        return 0
    else
        print_warn "无法连接 GitHub"
        NEED_GIT_MIRROR=true
        return 1
    fi
}

# 配置 Git 镜像
configure_git_mirror() {
    print_step "🌐 第 3 步：配置 GitHub 镜像源"

    echo ""
    echo -e "${YELLOW}你无法直接连接 GitHub，需要配置镜像源${NC}"
    echo ""
    echo -e "${CYAN}请选择镜像源 (直接输入数字即可)：${NC}"
    echo ""

    for i in "${!MIRROR_NAMES[@]}"; do
        echo "  $((i+1))) ${MIRROR_NAMES[$i]}"
    done

    echo ""
    echo -e "${BLUE}提示: 输入 1、2 或 3，然后按 Enter${NC}"
    echo ""

    local choice=$(read_number_choice "请选择 [1-3，默认1]: " 1 ${#MIRROR_NAMES[@]} 1)

    local idx=$((choice-1))
    local mirror_url="${MIRROR_URLS[$idx]}"

    print_info "你选择了: ${MIRROR_NAMES[$idx]}"
    print_info "配置镜像: $mirror_url"

    # 清除旧配置
    for m in "${MIRROR_URLS[@]}"; do
        git config --global --unset url."$m/github.com/".insteadOf 2>/dev/null
    done

    # 设置新配置
    git config --global url."$mirror_url/github.com/".insteadOf "https://github.com/"
    # 同时配置 SSH 转 HTTPS（重要！某些 npm 包用 SSH 协议）
    git config --global url."$mirror_url/github.com/".insteadOf "ssh://git@github.com/"
    git config --global url."$mirror_url/github.com/".insteadOf "git@github.com:"

    print_info "已配置镜像（HTTPS + SSH）"

    # 测试
    print_info "测试镜像连接..."
    if run_with_timeout 15 git ls-remote https://github.com &> /dev/null; then
        print_ok "镜像配置成功"
        return 0
    else
        print_warn "镜像测试失败，但已配置，尝试继续..."
        return 0
    fi
}

# 检测 OpenClaw
check_openclaw() {
    print_substep "检测小龙虾 (OpenClaw)"

    if command -v openclaw &> /dev/null; then
        local version=$(openclaw --version 2>/dev/null || echo "未知版本")
        print_ok "已安装: $version"

        echo ""
        if ask_yes_no "是否重新安装/更新?"; then
            NEED_OPENCLAW=true
            return 1
        fi

        return 0
    else
        print_warn "未安装小龙虾"
        NEED_OPENCLAW=true
        return 1
    fi
}

# 选择 npm 源
select_npm_registry() {
    echo ""
    echo -e "${CYAN}请选择 npm 源 (直接输入数字即可)：${NC}"
    echo ""

    for i in "${!NPM_NAMES[@]}"; do
        echo "  $((i+1))) ${NPM_NAMES[$i]}"
    done

    echo ""
    echo -e "${BLUE}提示: 输入 1、2 或 3，然后按 Enter${NC}"
    echo ""

    local choice=$(read_number_choice "请选择 [1-3，默认1]: " 1 ${#NPM_NAMES[@]} 1)

    local idx=$((choice-1))
    local registry="${NPM_URLS[$idx]}"

    print_info "你选择了: ${NPM_NAMES[$idx]}"
    npm config set registry "$registry"
    print_ok "已设置: $registry"
}

# 安装 OpenClaw
install_openclaw() {
    print_step "🦞 第 4 步：安装小龙虾 (OpenClaw)"

    # 先选择 npm 源
    select_npm_registry

    # 如果已有安装，先卸载
    if command -v openclaw &> /dev/null; then
        print_info "卸载旧版本..."
        npm uninstall -g openclaw 2>/dev/null
    fi

    print_info "正在安装，请耐心等待..."
    echo ""

    # 设置环境变量避免 sharp 问题
    export SHARP_IGNORE_GLOBAL_LIBVIPS=1

    # 尝试安装（先不用 sudo）
    if npm install -g openclaw@latest 2>&1; then
        # 验证安装
        if command -v openclaw &> /dev/null; then
            local version=$(openclaw --version 2>/dev/null || echo "未知版本")
            print_ok "小龙虾安装成功: $version"
            return 0
        fi
    fi

    # 如果失败，可能是权限问题，尝试 sudo
    print_warn "普通安装失败，尝试使用 sudo..."
    print_info "请输入管理员密码..."
    
    if sudo npm install -g openclaw@latest 2>&1; then
        # 验证安装
        if command -v openclaw &> /dev/null; then
            local version=$(openclaw --version 2>/dev/null || echo "未知版本")
            print_ok "小龙虾安装成功: $version"
            return 0
        fi
    fi

    print_error "小龙虾安装失败"
    show_openclaw_install_help
    return 1
}

# 显示 OpenClaw 安装帮助
show_openclaw_install_help() {
    echo ""
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  安装失败，请尝试：${NC}"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    echo ""
    echo "  1. 检查网络连接"
    echo "  2. 尝试更换 npm 源后重新运行此脚本"
    echo "  3. 手动安装: npm install -g openclaw"
    echo ""
    echo "  如需帮助，访问: https://docs.openclaw.ai"
    echo ""
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
}

# 运行配置向导
run_onboarding() {
    print_step "🎯 第 5 步：配置小龙虾"

    echo ""
    echo -e "${CYAN}现在需要配置小龙虾的 AI 模型和消息通道${NC}"
    echo ""
    echo "配置向导会帮助你："
    echo "  • 设置 AI 模型提供商（需要 API Key）"
    echo "  • 配置消息通道（WhatsApp、Telegram、Discord 等）"
    echo "  • 安装后台服务（可选）"
    echo ""

    if ask_yes_no "是否启动配置向导"; then
        print_info "启动配置向导..."
        echo ""
        openclaw onboard --install-daemon
    else
        print_info "跳过配置向导"
        print_info "稍后可以运行 'openclaw onboard' 进行配置"
    fi
}

# 显示完成信息
show_complete() {
    print_success_box

    echo ""
    echo -e "${GREEN}小龙虾已成功安装！${NC}"
    echo ""
    echo -e "${YELLOW}常用命令：${NC}"
    echo ""
    echo "  openclaw status      查看状态"
    echo "  openclaw gateway     启动网关"
    echo "  openclaw dashboard   打开控制面板"
    echo "  openclaw --help      查看帮助"
    echo ""
    echo -e "${YELLOW}下一步：${NC}"
    echo ""
    echo "  1. 运行 ${CYAN}openclaw gateway${NC} 启动网关"
    echo "  2. 打开浏览器访问 ${CYAN}http://127.0.0.1:18789${NC}"
    echo ""
    echo -e "${YELLOW}文档：${NC}https://docs.openclaw.ai"
    echo -e "${YELLOW}社区：${NC}https://discord.com/invite/clawd"
    echo ""
}

# 显示失败信息
show_failed() {
    local step="$1"

    print_fail_box

    echo ""
    echo -e "${RED}安装过程中断：${NC}$step"
    echo ""
    echo -e "${YELLOW}解决后重新运行：${NC}"
    echo ""
    echo "  curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/install.sh | bash"
    echo ""
    echo -e "${YELLOW}或使用 GitHub：${NC}"
    echo ""
    echo "  curl -fsSL https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/mac/install.sh | bash"
    echo ""
}

# 主函数
main() {
    print_header

    echo -e "${CYAN}这个脚本会帮你完成所有安装，你只需要：${NC}"
    echo ""
    echo "  1. 看着屏幕"
    echo "  2. 偶尔按一下 Enter 或输入 y/n"
    echo "  3. 等待完成"
    echo ""

    wait_continue "准备好了吗？按 Enter 开始..."

    # 第 1 步：检测环境
    if ! detect_environment; then
        show_failed "系统环境不满足要求"
        exit 1
    fi

    # 检测 Node.js
    check_node
    node_ok=$?

    # 检测 Git
    check_git
    git_ok=$?

    # 检测 OpenClaw
    check_openclaw
    openclaw_ok=$?

    # 第 2 步：安装 Node.js（如果需要）
    if [ "$NEED_NODE" = true ]; then
        echo ""
        if ask_yes_no "需要安装 Node.js，是否继续"; then
            if ! install_node; then
                show_failed "Node.js 安装失败"
                exit 1
            fi
        else
            show_failed "用户取消安装 Node.js"
            exit 1
        fi
    fi

    # 第 3 步：配置镜像（如果需要）
    if [ "$NEED_GIT_MIRROR" = true ]; then
        echo ""
        if ask_yes_no "需要配置 GitHub 镜像源，是否继续"; then
            if ! configure_git_mirror; then
                print_warn "镜像配置失败，尝试继续..."
            fi
        else
            print_warn "跳过镜像配置，后续安装可能失败"
        fi
    fi

    # 第 4 步：安装 OpenClaw（如果需要）
    if [ "$NEED_OPENCLAW" = true ]; then
        if ! install_openclaw; then
            show_failed "小龙虾安装失败"
            exit 1
        fi
    else
        print_step "🦞 小龙虾"
        print_ok "已安装，跳过"
    fi

    # 第 5 步：配置向导
    run_onboarding

    # 完成
    show_complete
}

# 运行
main
