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


# 检查依赖
command -v wget > /dev/null 2>&1 || { echo "ERROR\: You should install \"wget\" first." ; exit 1 ; }
command -v curl > /dev/null 2>&1 || { echo "ERROR\: You should install \"curl\" first." ; exit 1 ; }
command -v crontab > /dev/null 2>&1 || { echo "ERROR\: You should install \"crontab\" first." ; exit 1 ; }
command -v systemctl > /dev/null 2>&1 || { echo "ERROR\: You should install \"systemctl\" first." ; exit 1 ; }
command -v rm > /dev/null 2>&1 || { echo "ERROR\: Cannot run \"rm\" command." ; exit 1 ; }
command -v mkdir > /dev/null 2>&1 || { echo "ERROR\: Cannot run \"mkdir\" command." ; exit 1 ; }
command -v chmod > /dev/null 2>&1 || { echo "ERROR\: Cannot run \"chmod\" command." ; exit 1 ; }
command -v cat > /dev/null 2>&1 || { echo "ERROR\: Cannot run \"cat\" command." ; exit 1 ; }
command -v sed > /dev/null 2>&1 || { echo "ERROR\: Cannot run \"sed\" command." ; exit 1 ; }

# 检查和 GitHub 的网络连接是否正常，如果不正常则直接退出
wget -4 --spider --quiet --tries=3 --timeout=3 https://raw.githubusercontent.com || { echo "ERROR\: Cannot connect to GitHub." ; exit 1 ; }    

# 安装 v2ray，如果安装失败则直接退出
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) || { echo "ERROR\: Install v2ray failed." ; exit 1 ; }    

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

# 清除对 service 文件的修改
sed -i '/LimitCORE=/d' ${v2ray_service_file} && sed -i '/LimitNOFILE=/d' ${v2ray_service_file} && sed -i '/LimitNPROC=/d' ${v2ray_service_file}

# 修改 v2ray 的最大句柄数和最大进程数
sed -i '/\[Service\]/a\LimitCORE=infinity\nLimitNOFILE=12800\nLimitNPROC=12800' ${v2ray_service_file}
systemctl daemon-reload

# 打印 v2ray 配置文件路径，以便修改
echo -e "\n"
echo "=================================================="
echo "Config file path:"
echo "${v2ray_config_path}/config.json"
echo "=================================================="

