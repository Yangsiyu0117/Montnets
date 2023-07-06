#!/bin/bash
# date : 2023.7.1
# Use：Centos 7 and redhat 8
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

###
### Install Main Script
###
### Usage:
###   bash main.sh -h
###   logfile in /var/log/install/logfile_`date +"%Y-%m-%d-%H%M%S"`.log
###          日志文件可以帮助你快速排错
###   checkfile in /var/log/install/check_file_`date +"%Y-%m-%d-%H%M%S"
###          检查文件可以帮你确认配置是否修改正确
### Options:
###   -h --help    Show this message.

help() {
	sed -rn 's/^### ?//;T;p' "$0"
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	help
	exit 1
fi

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

lan_ip=$(ifconfig | grep inet | grep netmask | awk '{print $2}' | head -n 1)
log_file="logfile_$(date +"%Y-%m-%d-%H%M%S").log"

# #打印中控机ip
# echo "$(ip)" ./.controller_ip

#log_correct函数打印正常的输出到日志文件
function log_correct() {
	DATE=$(date "+%Y-%m-%d %H:%M:%S")
	USER=$(whoami) ####那个用户在操作
	show_str_Green "${DATE} ${USER} $0 [INFO] $@" >>/var/log/install/$log_file
}

#log_error函数打印错误的输出到日志文件
function log_error() {
	DATE=$(date "+%Y-%m-%d %H:%M:%S")
	USER=$(whoami)
	show_str_Red "${DATE} ${USER} $0 [ERROR] $@" >>/var/log/install/$log_file
}

mkdir_dir() {
	for ip in $(awk '/^[0-9]/{print $1}' install.config | sort -u); do
		ssh $ip "mkdir -p /data/{config,package,script}"
	done
}

install_rsync() {
	rsync_package=./package/rsync/rsync-3.1.2-10.el7.x86_64.rpm
	rpm -ivh $rsync_package >/dev/null

}

configure_ssh_without_pass() {
	[ ! -f $HOME/.ssh/id_rsa ] && ssh-keygen -t rsa -b 2048 -N "" -f $HOME/.ssh/id_rsa
	if ! grep -Ff $HOME/.ssh/id_rsa.pub $HOME/.ssh/authorized_keys &>/dev/null; then
		cat $HOME/.ssh/id_rsa.pub >>$HOME/.ssh/authorized_keys
	fi
	chmod 600 $HOME/.ssh/authorized_keys

	for ip in $(awk '/^[0-9]/{print $1}' install.config | sort -u); do
		# ssh-copy-id -o StrictHostKeyChecking=no -o CheckHostIP=no root@$ip
		rsync -a $HOME/.ssh/id_rsa* $HOME/.ssh/authorized_keys -e 'ssh -o StrictHostKeyChecking=no -o CheckHostIP=no' root@$ip:/root/.ssh/
	done
}
red_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[031;1m$@\033[0m"; }
green_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[032;1m$@\033[0m"; }
yellow_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[033;1m$@\033[0m"; }
blue_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[034;1m$@\033[0m"; }
purple_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[035;1m$@\033[0m"; }
bred_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[041;1m$@\033[0m"; }
bgreen_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[042;1m$@\033[0m"; }
byellow_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[043;1m$@\033[0m"; }
bblue_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[044;1m$@\033[0m"; }
bpurple_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[045;1m$@\033[0m"; }
bgreen_echo() { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[042;34;1m$@\033[0m"; }

function printinput() {
	echo "========================================"
	cat <<EOF
|-------------系-统-信-息--------------
|  时间            :$DATE                                        
|  主机名称        :$HOSTNAME
|  当前用户        :$USER                                        
|  内核版本        :$KERNEL
|  系统版本        :$SYSTEM
|  LAN_IP         :$lan_ip    
----------------------------------------
----------------------------------------
|****请选择你要操作的项目:[0-3]****|
----------------------------------------
(1) 初始化服务器
(2) 安装docker
(3) 安装docker-compose
(4) 安装JDK1.8
(5) 安装JDK1.7
(0) 退出
EOF

	read -p "请选择[0-4]: " input
	case $input in
	1)
		# for ip in $(awk '/^[0-9]/{print $1}' install.config); do
		# 	scp -r -P 22 $rsync_package root@$ip
		# done
		# install_rsync
		configure_ssh_without_pass
		mkdir_dir
		for ip in $(awk '/^[0-9]/{print $1}' install.config); do
			echo "当前$(green_echo ${ip})服务器正在初始化"
			rsync -a /data/initdata.sh root@${ip}:/data/
			ssh root@${ip} "sh /data/initdata.sh"
		done

		if [[ $(echo $?) -eq 0 ]]; then
			show_str_Green "----------------------------------"
			show_str_Green "|            提示！！！            |"
			show_str_Green "|     服 务 器 初 始 化 完 成      |"
			show_str_Green "----------------------------------"
		else
			show_str_Red "----------------------------------"
			show_str_Red "|            警告！！！            |"
			show_str_Red "|     服 务 器 初 始 化 失 败      |"
			show_str_Red "----------------------------------"
		fi
		printinput

		;;
	2)

		function onCtrlC() {
			#捕获CTRL+C，当脚本被ctrl+c的形式终止时同时终止程序的后台进程
			kill -9 ${do_sth_pid} ${progress_pid}
			echo
			echo 'Ctrl+C is captured'
			exit 1
		}

		do_sth() {
			#运行的主程序
			mkdir_dir
			for ip in $(cat install.config | grep docker | awk '/^[0-9]/{print $1}'); do
				echo "当前$(green_echo ${ip})服务器正在安装docker"
				rsync -a /data/script/install_docker.sh root@${ip}:/data/script/
				rsync -a /data/package/docker root@${ip}:/data/package/
				ssh root@${ip} "sh /data/script/install_docker.sh"
			done

		}

		progress() {
			#进度条程序
			local main_pid=$1
			local length=20
			local ratio=1
			while [ "$(ps -p ${main_pid} | wc -l)" -ne "1" ]; do
				mark='>'
				progress_bar=
				for i in $(seq 1 "${length}"); do
					if [ "$i" -gt "${ratio}" ]; then
						mark='-'
					fi
					progress_bar="${progress_bar}${mark}"
				done
				printf "Progress: ${progress_bar}\r"
				ratio=$((ratio + 1))
				#ratio=`expr ${ratio} + 1`
				if [ "${ratio}" -gt "${length}" ]; then
					ratio=1
				fi
				sleep 0.1
			done
		}

		do_sth &
		do_sth_pid=$(jobs -p | tail -1)

		progress "${do_sth_pid}" &
		progress_pid=$(jobs -p | tail -1)

		wait "${do_sth_pid}"
		printf "Install docker: done                \n"
		printinput
		;;

	3) ;;

	4) ;;

	5) ;;

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
