#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

CONFIG_DIR='/etc/consul'
LOCAL_IP=$(ip addr | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -E -v "^127\.|^255\.|^0\." | head -n 1)
echo "LOCAL_IP:" $LOCAL_IP

ui=0
leader=0
leaderip=""
node=""
port=0
userName=""
password=""

function init() {
    set -- $(getopt -l port:leaderip:leader: "$@")
    # -o 接收短参数， -l 接收长参数， 需要参数值的在参数后面添加: 。
    while [ -n "$1" ]; do
      case "$1" in
      -u)
        userName=$2
        shift
        ;;
      -p)
        password=$2
        shift
        ;;
      --port)
        port=$2
        shift
        ;;
      --leader)
        leader=1
        shift
        ;;
      --leaderip)
        leaderip=$2
        shift
        ;;
      --node)
        node=$2
        shift
        ;;
      --option)
        option=$2
        shift
        ;;
      --ui)
        ui=1
        shift
        ;;
      esac
      shift
    done
}

function usage() {
  echo "
Usage:
shell --leader true --node s1
shell --leaderip \"\" --node s2
"
  echo "--leader: ${leader}"
  echo "--leaderip: ${leaderip}"
  echo "--node: ${node}"
  echo "--option: ${option}"
  echo "--ui: ${ui}"
}

usage

download_consul() {
  echo "Download Consul.."
  wget https://releases.hashicorp.com/consul/1.14.2/consul_1.14.2_linux_amd64.zip
  unzip consul_1.14.2_linux_amd64.zip
  mv consul /usr/local/bin/
  mkdir -p /data/consul/{data,config}
  rm -rf consul_1.14.2_linux_amd64.zip
}

init_config() {
  touch ${CONFIG_DIR}
  : >${CONFIG_DIR}

  if [[ ${leader} -eq 1 ]]; then
    cat >${CONFIG_DIR} <<EOF
CMD_OPTS="agent -server -data-dir=/data/consul/data -node=${node} -config-dir=${CONFIG_DIR} -bind=${LOCAL_IP} -rejoin -client=0.0.0.0 -bootstrap"
EOF
  elif [[ ${leader} -eq 0 && ${leaderip} != "" ]]; then
    cat >${CONFIG_DIR} <<EOF
CMD_OPTS="agent -server -data-dir=/opt/consul/data -node=${node} -config-dir=${CONFIG_DIR} -bind=${LOCAL_IP} -rejoin -client=0.0.0.0 -join ${leaderip}"
EOF
  fi

  cat ${CONFIG_DIR}
}

install_system_service() {
  touch /usr/lib/systemd/system/consul.service
  cat >/usr/lib/systemd/system/consul.service <<EOF
  [Unit]
  Description=consul
  After=network.target

  [Service]
  EnvironmentFile=${CONFIG_DIR}
  ExecStart=/usr/local/bin/consul \$CMD_OPTS
  ExecReload=/bin/kill -HUP \$MAINPID
  KillSignal=SIGTERM

  [Install]
  WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable consul
  systemctl status consul

}

show_consul_status() {
  consul members
}

main() {
  echo "doing..."
  echo "doing..."
  echo "doing..."
  if [[ $node == "" ]]; then
    echo "error: -node parameter cannot be empty!"
    exit 1
  fi

  if [[ $leader -eq 0 && $leaderip == "" ]]; then
    echo "error: -leaderip parameter cannot be empty!"
    exit 1
  fi

  download_consul
  init_config
  install_system_service
  show_consul_status
}

main

exit 0
