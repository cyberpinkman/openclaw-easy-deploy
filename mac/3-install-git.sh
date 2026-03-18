#!/bin/bash

# ============================================
# 🦞 Git 安装与配置脚本 (macOS)
# 安装 Git 并配置 GitHub 镜像源（中国用户）
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 镜像源列表
declare -A GIT_MIRRORS
GIT_MIRRORS["1"]="https://gitclone.com"
GIT_MIRRORS["2"]="https://hub.fastgit.xyz"
GIT_MIRRORS["3"]="https://mirror.ghproxy.com"
GIT_MIRRORS["4"]="https://ghproxy.net"
GIT_MIRRORS["5"]="https://gh-proxy.com"

MIRROR_NAMES=(
    "gitclone.com"
    "hub.fastgit.xyz"
    "mirror.ghproxy.com"
    "ghproxy.net"
    "gh-proxy.com"
)

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 Git 安装与配置脚本 (macOS)${NC}"
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

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# 检测是否有代理
check_proxy() {
    print_step "检测网络代理"

    # 检查常见代理端口
    local proxy_ports=("7890" "1080" "1087" "10809" "10808" "8080" "1086")
    local proxy_found=false

    for port in "${proxy_ports[@]}"; do
        if nc -z 127.0.0.1 $port 2>/dev/null; then
            print_info "检测到本地代理端口: $port"
            proxy_found=true
            break
        fi
    done

    # 检查环境变量
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
        print_ok "检测到代理环境变量"
        proxy_found=true
    fi

    if $proxy_found; then
        return 0
    else
        return 1
    fi
}

# 测试 GitHub 连接
test_github_connection() {
    print_step "测试 GitHub 连接"

    if timeout 15 git ls-remote https://github.com 2>/dev/null; then
        print_ok "可以连接 GitHub"
        return 0
    else
        print_warn "无法连接 GitHub"
        return 1
    fi
}

# 安装 Git
install_git() {
    print_step "安装 Git"

    if command -v git &> /dev/null; then
        local version=$(git --version | awk '{print $3}')
        print_ok "Git 已安装: $version"
        return 0
    fi

    print_info "Git 未安装，正在安装..."

    # 使用 Homebrew 安装
    if command -v brew &> /dev/null; then
        print_info "使用 Homebrew 安装 Git..."
        brew install git
    else
        # 安装 Xcode 命令行工具（包含 Git）
        print_info "安装 Xcode 命令行工具..."
        xcode-select --install

        echo ""
        print_info "请在弹出的窗口中完成安装，然后重新运行此脚本"
        exit 0
    fi

    if command -v git &> /dev/null; then
        print_ok "Git 安装成功"
        return 0
    else
        print_error "Git 安装失败"
        return 1
    fi
}

# 配置 Git 镜像
configure_git_mirror() {
    local mirror_url=$1

    print_step "配置 Git 镜像源: $mirror_url"

    # 配置 URL 重写规则
    git config --global url."$mirror_url/github.com/".insteadOf "https://github.com/"
    git config --global url."$mirror_url/github.com/".insteadOf "git@github.com:"

    # 测试配置
    print_info "测试镜像连接..."
    if timeout 15 git ls-remote https://github.com 2>/dev/null; then
        print_ok "镜像配置成功"
        return 0
    else
        print_warn "镜像连接失败，请尝试其他镜像源"
        return 1
    fi
}

# 清除镜像配置
clear_mirror_config() {
    print_step "清除 Git 镜像配置"

    git config --global --unset url."https://gitclone.com/github.com/".insteadOf 2>/dev/null || true
    git config --global --unset url."https://hub.fastgit.xyz/github.com/".insteadOf 2>/dev/null || true
    git config --global --unset url."https://mirror.ghproxy.com/github.com/".insteadOf 2>/dev/null || true
    git config --global --unset url."https://ghproxy.net/github.com/".insteadOf 2>/dev/null || true
    git config --global --unset url."https://gh-proxy.com/github.com/".insteadOf 2>/dev/null || true
    git config --global --unset url."https://gitclone.com/github.com/".insteadOf 2>/dev/null || true

    print_ok "已清除镜像配置"
}

# 选择镜像源
select_mirror() {
    echo ""
    echo -e "${YELLOW}请选择 GitHub 镜像源：${NC}"
    echo ""

    for i in "${!MIRROR_NAMES[@]}"; do
        echo "  $((i+1))) ${MIRROR_NAMES[$i]}"
    done

    echo "  6) 不使用镜像（我有代理）"
    echo "  7) 清除现有镜像配置"
    echo ""

    read -p "请输入选项 (1-7): " choice

    case $choice in
        1|2|3|4|5)
            local mirror_url="${GIT_MIRRORS[$choice]}"
            configure_git_mirror "$mirror_url"
            ;;
        6)
            clear_mirror_config
            print_ok "将使用直连或代理访问 GitHub"
            ;;
        7)
            clear_mirror_config
            print_ok "已清除镜像配置"
            ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac
}

# 配置 Git 用户信息（可选）
configure_git_user() {
    print_step "Git 用户配置（可选）"

    local current_name=$(git config --global user.name 2>/dev/null || echo "")
    local current_email=$(git config --global user.email 2>/dev/null || echo "")

    if [ -n "$current_name" ] && [ -n "$current_email" ]; then
        print_ok "已配置: $current_name <$current_email>"
        return 0
    fi

    echo ""
    read -p "是否配置 Git 用户信息? (y/n): " choice

    if [[ $choice == "y" || $choice == "Y" ]]; then
        read -p "请输入用户名: " username
        read -p "请输入邮箱: " email

        git config --global user.name "$username"
        git config --global user.email "$email"

        print_ok "Git 用户信息配置完成"
    else
        print_info "跳过用户配置"
    fi
}

# 主函数
main() {
    clear
    print_header

    # 询问是否有代理
    echo -e "${YELLOW}你是否拥有 VPN/加速器/代理？${NC}"
    echo ""
    echo "  如果有，请确保已开启代理，然后继续"
    echo "  如果没有，脚本会帮你配置 GitHub 镜像源"
    echo ""
    read -p "按 Enter 继续..." dummy

    # 检测代理
    if check_proxy; then
        print_info "检测到代理，建议直接连接"
    else
        print_info "未检测到代理"
    fi

    # 安装 Git
    install_git

    # 测试连接
    if test_github_connection; then
        print_ok "可以正常访问 GitHub，无需配置镜像"
    else
        print_warn "无法访问 GitHub，需要配置镜像源"
        select_mirror
    fi

    # 配置用户信息
    configure_git_user

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Git 配置完成${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "当前 Git 配置:"
    echo ""
    git config --global --list 2>/dev/null | grep -E "(url\..*\.insteadof|user\.)" || print_info "无特殊配置"
    echo ""
    echo -e "下一步: 运行 ${YELLOW}4-install-openclaw.sh${NC} 安装小龙虾"
    echo -e "如需更换镜像源，可重新运行此脚本"
    echo ""
}

# 运行
main
