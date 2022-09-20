#!/bin/bash
# Copyright 2022 by Kawakaze

# 设置常量，路径尾部均不包含 /

# v2ray 配置文件存放路径
v2ray_config_path=/usr/local/etc/v2ray
# v2ray 日志文件存放路径
v2ray_log_path=/var/log/v2ray
# v2ray 服务文件的存放路径
v2ray_service_path=/etc/systemd/system
# 脚本存放路径
user_script_path=/etc/userscript


# 函数-运行前检查
check_before_running() {
    # 判断脚本是否由 root 用户运行，如果不是，则报错并退出
    [ "$(whoami)" == "root" ] || { echo -e "ERROR: This script must be run by root, please run \"sudo su\" before running this script.\n" ; exit 1 ; }

    # 判断 /etc/debian_version 文件是否存在，如果不存在，则报错并退出
    [ -f /etc/debian_version ] || { echo -e "ERROR: This system is not supported, please install Debian.\n" ; exit 1 ; }

    # 检查依赖
    command -v rm > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"rm\".\n" ; exit 1 ; }
    command -v cat > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"cat\".\n" ; exit 1 ; }
    command -v sed > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"sed\".\n" ; exit 1 ; }
    command -v chmod > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"chmod\".\n" ; exit 1 ; }
    command -v mkdir > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"mkdir\".\n" ; exit 1 ; }
    command -v curl > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"curl\".\n" ; exit 1 ; }
    command -v wget > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"wget\".\n" ; exit 1 ; }
    command -v crontab > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"crontab\".\n" ; exit 1 ; }
    command -v systemctl > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemctl\".\n" ; exit 1 ; }
    command -v systemd-sysusers > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemd-sysusers\".\n" ; exit 1 ; }
    command -v systemd-tmpfiles > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemd-tmpfiles\".\n" ; exit 1 ; }

    # 检查和 GitHub 的网络连接是否正常，如果不正常则直接退出
    wget --spider --quiet --tries=3 --timeout=15 https://raw.githubusercontent.com || { echo -e "ERROR: Cannot connect to GitHub.\n" ; exit 1 ; }

    # 检查是否已安装 v2ray，若是则判断是否已安装最新版
    if [ -f '/usr/local/bin/v2ray' ]; then

        # 获取已安装的 v2ray 版本（不适用于 v5）
        v2ray_current_version="$(/usr/local/bin/v2ray -version 2> /dev/null | awk -F ' ' 'NR==1 {print $2}')"

        # 如果没获取到，则重新尝试获取已安装的 v2ray 版本（只适用于 v5）
        if [ -z "${v2ray_current_version}" ]; then
            v2ray_current_version="$(/usr/local/bin/v2ray version 2> /dev/null | awk -F ' ' 'NR==1 {print $2}')"
        fi

        # 获取 v2ray 最新 release 版本号
        v2ray_release_latest_version="$(curl -sS -H 'Accept: application/vnd.github+json' https://api.github.com/repos/v2fly/v2ray-core/releases/latest \
| grep 'tag_name' \
| awk -F '"' '{print $4}')"

        # 检查已安装版本是否是最新版本，若是则提示无新版本可供更新并退出
        if [ "${v2ray_current_version}" == "${v2ray_release_latest_version#v}" ]; then
            echo "=================================================="
            echo "No new version for update."
            echo "=================================================="
            exit 0
        fi

    fi

}

# 函数-设置 v2ray
set_v2ray() {

    # 安装 v2ray，如果安装失败则直接退出
    bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) || { echo -e "ERROR\: Install v2ray failed.\n" ; exit 1 ; }
    echo -e "\n"

    # 添加 systemd 专属用户配置
    echo 'u v2ray - "V2Ray Service" - -' > /usr/lib/sysusers.d/v2ray.conf

    # 检查 systemd 专属用户配置的 SHA256SUM 是否正确，如果错误则直接退出
    echo "caca9d88eff50ce7cd695b6fcab4d253344e92c966780f7de6d5c531d48ed80e  /usr/lib/sysusers.d/v2ray.conf" | sha256sum -c - || exit 1
    echo -e "\n"

    # 设置文件权限
    chmod 644 /usr/lib/sysusers.d/v2ray.conf

    # 添加 systemd 临时文件（夹）配置
    echo 'd /var/log/v2ray 0700 v2ray v2ray - -' > /usr/lib/tmpfiles.d/v2ray.conf

    # 检查 systemd 临时文件（夹）配置的 SHA256SUM 是否正确，如果错误则直接退出
    echo "ae55077bcf7140a7460f192adb03009b4573ec4420af84f4cbe9828cf8ca8e06  /usr/lib/tmpfiles.d/v2ray.conf" | sha256sum -c - || exit 1
    echo -e "\n"

    # 设置文件权限
    chmod 644 /usr/lib/tmpfiles.d/v2ray.conf

    # 使 systemd 专属用户配置生效
    # 若是首次创建 systemd 专属用户（v2ray），则额外显示空行以改善显示效果
    id v2ray &> /dev/null
    if [ "$?" != "0" ]; then
        systemd-sysusers v2ray.conf
        echo -e "\n"
    else
        systemd-sysusers v2ray.conf
    fi

    # 使 systemd 临时文件（夹）配置生效
    systemd-tmpfiles --create v2ray.conf

    # 修改 v2ray 服务
    cat << \EOF > ${v2ray_service_path}/v2ray.service
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
LimitCORE=infinity
LimitNOFILE=12800
LimitNPROC=12800
User=v2ray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target

EOF
    cat << \EOF > ${v2ray_service_path}/v2ray\@.service
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
LimitCORE=infinity
LimitNOFILE=12800
LimitNPROC=12800
User=v2ray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/%i.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target

EOF

    # 设置文件权限
    chmod 644 /etc/systemd/system/v2ray.service
    chmod 644 /etc/systemd/system/v2ray\@.service

    # 检查 v2ray 服务的 SHA256SUM 是否正确，如果错误则直接退出
    echo "46241bbae6e318954b374fc08f82b1f655225a23d8123ed3ef0ebf44433b8b5a  /etc/systemd/system/v2ray.service" | sha256sum -c - || exit 1
    echo -e "\n"
    echo '81373e66e3fbded5661f83a9e4971f5653f46f5fd6c39d4d8383fd5e287e9923  /etc/systemd/system/v2ray@.service' | sha256sum -c - || exit 1
    echo -e "\n"

    # 重新加载 v2ray 服务，使修改生效
    systemctl daemon-reload

}

# 函数-安装 v2ray
install_v2ray() {

    # 运行“函数-设置 v2ray”
    set_v2ray

    # 删除额外的 v2ray 服务文件
    rm -rf /etc/systemd/system/v2ray.service.d/*
    rm -rf /etc/systemd/system/v2ray\@.service.d/*

    # 重新加载 v2ray 服务，使修改生效
    systemctl daemon-reload

    # 删除可能存在的权限错误的日志文件
    rm -rf ${v2ray_log_path}/*

    # 删除可能存在的多配置文件
    rm -rf ${v2ray_config_path}/*

    # 创建证书文件存放文件夹
    mkdir -p ${v2ray_config_path}/cert

    # 修改文件夹所有者和组
    chown -R v2ray:v2ray ${v2ray_config_path}/cert

    # 创建日志管理脚本存放路径
    mkdir -p ${user_script_path}/

    # 创建日志管理脚本
    cat << EOF > ${user_script_path}/clean_v2ray_log.sh
#!/bin/bash

# 删除现有的日志备份文件
rm -f ${v2ray_log_path}/access.log.backup

# 生成当前日志的备份
cp ${v2ray_log_path}/access.log ${v2ray_log_path}/access.log.backup

# 清空当前的日志文件
cat /dev/null > ${v2ray_log_path}/access.log

EOF

    # 检查日志管理脚本的 SHA256SUM 是否正确，如果错误则直接退出
    echo "508af5fd7e78c786d04998ecc24cc0b0958afc3d2c8b72d11b90d0b3ffabc403  ${user_script_path}/clean_v2ray_log.sh" | sha256sum -c - || exit 1
    echo -e "\n"

    # 设置文件权限
    chmod 755 ${user_script_path}/clean_v2ray_log.sh

    # 导出现有的定时任务
    crontab -l > crontab.temp

    # 删除可能已经存在的自动清理日志的定时任务
    sed -i '/clean_v2ray_log\.sh/d' crontab.temp

    # 添加自动清理日志的定时任务，每个月清理一次
    echo "0 5 1 * * ${user_script_path}/clean_v2ray_log.sh > /dev/null 2>&1" >> crontab.temp

    # 使修改后的定时任务生效
    crontab crontab.temp

    # 删除临时文件
    rm crontab.temp

    # 提示安装完毕，并提示 v2ray 配置文件路径，以便修改
    echo "=================================================="
    echo "Install v2ray successful."
    echo ""
    echo "Config file path:"
    echo "${v2ray_config_path}/config.json"
    echo "=================================================="
    echo ""

}

# 函数-更新 v2ray
update_v2ray() {

    # 停止 v2ray
    systemctl stop v2ray

    # 等待 1s
    sleep 1

    # 运行“函数-设置 v2ray”
    set_v2ray

    # 等待 1s
    sleep 1

    # 启动 v2ray
    systemctl start v2ray

    # 等待 1s
    sleep 1

    # 显示 v2ray 运行状态
    systemctl status v2ray
    echo -e "\n"

    # 提示 v2ray 更新完毕
    echo "=================================================="
    echo "Update v2ray successful."
    echo "=================================================="
    echo ""

}

# 函数-主函数
main() {

    # 为显示内容做好准备
    echo -e "\n"

    # 运行“函数-运行前检查”
    check_before_running

    # 检查是否已安装 v2ray，如果已安装 v2ray，则运行“函数-更新 v2ray”，否则运行“函数-安装 v2ray”
    command -v v2ray > /dev/null 2>&1
    if [ "$?" == "0" ]; then
        update_v2ray
    else
        install_v2ray
    fi

}

# 运行“函数-主函数”
main

