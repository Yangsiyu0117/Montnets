#!/bin/bash
# date : 2023.7.1
# Use：Centos 7 and redhat 8
# Install Docker

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
		show_str_Green "========================================"
		show_str_Green "    该服务器网络正常！"
		show_str_Green "========================================"
		return 1
	else
		#网络不畅通
		show_str_Yellow "========================================"
		show_str_Yellow "   该服务器无网络！"
		show_str_Yellow "========================================"
		return 0
	fi

	return 0
}

#检测服务器网络状态
if [ $(cat /etc/redhat-release | awk '{print $1}') == "CentOS" ]; then
	#获取当前系统版本
	os=centos
	SYSTEM=$(cat /etc/redhat-release)
elif [[ $(cat /etc/redhat-release | awk '{print $1}') == "Red" ]]; then
	#获取当前系统版本
	os=redhat
	SYSTEM=$(cat /etc/redhat-release)
else
	show_str_Red "脚本不适配当前系统，请选择退出。谢谢！"
	exit 0
fi

log_file="docker_installlog_$(date +"%Y-%m-%d-%H%M%S").log"

#log_correct函数打印正常的输出到日志文件
function log_correct() {
	DATE=$(date "+%Y-%m-%d %H:%M:%S")
	USER=$(whoami) ####那个用户在操作
	show_str_Green "${DATE} ${USER} $0 [INFO] $@" >>/var/log/install/docker/$log_file
}

#log_error函数打印错误的输出到日志文件
function log_error() {
	DATE=$(date "+%Y-%m-%d %H:%M:%S")
	USER=$(whoami)
	show_str_Red "${DATE} ${USER} $0 [ERROR] $@" >>/var/log/install/docker/$log_file
}

docker_info() {
	show_str_Green "配置文件目录:/etc/docker/daemon.json"
	show_str_Green "数据存储目录:/opt/docker"
	show_str_Green "docker-network:172.16.0.0"
	show_str_Green "日志最大大小:500M"
}

check_docker() {
	systemctl status docker | grep running >/dev/null 2>&1
	if [ $(echo $?) -eq 0 ]; then
		show_str_Red "========================================"
		show_str_Red "  该服务器已经安装了docker服务，请检查！"
		show_str_Red "========================================"
		exit 0
	fi
}
uninstall_docker() {
	yum remove docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
	yum remove -y yum-utils
	rm -rf /etc/docker/daemon.json
}

online_install() {
	sudo yum install -y yum-utils >/dev/null 2>&1
	sudo yum-config-manager \--add-repo \
		https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
	sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y >/dev/null 2>&1
	mkdir -p /etc/docker
	cat >>/etc/docker/daemon.json <<EOF
{
  "data-root": "/opt/docker",
  "log-driver":"json-file",
  "log-opts": {"max-size":"500m", "max-file":"3"},
  "debug" : true,
  "default-address-pools" : [
    {
      "base" : "172.16.0.0/16",
      "size" : 24
    }
  ]
}
EOF
	sudo systemctl start docker >/dev/null 2>&1
	sudo systemctl enable docker >/dev/null 2>&1
	systemctl status docker | grep running >/dev/null 2>&1
	# 安装docker-compose
	sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

	sudo chmod +x /usr/local/bin/docker-compose

	sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
	if [ $(echo $?) -eq 0 ]; then
		return 1 #安装成功
	else
		return 0 #安装失败
	fi
}

offine_install() {
	SYSTEMDDIR=/usr/lib/systemd/system
	SERVICEFILE=docker.service
	DOCKERDIR=/usr/bin
	DOCKERBIN=docker
	SERVICENAME=docker
	DOCKERSOFTWARE=/data/package/docker/docker-24.0.2.tgz

	mkdir -p /opt/src
	tar xvpf $DOCKERSOFTWARE -C /opt/src/ >/dev/null 2>&1
	cd /opt/src/ && cp -p ${DOCKERBIN}/* ${DOCKERDIR} >/dev/null 2>&1
	which ${DOCKERBIN} >/dev/null 2>&1

	cat >${SYSTEMDDIR}/${SERVICEFILE} <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
 
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
 
[Install]
WantedBy=multi-user.target

EOF
	systemctl daemon-reload
	mkdir -p /etc/docker
	cat >>/etc/docker/daemon.json <<EOF
{
  "data-root": "/opt/docker",
  "log-driver":"json-file",
  "log-opts": {"max-size":"500m", "max-file":"3"},
  "debug" : true,
  "default-address-pools" : [
    {
      "base" : "172.16.0.0/16",
      "size" : 24
    }
  ]
}
EOF
	sudo systemctl start docker >/dev/null 2>&1
	sudo systemctl enable docker >/dev/null 2>&1
	systemctl status docker | grep running >/dev/null 2>&1
	if [ $(echo $?) -eq 0 ]; then
		return 1 #安装成功
	else
		return 0 #安装失败
	fi

}

check_docker
network
case $(echo $?) in
1)
	online_install
	;;

0)
	offine_install
	;;
esac

# function onCtrlC() {
# 	#捕获CTRL+C，当脚本被ctrl+c的形式终止时同时终止程序的后台进程
# 	kill -9 ${do_sth_pid} ${progress_pid}
# 	echo
# 	echo 'Ctrl+C is captured'
# 	exit 1
# }

# do_sth() {
# 	#运行的主程序
# 	check_docker
# 	network
# 	case $(echo $?) in
# 	1)
# 		online_install
# 		;;

# 	0)
# 		offine_install
# 		;;
# 	esac

# }

# progress() {
# 	#进度条程序
# 	local main_pid=$1
# 	local length=20
# 	local ratio=1
# 	while [ "$(ps -p ${main_pid} | wc -l)" -ne "1" ]; do
# 		mark='>'
# 		progress_bar=
# 		for i in $(seq 1 "${length}"); do
# 			if [ "$i" -gt "${ratio}" ]; then
# 				mark='-'
# 			fi
# 			progress_bar="${progress_bar}${mark}"
# 		done
# 		printf "Progress: ${progress_bar}\r"
# 		ratio=$((ratio + 1))
# 		#ratio=`expr ${ratio} + 1`
# 		if [ "${ratio}" -gt "${length}" ]; then
# 			ratio=1
# 		fi
# 		sleep 0.1
# 	done
# }

# do_sth &
# do_sth_pid=$(jobs -p | tail -1)

# progress "${do_sth_pid}" &
# progress_pid=$(jobs -p | tail -1)

# wait "${do_sth_pid}"
# printf "Install docker: done                \n"
