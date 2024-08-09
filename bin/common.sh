#!/usr/bin/env bash
# apinto utils function script

#project dir
ORGPATH=$(pwd)
# script base dir 
CMD=$(cd `dirname $0`;pwd)
# workspace base dir
BasePath=$(cd `dirname $0`;cd ..;pwd)
UserPath=$(cd ~;pwd)
VERSION=0.17.7
IMG_FULL_NAME=

INNER_ROUTE_PORT=8099
INNER_API_PORT=9400
INNER_CLUSTER_PORT=9401

ApintoNodeName=apinto_node

function source_env(){
    if [ ! -f "$BasePath/.env" ]; then
        echo -e "\033[31m🤮 Miss .env in workspace, \033[31mplease cp env.example .env & modify content.\033[0m"
        exit 1
    fi

    source $BasePath/.env
}

function getImageName(){
    if [[ "$1" = true ]];then
        echo "${REPO_HOST}/${REPO_NAMESPACE}/${REPO_IMG_NAME}:${VERSION}-${ARCH}"
        return
    fi
    echo "${REPO_NAMESPACE}/${REPO_IMG_NAME}:${VERSION}-${ARCH}"
}

# ports
function parse_expose_ports(){
    if [ -n "$1" ];then
        local OLD_IFS="$IFS"
        IFS=","
        local arr=($1)
        local len=${#arr[@]}
        IFS="$OLD_IFS"

        if [[ $len -eq 2 ]]; then
            echo "-p ${arr[0]}:${INNER_ROUTE_PORT} -p ${arr[1]}:${INNER_API_PORT}"
            return 
        elif [[ $len -eq 3 ]]; then 
            echo "-p ${arr[0]}:${INNER_ROUTE_PORT} -p ${arr[1]}:${INNER_API_PORT} -p ${arr[2]}:${INNER_CLUSTER_PORT}"
            return 
        fi
    fi

    echo "-p ${INNER_ROUTE_PORT}:${INNER_ROUTE_PORT} -p ${INNER_API_PORT}:${INNER_API_PORT}"
}

function show_apinto_success_doc(){
    local v_host_ip=$(ip route get 1 | sed 's/^.*src \([^ ]*\).*$/\1/;q')


    echo -e "\033[32m✨✨✨ Run ${ApintoNodeName} successful. 🚀🚀🚀\033[0m"
    echo -e "\033[33m  Node IP: ${v_host_ip}\033[0m"


    if [ -n "$1" ];then 
        local OLD_IFS="$IFS"
        IFS=","
        local arr=($1)
        local len=${#arr[@]}
        IFS="$OLD_IFS"
        if [[ $len -ge 2 ]]; then
            echo -e "\033[35m  转发服务的广播地址\t\t: http://${v_host_ip}:${arr[0]}\033[0m"
            echo -e "\033[35m  服务的广播地址\t\t: http://${v_host_ip}:${arr[1]}\033[0m"
        fi
    else 
        echo -e "\033[35m  转发服务的广播地址\t\t: http://${v_host_ip}:${INNER_ROUTE_PORT}\033[0m"
        echo -e "\033[35m  服务的广播地址\t\t: http://${v_host_ip}:${INNER_API_PORT}\033[0m"
    fi

}

# /data/
function prepare_node_base(){
    local node_base_dir=${BasePath}/${ApintoNodeName}

    if [[ "$1" =~ ^/([\.a-zA-Z0-9_\-]+/?)+$ ]];then 
        local node_base_dir=$1/${ApintoNodeName}
    elif [[ "$1" =~ ^./([\.a-zA-Z0-9_\-]+/?)+$ ]];then
        local node_base_dir=${UserPath}${"$1":2}/${ApintoNodeName}
    else 
        local node_base_dir=${UserPath}$1/${ApintoNodeName}
    fi


    if [ ! -d "${node_base_dir}/data" ]; then
        if [[ `mkdir -p "${node_base_dir}/data"` -ne 0 ]];then
            echo -e "\033[31m🤮 Cannot create folder at ${node_base_dir}/data.\033[0m"
            exit 1;
        fi 
    fi

    if [ ! -d "${node_base_dir}/conf" ]; then
        if [[ `mkdir -p "${node_base_dir}/conf"` -ne 0 ]];then
            echo -e "\033[31m🤮 Cannot create folder at ${node_base_dir}/conf.\033[0m"
            exit 1;
        fi 
    fi

        if [ ! -d "${node_base_dir}/log" ]; then
        if [[ `mkdir -p "${node_base_dir}/log"` -ne 0 ]];then
            echo -e "\033[31m🤮 Cannot create folder at ${node_base_dir}/log.\033[0m"
            exit 1;
        fi 
    fi

    echo "${node_base_dir}"
    return 
}

function create_config_yml(){
    local f=$1

    local v_ip=$(ip route get 1 | sed 's/^.*src \([^ ]*\).*$/\1/;q')

    # write
    if [ -f "$f" ];then
        echo -e "\033[33m config file [$f] exists.skip created.\033[0m"
        # return
    else 
        touch $f
    fi

cat << EOF > $f
version: 2
# certificate: # 证书存放根目录
# dir: /etc/apinto/cert
client:
  #advertise_urls: # open api 服务的广播地址
  #- http://${v_ip}:9400
  listen_urls: # open api 服务的监听地址
    - http://0.0.0.0:9400
  #certificate:  # 证书配置，允许使用ip的自签证书
  #  - cert: server.pem
  #    key: server.key
gateway:
  #advertise_urls: # 转发服务的广播地址
  #- http://${v_ip}:9400
  listen_urls: # 转发服务的监听地址
    - https://0.0.0.0:8099
    - http://0.0.0.0:8099
peer: # 集群间节点通信配置信息
  listen_urls: # 节点监听地址
    - http://0.0.0.0:9401
  #advertise_urls: # 节点通信广播地址
  # - http://127.0.0.1:9400
  #certificate:  # 证书配置，允许使用ip的自签证书
  #  - cert: server.pem
  #    key: server.key

EOF

}

