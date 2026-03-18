#!/bin/bash

# ============================================
# 🦞 小龙虾诊断修复脚本 (macOS)
# 检测并修复常见问题
# ============================================

# 不使用 set -e，让脚本完整运行所有诊断

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  🦞 小龙虾诊断修复脚本 (macOS)${NC}"
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

# 问题标记
ISSUES_FOUND=0

# 检查小龙虾安装
check_openclaw_install() {
    print_step "检查小龙虾安装"

    if command -v openclaw &> /dev/null; then
        local version=$(openclaw --version 2>/dev/null || echo "未知版本")
        print_ok "已安装: $version"
        return 0
    else
        print_error "未安装小龙虾"
        print_info "请运行 4-install-openclaw.sh 进行安装"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    fi
}

# 检查 Node.js
check_node() {
    print_step "检查 Node.js"

    if ! command -v node &> /dev/null; then
        print_error "未安装 Node.js"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    fi

    local version=$(node -v)
    local major=$(echo $version | sed 's/v\([0-9]*\).*/\1/')

    if [ $major -lt 22 ]; then
        print_error "Node.js 版本过低: $version (需要 22+)"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    fi

    print_ok "Node.js: $version"
    return 0
}

# 检查配置文件
check_config() {
    print_step "检查配置文件"

    local config_file="$HOME/.openclaw/openclaw.json"

    if [ -f "$config_file" ]; then
        print_ok "配置文件存在"

        # 检查是否为空
        if [ ! -s "$config_file" ]; then
            print_warn "配置文件为空"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    else
        print_warn "配置文件不存在"
        print_info "首次运行可能需要配置"
    fi
}

# 检查网关端口
check_port() {
    print_step "检查网关端口 (18789)"

    if lsof -i :18789 &> /dev/null; then
        local pid=$(lsof -t -i :18789)
        print_ok "端口 18789 已被占用 (PID: $pid)"

        # 检查是否是 openclaw 进程
        if ps -p $pid -o command= | grep -q openclaw; then
            print_ok "是小龙虾网关进程"
        else
            print_warn "被其他进程占用"
            print_info "可能需要关闭该进程"
        fi
    else
        print_info "端口 18789 未被占用（网关未运行）"
    fi
}

# 检查网关状态
check_gateway_status() {
    print_step "检查网关状态"

    # 尝试访问健康检查端点
    if curl -s http://127.0.0.1:18789/health &> /dev/null; then
        print_ok "网关运行正常"

        # 检查 dashboard
        if curl -s http://127.0.0.1:18789/ &> /dev/null; then
            print_ok "Dashboard 可访问"
        fi

        return 0
    else
        print_warn "网关未运行或无法访问"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    fi
}

# 运行 openclaw doctor
run_doctor() {
    print_step "运行诊断命令"

    print_info "运行 openclaw doctor..."
    echo ""

    if openclaw doctor 2>&1; then
        print_ok "诊断通过"
    else
        print_warn "诊断发现问题"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
}

# 尝试修复
attempt_fix() {
    print_step "尝试修复问题"

    echo ""
    echo -e "${YELLOW}发现 $ISSUES_FOUND 个问题${NC}"
    echo ""

    if [ $ISSUES_FOUND -eq 0 ]; then
        print_ok "未发现问题"
        return 0
    fi

    read -p "是否尝试自动修复? (y/n): " choice

    if [[ $choice != "y" && $choice != "Y" ]]; then
        print_info "跳过自动修复"
        return 1
    fi

    # 常见修复操作
    print_info "尝试修复..."

    # 1. 修复权限问题
    local npm_prefix=$(npm prefix -g 2>/dev/null)
    if [ -n "$npm_prefix" ] && [ ! -w "$npm_prefix" ]; then
        print_info "修复 npm 权限..."
        sudo chown -R $(whoami) "$npm_prefix" 2>/dev/null || true
    fi

    # 2. 清理缓存
    print_info "清理 npm 缓存..."
    npm cache clean --force 2>/dev/null || true

    # 3. 重新安装依赖（如果有问题）
    print_info "检查依赖完整性..."
    npm rebuild -g openclaw 2>/dev/null || true

    print_ok "修复尝试完成"
    return 0
}

# 重启网关
restart_gateway() {
    print_step "重启网关"

    # 先停止现有网关
    print_info "停止现有网关进程..."

    # 使用 openclaw gateway stop
    openclaw gateway stop 2>/dev/null || true

    # 确保端口释放
    sleep 2

    # 如果端口仍被占用，强制结束
    if lsof -i :18789 &> /dev/null; then
        local pid=$(lsof -t -i :18789)
        print_warn "强制结束进程 $pid"
        kill -9 $pid 2>/dev/null || true
        sleep 1
    fi

    print_info "启动网关..."

    # 后台启动网关
    nohup openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &

    sleep 3

    # 检查是否启动成功
    if curl -s http://127.0.0.1:18789/health &> /dev/null; then
        print_ok "网关启动成功"
        return 0
    else
        print_error "网关启动失败"
        print_info "查看日志: tail -f /tmp/openclaw-gateway.log"
        return 1
    fi
}

# 打开 Dashboard
open_dashboard() {
    print_step "打开控制面板"

    echo ""
    read -p "是否打开 Dashboard (Web UI)? (y/n): " choice

    if [[ $choice == "y" || $choice == "Y" ]]; then
        print_info "正在打开浏览器..."
        open "http://127.0.0.1:18789" 2>/dev/null || \
            print_info "请手动访问: http://127.0.0.1:18789"
    fi
}

# 显示诊断总结
show_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  诊断总结${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}✅ 未发现明显问题${NC}"
    else
        echo -e "${YELLOW}⚠ 发现 $ISSUES_FOUND 个问题${NC}"
    fi

    echo ""
    echo -e "${YELLOW}常用命令：${NC}"
    echo ""
    echo "  openclaw status          查看状态"
    echo "  openclaw gateway         启动网关"
    echo "  openclaw gateway stop    停止网关"
    echo "  openclaw dashboard       打开控制面板"
    echo "  openclaw doctor          运行诊断"
    echo "  tail -f /tmp/openclaw-gateway.log  查看日志"
    echo ""
}

# 主函数
main() {
    clear
    print_header

    # 检查安装
    check_openclaw_install || exit 1

    # 检查 Node.js
    check_node

    # 检查配置
    check_config

    # 检查端口
    check_port

    # 检查网关状态
    check_gateway_status

    # 运行诊断
    run_doctor

    # 尝试修复
    attempt_fix

    echo ""
    read -p "是否重启网关? (y/n): " choice

    if [[ $choice == "y" || $choice == "Y" ]]; then
        restart_gateway
        open_dashboard
    fi

    # 显示总结
    show_summary
}

# 运行
main
