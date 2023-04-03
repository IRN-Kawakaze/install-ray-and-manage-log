#!/bin/bash

# 函数-运行前检查
check_before_running() {
    # 判断脚本是否由 root 用户运行，如果不是，则报错并退出
    [ "$(whoami)" == "root" ] || { echo -e "ERROR: This script must be run by root, please run \"sudo su\" before running this script.\n"; exit 1; }

    # 判断 /etc/debian_version 文件是否存在，如果不存在，则报错并退出
    [ -f /etc/debian_version ] || { echo -e "ERROR: This system is not supported, please install Debian.\n"; exit 1; }

    # 判断 /usr/local/bin 文件夹是否存在，如果不存在，则报错并退出
    [ -d /usr/local/bin ] || { echo -e "ERROR: Directory /usr/local/bin does not exist.\n"; exit 1; }

    # 检查依赖
    which jq > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"jq\".\n"; exit 1; }
    which rm > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"rm\".\n"; exit 1; }
    which 7za > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"7za\".\n"; exit 1; }
    which cat > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"cat\".\n"; exit 1; }
    which sed > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"sed\".\n"; exit 1; }
    which chmod > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"chmod\".\n"; exit 1; }
    which mkdir > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"mkdir\".\n"; exit 1; }
    which curl > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"curl\".\n"; exit 1; }
    which wget > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"wget\".\n"; exit 1; }
    which crontab > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"crontab\".\n"; exit 1; }
    which systemctl > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemctl\".\n"; exit 1; }
    which systemd-sysusers > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemd-sysusers\".\n"; exit 1; }
    which systemd-tmpfiles > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"systemd-tmpfiles\".\n"; exit 1; }

    # 检查和 GitHub 的网络连接是否正常，如果不正常则直接退出
    wget --spider --quiet --tries=3 --timeout=15 https://github.com || { echo -e "ERROR: Cannot connect to \"github.com\".\n"; exit 1; }
    wget --spider --quiet --tries=3 --timeout=15 https://raw.githubusercontent.com || { echo -e "ERROR: Cannot connect to \"raw.githubusercontent.com\".\n"; exit 1; }

    # 获取 ray 的最新 release 的版本号
    ray_latest_release_version="$(curl -sS -H 'Accept: application/vnd.github+json' https://api.github.com/repos/${ray_repo}/releases/latest | jq -r .tag_name)"

    # 检查是否获取失败，若获取失败则报错并退出
    [ "${ray_latest_release_version}" == "null" ] && { echo -e "ERROR: Github API rate limit exceeded.\n"; exit 1; }
    [ -z "${ray_latest_release_version}" ] && { echo -e "ERROR: Get ${ray_type} latest release version failed.\n"; exit 1; }

    # 检查是否已安装 ray，若是则判断是否已安装最新版
    if [ -f "/usr/local/bin/${ray_type}" ]; then
        # 获取已安装的 ray 版本（不适用于 v5）
        ray_current_version="$(/usr/local/bin/${ray_type} -version 2> /dev/null | awk -F ' ' 'NR==1 {print $2}')"

        # 如果没获取到，则重新尝试获取已安装的 ray 版本（适用于 v5）
        if [ -z "${ray_current_version}" ]; then
            ray_current_version="$(/usr/local/bin/${ray_type} version 2> /dev/null | awk -F ' ' 'NR==1 {print $2}')"
        fi

        # 检查已安装版本是否是最新版本，若是则提示无新版本可供升级并退出
        if [ "${ray_current_version}" == "${ray_latest_release_version#v}" ]; then
            echo "=================================================="
            echo "No new version for upgrade."
            echo "=================================================="
            echo ""
            exit 0
        fi
    fi
}

# 函数-安装 ray
inst_ray() {
    # 获取系统架构并转换成对应的 ray 安装包架构（对应关系取自 fhs-install-v2ray 脚本）
    case "$(uname -m)" in
        'i386' | 'i686')
            sys_arch='32'
            ;;
        'amd64' | 'x86_64')
            sys_arch='64'
            ;;
        'armv5tel')
            sys_arch='arm32-v5'
            ;;
        'armv6l')
            sys_arch='arm32-v6'
            grep Features /proc/cpuinfo | grep -qw 'vfp' || sys_arch='arm32-v5'
            ;;
        'armv7' | 'armv7l')
            sys_arch='arm32-v7a'
            grep Features /proc/cpuinfo | grep -qw 'vfp' || sys_arch='arm32-v5'
            ;;
        'armv8' | 'aarch64')
            sys_arch='arm64-v8a'
            ;;
        'mips')
            sys_arch='mips32'
            ;;
        'mipsle')
            sys_arch='mips32le'
            ;;
        'mips64')
            sys_arch='mips64'
            ;;
        'mips64le')
            sys_arch='mips64le'
            ;;
        'ppc64')
            sys_arch='ppc64'
            ;;
        'ppc64le')
            sys_arch='ppc64le'
            ;;
        'riscv64')
            sys_arch='riscv64'
            ;;
        's390x')
            sys_arch='s390x'
            ;;
        *)
            echo "ERROR: Unsupported system architecture."
            echo ""
            exit 1
            ;;
    esac

    # 创建临时存放文件夹
    dl_tmp_dir="$(mktemp -d)"

    # 下载 ray 到临时存放文件夹
    wget "https://github.com/${ray_repo}/releases/download/${ray_latest_release_version}/${ray_type}-linux-${sys_arch}.zip" -P "${dl_tmp_dir}" || exit 1
    echo -e "\n"

    # 检查安装包
    7za t "${dl_tmp_dir}/${ray_type}-linux-${sys_arch}.zip" || exit 1
    echo -e "\n"

    # 解压（注意，7za 命令的 -o 参数后面接路径时两者之间不能有空格）
    7za x "${dl_tmp_dir}/${ray_type}-linux-${sys_arch}.zip" -o"${dl_tmp_dir}" || exit 1
    echo -e "\n"

    # 安装 ray
    install "${dl_tmp_dir}/${ray_type}" "/usr/local/bin/${ray_type}"
    chmod 755 "/usr/local/bin/${ray_type}"

    # 若 geo 文件夹不存在，则创建 geo 文件夹
    if [ ! -d "/usr/local/share/${ray_type}" ]; then
        mkdir -p "/usr/local/share/${ray_type}"
        chmod 755 "/usr/local/share/${ray_type}"
    fi

    # 安装 geo 文件
    cp "${dl_tmp_dir}/geoip.dat" "/usr/local/share/${ray_type}/geoip.dat"
    cp "${dl_tmp_dir}/geosite.dat" "/usr/local/share/${ray_type}/geosite.dat"
    chmod 644 "/usr/local/share/${ray_type}/geoip.dat"
    chmod 644 "/usr/local/share/${ray_type}/geosite.dat"

    # 删除临时存放文件夹
    rm -rf "${dl_tmp_dir}"
}

# 函数-创建用户（组）和临时文件（夹）
create_user_and_tmp() {
    # 添加 systemd 专属用户配置
    [ "${ray_type}" == "v2ray" ] && echo 'u v2ray - "V2Ray Service" - -' > /usr/lib/sysusers.d/${ray_type}.conf
    [ "${ray_type}" == "xray" ] && echo 'u xray - "Xray Service" - -' > /usr/lib/sysusers.d/${ray_type}.conf

    # 设置文件权限
    chmod 644 /usr/lib/sysusers.d/${ray_type}.conf

    # 使 systemd 专属用户配置生效
    systemd-sysusers ${ray_type}.conf
    echo -e "\n"

    # 添加 systemd 临时文件（夹）配置
    [ "${ray_type}" == "v2ray" ] && echo 'd /var/log/v2ray 0700 v2ray v2ray - -' > /usr/lib/tmpfiles.d/${ray_type}.conf
    [ "${ray_type}" == "xray" ] && echo 'd /var/log/xray 0700 xray xray - -' > /usr/lib/tmpfiles.d/${ray_type}.conf

    # 设置文件权限
    chmod 644 /usr/lib/tmpfiles.d/${ray_type}.conf

    # 使 systemd 临时文件（夹）配置生效
    systemd-tmpfiles --create ${ray_type}.conf
}

# 函数-创建配置文件夹
create_conf_dir() {
    # 创建文件夹
    mkdir -p "${ray_config_path}"
    mkdir -p "${ray_config_path}/ssl"
    mkdir -p "${ray_config_path}/backup"

    # 修改文件夹的所有者和组
    chown -R ${ray_type}:${ray_type} ${ray_config_path}
}

# 函数-创建服务
create_service() {
    # 创建 ray 服务文件
    cat << \EOF > ${ray_service_path}/${ray_type}.service
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
    cat << \EOF > ${ray_service_path}/${ray_type}\@.service
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
    chmod 644 ${ray_service_path}/${ray_type}.service
    chmod 644 ${ray_service_path}/${ray_type}\@.service

    # 检查 ray 服务的 SHA256SUM 是否正确，如果错误则直接退出
    echo "46241bbae6e318954b374fc08f82b1f655225a23d8123ed3ef0ebf44433b8b5a  ${ray_service_path}/${ray_type}.service" | sha256sum -c - || exit 1
    echo -e "\n"
    echo "81373e66e3fbded5661f83a9e4971f5653f46f5fd6c39d4d8383fd5e287e9923  ${ray_service_path}/${ray_type}@.service" | sha256sum -c - || exit 1
    echo -e "\n"

    # 修改服务文件
    if [ "${ray_type}" == "xray" ]; then
        # .service 文件
        sed -i 's|V2Ray Service|Xray Service|g' ${ray_service_path}/${ray_type}.service
        sed -i 's|https://www.v2fly.org/|https://github.com/xtls|g' ${ray_service_path}/${ray_type}.service
        sed -i 's|User=v2ray|User=xray|g' ${ray_service_path}/${ray_type}.service
        sed -i 's|/usr/local/bin/v2ray|/usr/local/bin/xray|g' ${ray_service_path}/${ray_type}.service
        sed -i 's|/usr/local/etc/v2ray|/usr/local/etc/xray|g' ${ray_service_path}/${ray_type}.service

        # \@.service 文件
        sed -i 's|V2Ray Service|Xray Service|g' ${ray_service_path}/${ray_type}\@.service
        sed -i 's|https://www.v2fly.org/|https://github.com/xtls|g' ${ray_service_path}/${ray_type}\@.service
        sed -i 's|User=v2ray|User=xray|g' ${ray_service_path}/${ray_type}\@.service
        sed -i 's|/usr/local/bin/v2ray|/usr/local/bin/xray|g' ${ray_service_path}/${ray_type}\@.service
        sed -i 's|/usr/local/etc/v2ray|/usr/local/etc/xray|g' ${ray_service_path}/${ray_type}\@.service
    fi

    # 创建 ray 服务文件目录
    mkdir -p ${ray_service_path}/${ray_type}.service.d
    mkdir -p ${ray_service_path}/${ray_type}\@.service.d

    # 设置目录权限
    chmod 755 ${ray_service_path}/${ray_type}.service.d
    chmod 755 ${ray_service_path}/${ray_type}\@.service.d

    # 重新加载服务，使修改生效
    systemctl daemon-reload
}

# 函数-管理日志
manage_log() {
    # 创建“清理 ray 日志”脚本的存放路径
    mkdir -p ${user_script_path}

    # 创建“清理 ray 日志”脚本
    cat << EOF > ${user_script_path}/clean_${ray_type}_log.sh
#!/bin/bash

source /etc/profile

# 删除现有的日志备份文件
rm -f ${ray_log_path}/access.log.backup

# 生成当前日志的备份
cp ${ray_log_path}/access.log ${ray_log_path}/access.log.backup

# 清空当前的日志文件
cat /dev/null > ${ray_log_path}/access.log

EOF

    # 设置文件权限
    chmod 755 ${user_script_path}/clean_${ray_type}_log.sh

    # 导出现有的定时任务
    crontab -l > crontab.temp || echo -e "\n"

    # 添加自动清理日志的定时任务，每个月清理一次
    echo "0 5 1 * * ${user_script_path}/clean_${ray_type}_log.sh > /dev/null 2>&1" >> crontab.temp

    # 使修改后的定时任务生效
    crontab crontab.temp

    # 删除临时文件
    rm crontab.temp
}

# 函数-重启服务
restart_service() {
    # 逐个重启所有运行中的 ray 服务
    while read running_service_name; do
        systemctl restart ${running_service_name}
        sleep 2
        systemctl status ${running_service_name}
        echo -e "\n"
    done <<< "$(systemctl list-units --type=service --state=running | grep "${ray_type}" | awk -F ' ' '{print $1}')"
}

# 函数-安装流程
inst_cmd() {
    # 运行“函数-安装 ray”
    inst_ray

    # 运行“函数-创建用户（组）和临时文件（夹）”
    create_user_and_tmp

    # 运行“函数-创建配置文件夹”
    create_conf_dir

    # 运行“函数-创建服务”
    create_service

    # 运行“函数-管理日志”
    manage_log

    # 提示安装完毕，并提示 ray 配置文件路径，以便修改
    echo "=================================================="
    echo "Install ${ray_type} successful."
    echo ""
    echo "Config file path:"
    echo "${ray_config_path}/config.json"
    echo "=================================================="
    echo ""
}

# 函数-升级流程
upgr_cmd() {
    # 运行“函数-安装 ray”
    inst_ray

    # 运行“函数-重启服务”
    restart_service

    # 提示 ray 升级完毕
    echo "=================================================="
    echo "Upgrade ${ray_type} successful."
    echo "=================================================="
    echo ""
}

# 函数-主函数
main() {
    # 为显示内容做好准备
    echo -e "\n"

    # 获取 ray_type 和 ray_repo
    case "${1}" in
        'v2ray' | 'v2')
            ray_type="v2ray"
            ray_repo="v2fly/v2ray-core"
            ;;
        'xray' | 'x')
            ray_type="xray"
            ray_repo="xtls/xray-core"
            ;;
        *)
            echo "ERROR: Unsupported *ray type."
            echo ""
            exit 1
            ;;
    esac

    # 设置路径变量，路径尾部均不需要以“/”结尾
    ray_config_path="/usr/local/etc/${ray_type}"
    ray_log_path="/var/log/${ray_type}"
    ray_service_path="/etc/systemd/system"
    user_script_path="/etc/user_scripts"

    # 运行“函数-运行前检查”
    check_before_running

    # 检查是否已安装 ray，如果已安装 ray，则进行升级，否则进行安装
    if { which ${ray_type} > /dev/null 2>&1; }; then
        # 运行“函数-升级流程”
        upgr_cmd
    else
        # 运行“函数-安装流程”
        inst_cmd
    fi
}

# 运行“函数-主函数”
# 函数需使用 "${@}" 接收传参，使用 ${@} 而非 ${*} 以确保多个参数不会被合并成 ${1}，套上 "" 以确保带空格的参数不会在传入时被拆分
main "${@}"

