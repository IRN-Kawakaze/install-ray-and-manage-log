#!/bin/bash
# Copyright 2022 by Kawakaze

# 环境变量，路径尾部均不包含 /

# v2ray配置文件存放路径
v2ray_config_path=/usr/local/etc/v2ray
# v2ray日志文件存放路径
v2ray_log_path=/var/log/v2ray
# v2ray服务文件的绝对路径
v2ray_service_file=/etc/systemd/system/v2ray.service
# 脚本存放路径
user_script_path=/etc/userscript


# 为显示内容做好准备：
echo -e "\n"

# 判断脚本是否由 root 用户运行，如果不是，则报错并退出：
[ "$(whoami)" == "root" ] || { echo -e "ERROR: This script must be run by root, please run \"sudo su\" before running this script.\n" ; exit 1 ; }

# 判断 /etc/debian_version 文件是否存在，如果不存在，则报错并退出：
[ -f /etc/debian_version ] || { echo -e "ERROR: This system is not supported, please install Debian.\n" ; exit 1 ; }

# 检查依赖
command -v rm > /dev/null 2>&1 || { echo -e "ERROR\: Cannot run \"rm\" command.\n" ; exit 1 ; }
command -v cat > /dev/null 2>&1 || { echo -e "ERROR\: Cannot run \"cat\" command.\n" ; exit 1 ; }
command -v sed > /dev/null 2>&1 || { echo -e "ERROR\: Cannot run \"sed\" command.\n" ; exit 1 ; }
command -v chmod > /dev/null 2>&1 || { echo -e "ERROR\: Cannot run \"chmod\" command.\n" ; exit 1 ; }
command -v mkdir > /dev/null 2>&1 || { echo -e "ERROR\: Cannot run \"mkdir\" command.\n" ; exit 1 ; }
command -v curl > /dev/null 2>&1 || { echo -e "ERROR\: You should install \"curl\" first.\n" ; exit 1 ; }
command -v wget > /dev/null 2>&1 || { echo -e "ERROR\: You should install \"wget\" first.\n" ; exit 1 ; }
command -v crontab > /dev/null 2>&1 || { echo -e "ERROR\: You should install \"crontab\" first.\n" ; exit 1 ; }
command -v systemctl > /dev/null 2>&1 || { echo -e "ERROR\: You should install \"systemctl\" first.\n" ; exit 1 ; }

# 检查和 GitHub 的网络连接是否正常，如果不正常则直接退出
wget -4 --spider --quiet --tries=3 --timeout=3 https://raw.githubusercontent.com || { echo -e "ERROR\: Cannot connect to GitHub.\n" ; exit 1 ; }    

# 函数-安装 v2ray
install_v2ray() {

    # 安装 v2ray，如果安装失败则直接退出
    bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) || { echo -e "ERROR\: Install v2ray failed.\n" ; exit 1 ; }    
    echo -e "\n"

    # 删除可能存在的多配置文件
    rm -f ${v2ray_config_path}/*

    # 创建证书文件存放文件夹
    mkdir -p ${v2ray_config_path}/cert

    # 创建日志管理脚本存放路径
    mkdir -p ${user_script_path}/

    # 创建日志管理脚本
    cat << EOF > ${user_script_path}/cleanv2raylog.sh
#!/bin/bash

# 删除现有的日志备份文件
rm -f ${v2ray_log_path}/access.log.backup

# 生成当前日志的备份
cp ${v2ray_log_path}/access.log ${v2ray_log_path}/access.log.backup

# 清空当前的日志文件
echo "" > ${v2ray_log_path}/access.log

EOF

    # 给日志管理脚本赋权
    chmod +x ${user_script_path}/cleanv2raylog.sh

    # 导出现有的定时任务
    crontab -l > crontab.temp

    # 删除可能已经存在的自动清理日志的定时任务
    sed -i '/cleanv2raylog\.sh/d' crontab.temp

    # 添加自动清理日志的定时任务，每个月清理一次
    echo "0 5 1 * * ${user_script_path}/cleanv2raylog.sh >> /dev/null 2>&1" >> crontab.temp

    # 使修改后的定时任务生效
    crontab crontab.temp

    # 运行“函数-修改 service 文件”
    modify_service_file

    # 打印 v2ray 配置文件路径，以便修改
    echo -e "\n"
    echo "=================================================="
    echo "Config file path:"
    echo "${v2ray_config_path}/config.json"
    echo "=================================================="
    echo ""

}

# 函数-更新 v2ray
update_v2ray() {

    # 停止 v2ray
    systemctl stop v2ray

    # 安装 v2ray，如果安装失败则直接退出
    bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) || { echo -e "ERROR\: Update v2ray failed.\n" ; exit 1 ; }    
    echo -e "\n"

    # 运行“函数-修改 service 文件”
    modify_service_file

    # 启动 v2ray
    systemctl start v2ray

    # 显示 v2ray 运行状态
    systemctl status v2ray

    # 显示 v2ray 更新完毕
    echo -e "\n"
    echo "=================================================="
    echo "Update v2ray successful."
    echo "=================================================="
    echo ""

}

# 函数-修改 service 文件
modify_service_file() {

    # 清除对 service 文件的修改
    sed -i '/LimitCORE=/d' ${v2ray_service_file} && sed -i '/LimitNOFILE=/d' ${v2ray_service_file} && sed -i '/LimitNPROC=/d' ${v2ray_service_file}

    # 修改 v2ray 的最大句柄数和最大进程数
    sed -i '/\[Service\]/a\LimitCORE=infinity\nLimitNOFILE=12800\nLimitNPROC=12800' ${v2ray_service_file}

    # 重新加载 service 文件，使修改生效
    systemctl daemon-reload

}

# 检查是否已安装 v2ray，如果已安装 v2ray，则运行“函数-更新 v2ray”，否则运行“函数-安装 v2ray”
command -v v2ray > /dev/null 2>&1
if [ "$?" == "0" ]; then
    update_v2ray
else
    install_v2ray
fi

