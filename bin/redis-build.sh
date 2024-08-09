#!/bin/bash 
basepath=$(cd `dirname $0`;pwd);
workspace=$(cd `dirname $0`;cd ..;pwd);

NETWORK_NAME=xai-network
REDIS_MIN_PORT=7201
REDIS_MAX_PORT=7205
REDIS_PASSWORD=admin123
DOCKER_VHOST=172.20.0.1
NODE_COUNTS=

REDIS_DATA_BASE=redis
REDIS_CONTAINER_NAME_PREFIX=redis

EC_CMD=
ROOT_DIR=$workspace
# ROOT_DIR=$(cd ~/.xai-data;pwd)

if [ ! -d $ROOT_DIR ];then
    mkdir -p $ROOT_DIR
fi

echo -e "\033[35m project root: $ROOT_DIR \033[0m"

# rebuild args
ARGS=$(getopt -o 'hp:s:v::' --long 'help,port:,size:,version::' -n "$0" -- "$@")

# 将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"

# Command pull|up|down|remove|rmi|pull-up
function show_help() {
  echo -e "\033[31mCommands Help :\n\033[0m";
  echo -e '\033[35m$ deploy \033[0m';
  echo -e "\033[35m$ deploy <options?> <command>\033[0m";
  echo -e "\033[34mDeploy options: \033[0m ";
  echo -e "\033[35m$ make -e<env-file> or <--env=env-file>: use env file.\033[0m";  
  echo -e "\033[33m\t-v<version> or --version=<version> : image version.\033[0m";
  echo -e "\033[33m\t-m<mount_volume> or --mount=<mount_volume> : up or down mount volumes.\033[0m";
  echo -e "\033[33m\t-n<container_name> or --name=<container_name> : set container_name.\033[0m";
  echo -e "\033[34m\nCommand:\033[0m";
  echo -e "\033[33m\t up[u] or deploy : deploy all container instances.\033[0m";
  echo -e "\033[33m\t down[d] or remove[rmi] : remove all container instances.\033[0m";
  echo -e "\033[33m\t init[i] : init redis config with override files.\033[0m";
  echo -e "\033[33m\t clean[c] : clean redis data.\033[0m";
  echo -e "\033[33m\t w : create document file.\033[0m";
}

# 解析参数
while true ; do 
  # fetch first args,then use shift clear
  case "$1" in 
    -h|--help) show_help; shift ;exit 1;;
    -p|--port)
      case "$2" in 
        "") shift 2 ;;
        *) 
          if [[ "$2" =~ ^([1-9][0-9]{3})$ ]];then
            REDIS_MIN_PORT=$2;
            NODE_COUNTS=6
          else 
            echo -e "\033[31mStart port illegal,required 4 length port.\033[0m";
            exit 1;
          fi
         shift 2 ;;
      esac ;;
    -s|--size)
      case "$2" in 
        "") shift 2 ;;
        *) 
          if [[ "$2" =~ ^([6-9]|(1[0-9]))+$ ]];then
            NODE_COUNTS=$2
          else 
            echo -e "\033[31mRedis Cluster requirement 6 nodes at least.\033[0m";
            exit 1;
          fi
         shift 2 ;;
      esac ;;        
    -v|--version) 
      case "$2" in 
        "") shift 2 ;;
        *) 
          if [[ "$2" =~ ^([0-9]\.[0-9]\.[0-9])$ || "$2" == latest ]];then 
            version=$2
          else
            echo -e "\033[31mVersion arg illegal. $2 shuld x.x.x \n\033[0m"
          fi
          shift 2;;
      esac ;;
    --) shift ; break ;;
    *) echo "Internal error."; exit ;;
  esac
done

if [ "$1" != "" ];then
  if [[ "$1" =~ ^(up|u|down|d|remove|rmi|deploy|clean|c|init|i|w)$ ]];then
    EC_CMD=$1
  else
    echo -e "\033[31m请选择操作 up[u],deploy,down[d],clean[c],[remove]rmi,init[i] or w.\033[0m"
    exit 0;
  fi
else
  show_help;
  exit 0;
fi

if [[ "$NODE_COUNTS" =~ ^([6-9]|(1[0-9]))$  ]];then
    REDIS_MAX_PORT=`expr $REDIS_MIN_PORT + $NODE_COUNTS`
    REDIS_MAX_PORT=`expr $REDIS_MAX_PORT - 1`
fi

# Redis-node ${_port} config
# 服务器就填公网ip,或者内部对应容器的ip
function write_conf(){
    _port=$1
    cat > $redis_base_dir/node-${_port}/conf/redis.conf << EOF
port ${_port}
requirepass ${REDIS_PASSWORD}
bind 0.0.0.0
protected-mode no
daemonize no
databases 16
appendonly yes
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-announce-ip ${DOCKER_VHOST}
cluster-announce-port ${_port}
cluster-announce-bus-port 1${_port}
EOF
}

function prepare_config(){
    redis_base_dir=${ROOT_DIR}/${REDIS_DATA_BASE}

    echo -e "\033[35m redis_base_dir: $redis_base_dir \033[0m"

    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        # mkdir -p $redis_base_dir/node-${port}/data
        mkdir -p $redis_base_dir/node-${port}/conf
        touch $redis_base_dir/node-${port}/conf/redis.conf

        write_conf $port

    done
}

# sysctl参数来设置系统参数，通过这些参数来调整系统性能
function run_container(){
    _port=$1

    _mnt_base=$ROOT_DIR/$REDIS_DATA_BASE/node-${_port}
    container_name=${REDIS_CONTAINER_NAME_PREFIX}-${_port}

    container_id=$(docker ps -aqf "name=$container_name")

    echo -e "\033[33mCONF : ${_mnt_base}\033[0m"

    if [ ! -z $container_id ];then
        echo -e "\033[32m $container_name is running..🚀.\033[0m"
    else 
        docker run -it -d -p ${_port}:${_port} -p 1${_port}:1${_port} --privileged=true\
        -v "${_mnt_base}/conf/redis.conf":'/etc/redis/redis.conf' \
        -v "${_mnt_base}/data":'/data' \
        --restart always --name ${container_name} --net ${NETWORK_NAME} \
        --sysctl net.core.somaxconn=1024 redis redis-server /etc/redis/redis.conf

        echo -e "\033[32mdeploy ${container_name} complete.\033[0m"
    fi

}

# write some title
function write_tile(){
    f=$1
    cat << EOF > $f 
# Redis Cluster nodes ${REDIS_CONTAINER_NAME_PREFIX}-${REDIS_MIN_PORT} ~ ${REDIS_CONTAINER_NAME_PREFIX}-${REDIS_MAX_PORT}

## Connect redis

\`\`\`bash
docker exec -it ${REDIS_CONTAINER_NAME_PREFIX}-${REDIS_MIN_PORT} /bin/bash
redis-cli -c -a ${REDIS_PASSWORD} -p ${REDIS_MIN_PORT}
select 0
\`\`\`
EOF

}

function write_append_commands() {
    p=$1
    f=$2
    echo -e "\t${DOCKER_VHOST}:${p} \\" >> $f

}


function create_cluster_scripts(){
    readme_file="$ROOT_DIR/$REDIS_DATA_BASE/README.md"

    touch $readme_file

    write_tile $readme_file

    echo -e "\n# 创建集群\n\n> in docker container enviroment\n\n\`\`\`bash\nredis-cli -a ${REDIS_PASSWORD} --cluster create \\" >> $readme_file

    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        write_append_commands $port $readme_file
    done

    echo -e "\t--cluster-replicas 1" >> $readme_file
    echo -e "\`\`\`\n" >> $readme_file
  
    echo -e "\033[32mSee Document ${readme_file}.\033[0m"
}

function deploy_all(){
    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        run_container $port
    done
}

function remove_container(){
    _port=$1
    container_name=${REDIS_CONTAINER_NAME_PREFIX}-${_port}
    container_id=$(docker ps -aqf "name=$container_name")

    if [ ! -z $container_id ];then
        docker rm $container_id -f
        echo -e "\033[32mDokcer remove complete.\033[0m"
    else 
        echo -e "\033[32mDokcer $container_name not run.\033[0m"
    fi
}

function uninstall_all(){
    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        remove_container $port
    done
}

function clean_data(){
    node_run=false
    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        container_name=${REDIS_CONTAINER_NAME_PREFIX}-${port}
        container_id=$(docker ps -aqf "name=$container_name")

        if [ ! -z $container_id ];then
            echo -e "\033[32m$container_name is running,please stop it first.\033[0m"
            exit 1;
        fi
    done 

    # delete
    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do
        rm -rf $ROOT_DIR/$REDIS_DATA_BASE/node-$port/* 
    done  
 
}

# EC_CMD
if [[ $EC_CMD =~ ^(up|u|deploy)$ ]];then 
  deploy_all
  exit 0
elif [[ $EC_CMD =~ ^(down|d|remove|rmi)$ ]];then
  uninstall_all
  exit 0  
elif [[ $EC_CMD =~ ^(clean|c)$ ]];then 
  clean_data
  exit 0
elif [[ $EC_CMD =~ ^(init|i)$ ]];then 
  prepare_config
  exit 0 
elif [[ $EC_CMD =~ ^(w)$ ]];then 
  create_cluster_scripts
  exit 0 
else
  show_help
  exit 0 
fi
