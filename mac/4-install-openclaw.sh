#!/bin/bash

# ============================================
# 🦞 小龙虾安装脚本 (macOS)
# 安装 OpenClaw Agent
# ============================================

# 不使用 set -e，避免非关键错误中断安装

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# npm 源列表（兼容 bash 3.2，使用普通数组）
NPM_URLS=(
    "https://registry.npmmirror.com"
    "https://mirrors.cloud.tencent.com/npm/"
    "https://repo.huaweicloud.com/repository/npm/"
    "https://registry.npmjs.org"
)

NPM_NAMES=(
    "淘宝源 (npmmirror.com) - 推荐"
    "腾讯源"
    "华为源"
    "官方源 (需要代理)"
)

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 小龙虾安装脚本 (macOS)${NC}"
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

# 检查前置条件
check_prerequisites() {
    print_step "检查前置条件"

    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        print_error "未安装 Node.js"
        print_info "请先运行 2-install-node.sh 安装 Node.js"
        exit 1
    fi

    local node_major=$(node -v | sed 's/v\([0-9]*\).*/\1/')
    if [ $node_major -lt 22 ]; then
        print_error "Node.js 版本过低 ($(node -v))"
        print_info "需要 Node.js 22.16 或更高版本"
        print_info "请运行 2-install-node.sh 升级"
        exit 1
    fi

    print_ok "Node.js: $(node -v)"

    # 检查 npm
    if ! command -v npm &> /dev/null; then
        print_error "未找到 npm"
        exit 1
    fi

    print_ok "npm: $(npm -v)"

    # 检查 Git（可选但建议）
    if command -v git &> /dev/null; then
        print_ok "Git: $(git --version | awk '{print $3}')"
    else
        print_warn "未安装 Git，建议运行 3-install-git.sh"
    fi
}

# 选择 npm 源
select_npm_registry() {
    print_step "选择 npm 源"

    local current_registry=$(npm config get registry)
    print_info "当前源: $current_registry"
    echo ""

    echo -e "${YELLOW}请选择 npm 源${NC}"
    echo ""

    local i=0
    while [ $i -lt ${#NPM_NAMES[@]} ]; do
        echo "  $((i+1))) ${NPM_NAMES[$i]}"
        i=$((i+1))
    done

    echo "  5) 保持当前设置"
    echo ""

    read -p "请输入选项 (1-5): " choice

    case $choice in
        1|2|3|4)
            local idx=$((choice-1))
            local registry="${NPM_URLS[$idx]}"
            npm config set registry "$registry"
            print_ok "已切换到: $registry"
            ;;
        5)
            print_ok "保持当前源: $current_registry"
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
}

# 检查是否已安装
check_existing_install() {
    if command -v openclaw &> /dev/null; then
        print_step "检测到已安装的小龙虾"

        local version=$(openclaw --version 2>/dev/null || echo "未知版本")
        print_info "当前版本: $version"

        echo ""
        read -p "是否重新安装/更新? (y/n): " choice

        if [[ $choice != "y" && $choice != "Y" ]]; then
            print_info "跳过安装"
            return 1
        fi

        # 卸载旧版本
        print_info "卸载旧版本..."
        npm uninstall -g openclaw 2>/dev/null || true
    fi

    return 0
}

# 安装小龙虾
install_openclaw() {
    print_step "安装小龙虾"

    print_info "正在安装，请耐心等待..."
    echo ""

    # 设置环境变量避免 sharp 问题
    export SHARP_IGNORE_GLOBAL_LIBVIPS=1

    # 安装
    if npm install -g openclaw@latest; then
        print_ok "安装成功"
    else
        print_error "安装失败"
        echo ""
        print_info "可能的原因："
        print_info "1. 网络问题 - 尝试更换 npm 源后重试"
        print_info "2. 权限问题 - 尝试使用 sudo npm install -g openclaw"
        print_info "3. Node 版本问题 - 确保使用 Node.js 22+"
        exit 1
    fi
}

# 验证安装
verify_installation() {
    print_step "验证安装"

    if command -v openclaw &> /dev/null; then
        local version=$(openclaw --version 2>/dev/null || echo "未知版本")
        print_ok "小龙虾已安装: $version"
        return 0
    else
        print_error "openclaw 命令未找到"
        print_info "可能需要将 npm 全局目录添加到 PATH"
        print_info "运行以下命令："
        echo ""
        echo "  export PATH=\"\$(npm prefix -g)/bin:\$PATH\""
        echo ""
        print_info "或将此行添加到 ~/.zshrc 文件中"
        return 1
    fi
}

# 运行 onboarding
run_onboarding() {
    print_step "启动配置向导"

    echo ""
    echo -e "${YELLOW}现在可以启动小龙虾的配置向导了${NC}"
    echo ""
    echo "配置向导会帮助你："
    echo "  • 设置 AI 模型提供商（需要 API Key）"
    echo "  • 配置消息通道（WhatsApp、Telegram 等）"
    echo "  • 安装后台服务"
    echo ""

    read -p "是否启动配置向导? (y/n): " choice

    if [[ $choice == "y" || $choice == "Y" ]]; then
        print_info "启动配置向导..."
        echo ""
        openclaw onboard --install-daemon
    else
        print_info "跳过配置向导"
        print_info "稍后可以运行 'openclaw onboard' 进行配置"
    fi
}

# 显示下一步
show_next_steps() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ 小龙虾安装完成${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}常用命令：${NC}"
    echo ""
    echo "  openclaw --help      查看帮助"
    echo "  openclaw status      查看状态"
    echo "  openclaw gateway     启动网关"
    echo "  openclaw dashboard   打开控制面板"
    echo "  openclaw doctor      诊断问题"
    echo ""
    echo -e "${YELLOW}下一步：${NC}"
    echo ""
    echo "  1. 运行 'openclaw gateway' 启动网关"
    echo "  2. 打开浏览器访问 http://127.0.0.1:18789"
    echo ""
    echo -e "如遇问题，运行 ${YELLOW}5-diagnose.sh${NC} 进行诊断修复"
    echo ""
}

# 主函数
main() {
    clear
    print_header

    # 检查前置条件
    check_prerequisites

    # 选择 npm 源
    select_npm_registry

    # 检查现有安装
    check_existing_install || exit 0

    # 安装
    install_openclaw

    # 验证
    verify_installation || exit 1

    # 运行 onboarding
    run_onboarding

    # 显示下一步
    show_next_steps
}

# 运行
main
