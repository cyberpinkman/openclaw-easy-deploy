#!/bin/bash

# ============================================
# 🦞 小龙虾环境自检脚本 (macOS)
# 检测电脑配置和已安装软件
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 小龙虾环境自检 (macOS)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_section() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# 检测系统信息
check_system() {
    print_section "系统信息"

    # macOS 版本
    local os_version=$(sw_vers -productVersion)
    print_info "macOS 版本: $os_version"

    # 芯片类型
    local chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    if [[ $(uname -m) == "arm64" ]]; then
        print_info "芯片: Apple Silicon (ARM64)"
    else
        print_info "芯片: Intel (x86_64)"
    fi
}

# 检测硬件配置
check_hardware() {
    print_section "硬件配置"

    # 内存
    local total_mem=$(sysctl -n hw.memsize 2>/dev/null)
    local mem_gb=$((total_mem / 1024 / 1024 / 1024))

    print_info "内存: ${mem_gb}GB"

    if [ $mem_gb -lt 4 ]; then
        print_error "内存过低 (低于 4GB)，建议更换设备"
        return 1
    elif [ $mem_gb -lt 8 ]; then
        print_warn "内存较低 (4-8GB)，可以运行但可能卡顿"
    else
        print_ok "内存充足 (8GB+)"
    fi

    # 硬盘空间
    local free_space=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
    print_info "可用硬盘空间: ${free_space}GB"

    if [ $free_space -lt 2 ]; then
        print_error "硬盘空间不足 (低于 2GB)，请清理磁盘"
        return 1
    elif [ $free_space -lt 5 ]; then
        print_warn "硬盘空间较少 (2-5GB)，建议清理"
    else
        print_ok "硬盘空间充足 (5GB+)"
    fi
}

# 检测 Node.js
check_node() {
    print_section "Node.js"

    if command -v node &> /dev/null; then
        local node_version=$(node -v 2>/dev/null)
        local major_version=$(echo $node_version | sed 's/v\([0-9]*\).*/\1/')

        print_info "已安装: $node_version"

        if [ $major_version -ge 24 ]; then
            print_ok "版本满足推荐要求 (24+)"
        elif [ $major_version -ge 22 ]; then
            print_ok "版本满足最低要求 (22+)"
        else
            print_warn "版本过低 (低于 22)，需要升级"
            print_info "请运行 2-install-node.sh 安装新版本"
            return 1
        fi

        # 检查 npm
        local npm_version=$(npm -v 2>/dev/null)
        print_info "npm 版本: $npm_version"
    else
        print_warn "未安装 Node.js"
        print_info "请运行 2-install-node.sh 进行安装"
        return 1
    fi
}

# 检测 Git
check_git() {
    print_section "Git"

    if command -v git &> /dev/null; then
        local git_version=$(git --version 2>/dev/null | awk '{print $3}')
        print_info "已安装: $git_version"
        print_ok "Git 已就绪"

        # 检测是否能连接 GitHub
        print_info "检测 GitHub 连接..."
        if timeout 10 git ls-remote https://github.com &> /dev/null; then
            print_ok "可以连接 GitHub"
        else
            print_warn "无法连接 GitHub，可能需要配置镜像或使用代理"
            print_info "请运行 3-install-git.sh 配置镜像"
        fi
    else
        print_warn "未安装 Git"
        print_info "请运行 3-install-git.sh 进行安装"
        return 1
    fi
}

# 检测 OpenClaw
check_openclaw() {
    print_section "小龙虾 (OpenClaw)"

    if command -v openclaw &> /dev/null; then
        local oc_version=$(openclaw --version 2>/dev/null || echo "未知版本")
        print_info "已安装: $oc_version"
        print_ok "小龙虾已安装"

        # 检测网关状态
        print_info "检测网关状态..."
        if curl -s http://127.0.0.1:18789/health &> /dev/null; then
            print_ok "网关运行正常"
        else
            print_warn "网关未运行"
            print_info "如需启动网关，请运行: openclaw gateway"
            print_info "或运行 5-diagnose.sh 进行诊断修复"
        fi
    else
        print_warn "未安装小龙虾"
        print_info "请先完成 Node.js 和 Git 的安装"
        print_info "然后运行 4-install-openclaw.sh 进行安装"
        return 1
    fi
}

# 生成建议
generate_recommendation() {
    print_section "📋 检测结果与建议"

    echo ""
    echo -e "${GREEN}根据检测结果，建议按以下顺序执行脚本：${NC}"
    echo ""

    # 检查是否需要安装 Node.js
    if ! command -v node &> /dev/null; then
        echo "  1️⃣  运行 2-install-node.sh 安装 Node.js"
    elif [ $(node -v | sed 's/v\([0-9]*\).*/\1/') -lt 22 ]; then
        echo "  1️⃣  运行 2-install-node.sh 升级 Node.js"
    else
        echo "  ✅ Node.js 已就绪，跳过步骤 2"
    fi

    # 检查是否需要安装/配置 Git
    if ! command -v git &> /dev/null; then
        echo "  2️⃣  运行 3-install-git.sh 安装 Git"
    elif ! timeout 10 git ls-remote https://github.com &> /dev/null; then
        echo "  2️⃣  运行 3-install-git.sh 配置镜像源"
    else
        echo "  ✅ Git 已就绪，跳过步骤 3"
    fi

    # 检查是否需要安装小龙虾
    if ! command -v openclaw &> /dev/null; then
        echo "  3️⃣  运行 4-install-openclaw.sh 安装小龙虾"
    else
        echo "  ✅ 小龙虾已安装"
        echo "  💡 如遇问题，运行 5-diagnose.sh 进行诊断"
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 主函数
main() {
    clear
    print_header

    check_system
    check_hardware
    check_node
    check_git
    check_openclaw

    generate_recommendation
}

# 运行
main
