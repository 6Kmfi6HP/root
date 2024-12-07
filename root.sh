#!/bin/bash

# 函数：检查错误并退出
# 参数 $1: 错误消息
check_error() {
    if [ $? -ne 0 ]; then
        echo "发生错误： $1"
        exit 1
    fi
}

# 函数：检查是否具有 root 权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "需要 root 权限来运行此脚本。请使用 sudo 或以 root 用户身份运行。"
        exit 1
    fi
}

# 函数：生成随机密码
generate_random_password() {
    random_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9!@#$%^&*()_-')
    echo "$random_password" # 输出密码
}

# 函数：修改 sshd_config 文件
modify_sshd_config() {
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    check_error "备份 sshd_config 文件时出错"

    # 注释掉 Include /etc/ssh/sshd_config.d/*.conf 行
    sudo sed -i 's/^Include \/etc\/ssh\/sshd_config.d\/\*\.conf/# &/' /etc/ssh/sshd_config
    check_error "注释掉 Include 行时出错"

    # 检查文件中是否存在以'PermitRootLogin'开头的行
    if grep -q '^PermitRootLogin' /etc/ssh/sshd_config; then
        # 存在匹配行，用'PermitRootLogin yes'替换
        sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        check_error "修改 PermitRootLogin 时出错"
    else
        # 不存在匹配行，追加'PermitRootLogin yes'到文件末尾
        echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
        check_error "追加 PermitRootLogin 时出错"
    fi

    # 修改 PasswordAuthentication
    if grep -q '^PasswordAuthentication' /etc/ssh/sshd_config; then
        sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    else
        echo 'PasswordAuthentication yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
    fi
    check_error "修改 PasswordAuthentication 时出错"
}

# 函数：设置密码并应用更改
apply_changes() {
    local password=$1
    
    # 设置密码
    echo "root:$password" | sudo chpasswd
    check_error "修改密码时出错"
    
    # 修改SSH配置
    modify_sshd_config
    
    # 重启SSH服务
    restart_sshd_service
}

# 函数：获取 SSH 服务名称
get_ssh_service_name() {
    # 检查 ssh 服务
    if sudo service ssh status >/dev/null 2>&1; then
        echo "ssh"
        return
    fi
    
    # 检查 sshd 服务
    if sudo service sshd status >/dev/null 2>&1; then
        echo "sshd"
        return
    fi

    # 如果都检测不到，返回默认值 sshd
    echo "sshd"
}

# 函数：重启 SSHD 服务
restart_sshd_service() {
    local service_name=$(get_ssh_service_name)
    sudo service $service_name restart
    check_error "重启 SSH 服务时出错"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [-p password]"
    echo "选项:"
    echo "  -p password    直接设置指定的密码"
    echo "  -h            显示此帮助信息"
    exit 0
}

# 主函数
main() {
    # 处理命令行参数
    while getopts "p:h" opt; do
        case $opt in
            h)
                show_help  # show_help 函数中已包含 exit 0
                ;;
            p)
                check_root
                password="$OPTARG"
                echo "即将设置的密码：$password"
                apply_changes "$password"
                # 删除下载的脚本
                if [ -f "root.sh" ]; then
                    rm -f "root.sh"
                fi
                exit 0
                ;;
            \?)
                echo "无效选项: -$OPTARG" >&2
                show_help
                ;;
        esac
    done

    shift $((OPTIND-1))

    # 交互模式
    echo "请选择密码选项："
    echo "1. 生成密码"
    echo "2. 输入密码"
    read -p "请输入选项编号：" option

    case $option in
        1)
            check_root
            password=$(generate_random_password)
            echo "生成的密码是：$password"
            apply_changes "$password"
            ;;
        2)
            check_root
            read -p "请输入更改密码：" custom_password
            echo "即将设置密码：$custom_password"
            apply_changes "$custom_password"
            ;;
        *)
            echo "无效选项 退出..."
            exit 1
            ;;
    esac

    # 删除下载的脚本
    if [ -f "root.sh" ]; then
        rm -f "root.sh"
    fi
}

# 执行主函数
main "$@"
