#!/bin/bash
# date : 2023.7.1
# Use：初始化服务器
#

#骚气颜色
show_str_Black() {
	echo -e "\033[30m $1 \033[0m"
}
show_str_Red() {
	echo -e "\033[31m $1 \033[0m"
}
show_str_Green() {
	echo -e "\033[32m $1 \033[0m"
}
show_str_Yellow() {
	echo -e "\033[33m $1 \033[0m"
}
show_str_Blue() {
	echo -e "\033[34m $1 \033[0m"
}
show_str_Purple() {
	echo -e "\033[35m $1 \033[0m"
}
show_str_SkyBlue() {
	echo -e "\033[36m $1 \033[0m"
}
show_str_White() {
	echo -e "\033[37m $1 \033[0m"
}

#获取当前时间
DATE=$(date +"%Y-%m-%d %H:%M:%S")
#获取当前主机名
HOSTNAME=$(hostname -s)
#获取当前用户
USER=$(whoami)
#获取当前内核版本参数
KERNEL=$(uname -r | cut -f 1-3 -d.)
#获取当前系统版本
SYSTEM=$(cat /etc/redhat-release)

#检测网络链接畅通
function network() {
	#超时时间
	local timeout=1

	#目标网站
	local target=www.baidu.com

	#获取响应状态码
	local ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)

	if [ "x$ret_code" = "x200" ]; then
		#网络畅通
		return 1
	else
		#网络不畅通
		return 0
	fi

	return 0
}

source_profile() {
	echo 'export PS1="\[\033[01;31m\]\u\[\033[00m\]@\033[01;32m\]\H\[\033[00m\][\[\033[01;33m\]\t\[\033[00m\]]:\[\033[01;34m\]\W\[\033[00m\]\n$"' >>/etc/profile
	source /etc/profile
}

if [ "$UID" != "0" ]; then
	echo "Please run this script by root."
	exit 1
fi

#2.Configure sysctl
function start_configure_sysctl() {
	echo "Start configure sysctl......"
	cat >>/etc/sysctl.conf <<EOF
net.ipv4.tcp_syncookies = 0
fs.file-max = 2000000
fs.nr_open = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 3
net.ipv4.tcp_max_tw_buckets = 0
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.ip_local_port_range = 1025 65535
net.ipv4.ip_local_reserved_ports = 9999,8888,7891
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_wmem = 40960 163840 16777216
net.ipv4.tcp_rmem = 40960 163840 16777216
net.ipv4.tcp_mem = 12365824 16490496 24731648
net.ipv4.tcp_keepalive_time = 360000
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.netdev_max_backlog = 20000
net.core.optmem_max = 40960
net.core.somaxconn = 2048
net.netfilter.nf_conntrack_max = 2000000
EOF
	sysctl -p &>/dev/null
	# echo "configure sysctl is complete!"
}

#3.Create core dump
function create_core_dump() {
	# echo "Start create core dump......"
	echo "#config for  MRCS" >>/etc/profile
	echo 'ulimit -S -c unlimited > /dev/null 2>&1' >>/etc/profile
	echo "#end config for MRCS" >>/etc/profile
	echo 'core-%p-%t' >>/proc/sys/kernel/core_pattern
	source /etc/profile
	echo "Configure core dump is complete!"
}

#4.Handle number tuning
function handle_number_tuning() {
	# echo "Start Handle number tuning......"
	cat >>/etc/security/limits.conf <<EOF
* hard nofile 1000000
* soft nofile 1000000
EOF
	echo "Handle number tuning is complete!"
}

#5.Process number tuning
function process_number_tuning() {
	# echo "Start process number tuning......"
	sed -i 's/4096/1000000/g' /etc/security/limits.d/20-nproc.conf
	cat >>/etc/security/limits.d/20-nproc.conf <<EOF
* hard nproc 1000000
EOF
	echo "Process number tuning is complete!"
}

#7.Close selinux
function close_selinux() {
	# echo "Start close selinux......"
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	echo "Close selinux is complete!"
}

function printinput() {
	echo "========================================"
	cat <<EOF
|-------------系-统-信-息--------------
|  时间            :$DATE
|  主机名称        :$HOSTNAME
|  当前用户        :$USER
|  内核版本        :$KERNEL
|  系统版本        :$SYSTEM
----------------------------------------
----------------------------------------
|****请选择你要操作的项目:[0-3]****|
----------------------------------------
(1) 检查当前环境
(2) 初始化服务器
(0) 退出
EOF
	read -p "请选择[0-2]: " input
	case $input in
	1)
		network
		if [ $? -eq 0 ]; then
			show_str_Red "-------------------------------------------"
			show_str_Red "|                提醒！！！                |"
			show_str_Red "| 检测到当前服务器无网络，后续安装请选择离线安装！|"
			show_str_Red "-------------------------------------------"
			printinput
		else
			show_str_Green "-------------------------------------------"
			show_str_Green "|                提醒！！！                |"
			show_str_Green "|           当前服务器网络正常！！！       |"
			show_str_Green "-------------------------------------------"
		fi
		printinput
		;;
	2)
		source_profile
		start_configure_sysctl
		create_core_dump
		handle_number_tuning
		process_number_tuning
		close_selinux
		printinput
		;;

	0)
		clear
		exit 0
		;;
	*)
		show_str_Red "----------------------------------"
		show_str_Red "|            警告！！！            |"
		show_str_Red "|    请 输 入 正 确 的 选 项       |"
		show_str_Red "----------------------------------"
		for i in $(seq -w 3 -1 1); do
			echo -ne "\b\b$i"
			sleep 1
		done
		printinput
		;;
	esac
}

printinput
