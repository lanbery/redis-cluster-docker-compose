#!/bin/bash 
basepath=$(cd `dirname $0`;pwd);
workspace=$(cd `dirname $0`;cd ..;pwd);

version=latest

NETWORK_NAME=xai-network
REDIS_MIN_PORT=7201
REDIS_MAX_PORT=7205
REDIS_PASSWORD=admin123
DOCKER_VHOST=172.20.0.1
NODE_COUNTS=

REDIS_DATA_BASE=redis
REDIS_CONTAINER_NAME_PREFIX=redis


# APP 
APP_DATA_BASE=apinto
APP_CONTAINER_NAME=apinto-dashboard
APP_PORT=18080


EC_CMD=
ROOT_DIR=$workspace

# rebuild args
ARGS=$(getopt -o 'hm:s:n:p:v::' --long 'help,min-port:,node-size:,name:,expose-port:,version::' -n "$0" -- "$@")

# 将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"

# Command pull|up|down|remove|rmi|pull-up
function show_help() {
  echo -e "\033[31mCommands Help :\n\033[0m";
  echo -e '\033[35m$ apinto \033[0m';
  echo -e "\033[35m$ apinto <options?> <command>\033[0m";
  echo -e "\033[34mDeploy options: \033[0m";
  echo -e "\033[35m\t-m<redis-min-port> or --min-port=<redis-min-port>: set min redis cluster port.\033[0m";  
  echo -e "\033[35m\t-s<redis-node-size> or --node-size=<redis-node-size> :redis cluster nodes count,default 6.\033[0m";
  echo -e "\033[35m\t-p<expose-port> or --expose-port=<expose-port> : set APP_PORT argument.\033[0m";
  echo -e "\033[35m\t-n<container_name> or --name=<container_name> : set container_name.\033[0m";
  echo -e "\033[34m\nCommand:\033[0m";
  echo -e "\033[33m\t up[u] or deploy : deploy all container instances.\033[0m";
  echo -e "\033[33m\t down[d] or remove[rmi] : remove all container instances.\033[0m";
  echo -e "\033[33m\t init[i] : init redis config with override files.\033[0m";
  echo -e "\033[33m\t clean[c] : clean redis data.\033[0m";
  echo -e "\033[33m\t w : create document file.\033[0m";
}

function source_env(){
  if [ ! -f "$workspace/.env" ];then
    echo -e "\033[31m🤮Miss .env in workspace, \033[31mplease cp env.example .env & modify content.\033[0m"
    exit 0
  fi

  source $workspace/.env
}

source_env

# 解析参数
# 'hm:s:n:p:v::' --long 'help,min-port:,node-size:,name:,expose-port:,version::'
while true ; do 
  # fetch first args,then use shift clear
  case "$1" in 
    -h|--help) show_help; shift ;exit 1;;
    -m|--min-port)
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
    -s|--node-size)
      case "$2" in 
        "") shift 2 ;;
        *) 
          if [[ "$2" =~ ^([6-9]|(1[0-9]))$ ]];then
            NODE_COUNTS=$2
          else 
            echo -e "\033[31mRedis Cluster requirement 6 nodes at least.\033[0m";
            exit 1;
          fi
         shift 2 ;;
      esac ;;      
    -n|--name)
      case "$2" in 
        "") shift 2 ;;
        *)
          if [[ "$2" =~ ^[a-zA-Z]+([a-zA-Z0-9_]+)?[a-zA-Z]+$ ]];then
            APP_CONTAINER_NAME=$2
          else 
            echo -e "\033[31mContainer name arg illegal. $2.\033[0m"
            exit 1;
          fi
          shift 2 ;;
        esac ;;        
    -p|--expose-port)
      case "$2" in 
        "") shift 2 ;;
        *) 
          if [[ "$2" =~ ^([1-9][0-9]{3,4})$ ]];then
            APP_PORT=$2;
          else 
            echo -e "\033[31mAPP expose port ${APP_PORT} invalid.\033[0m";
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
            exit 1;
          fi
          shift 2;;
      esac ;;
    --) shift ; break ;;
    *) echo "Internal error."; exit ;;
  esac
done

if [ "$1" != "" ];then
  if [[ "$1" =~ ^(up|u|down|d|remove|rmi|clean|c|init|i|w)$ ]];then
    EC_CMD=$1
  else
    echo -e "\033[31m请选择操作 up[u],down[d],[remove]rmi,clean[c],init[i] or w.\033[0m"
    exit 0;
  fi
else
  show_help;
  exit 0;
fi

if [[ "$NODE_COUNTS" =~ ^([6-9]|(1[0-9]))$ ]];then
    REDIS_MAX_PORT=`expr $REDIS_MIN_PORT + $NODE_COUNTS`
    REDIS_MAX_PORT=`expr $REDIS_MAX_PORT - 1`
fi

function export_redis_addr(){
  app_base=$ROOT_DIR/$APP_DATA_BASE
  if [ ! -d $app_base ];then
    mkdir -p $app_base
  fi

  touch $app_base/temp
  echo -ne "" > $app_base/temp

  for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
  do
    echo -ne "${DOCKER_VHOST}:${port}," >> $app_base/temp
  done

  redis_addr=$(cat $app_base/temp)

  redis_addr=${redis_addr%*,}
#   redis_addr=`grep -r $redis_addr|tr -d "\n"`

  if [ -z "$redis_addr" ];then
    echo -e "\033[31mGET REDIS_ADDR ${redis_addr} argument invalid.\033[0m"
    exit 1
  fi
  
  export REDIS_ADDR=$redis_addr

  # rm
#   rm -rf $app_base/temp

}

# function 
function check_env_args(){
  if [ -z "$MYSQL_HOST" ];then
    MYSQL_HOST=mysql
    export MYSQL_HOST=$MYSQL_HOST
  fi 
  if [ -z "$MYSQL_PORT" ];then
    MYSQL_PORT=3306
    export MYSQL_PORT=$MYSQL_PORT
  fi  
  if [ -z "$MYSQL_DB" ];then
    MYSQL_DB=apinto
    export MYSQL_DB=$MYSQL_DB
  fi
  if [ -z "$MYSQL_USER_NAME" ];then
    MYSQL_USER_NAME=admin
    export MYSQL_USER_NAME=$MYSQL_USER_NAME
  fi
  if [ -z "$MYSQL_PWD" ];then
    echo -e "\033[31mUnset MYSQL_PWD in env file.\033[0m"
    exit 1;
  fi

# Redis

  if [ -z "$DOCKER_VHOST" ];then
    echo -e "\033[31mUnset DOCKER_VHOST in env file.\033[0m"
    exit 1;
  fi
  if [ -z "$REDIS_PASSWORD" ];then
    echo -e "\033[31mUnset REDIS_PASSWORD in env file.\033[0m"
    exit 1;
  fi      
}

function prepare_app_data_dir(){
  app_base=$ROOT_DIR/$APP_DATA_BASE

  if [ ! -d $app_base/${APP_CONTAINER_NAME} ];then
    mkdir -p $app_base/${APP_CONTAINER_NAME}/work
  fi    
  export MNT_APP_LOG=$app_base/${APP_CONTAINER_NAME}/work

}

# function 
function up_apinto_dashboard(){
    docker run -dt --name ${APP_CONTAINER_NAME} --restart=always \
    --privileged=true  --network=${NETWORK_NAME}  -p ${APP_PORT}:8080 \
    -v "$MNT_APP_LOG":/apinto-dashboard/work \
    -e MYSQL_USER_NAME=${MYSQL_USER_NAME} -e MYSQL_IP=${MYSQL_HOST} \
    -e MYSQL_PWD=${MYSQL_PWD} -e MYSQL_PORT=${MYSQL_PORT} -e MYSQL_DB=${MYSQL_DB} \
    -e REDIS_ADDR=${REDIS_ADDR} \
    -e REDIS_PWD=${REDIS_PASSWORD} eolinker/apinto-dashboard
}

function write_readme_md(){
  app_base=$ROOT_DIR/$APP_DATA_BASE

  if [ ! -d $app_base ];then
    mdkir -p $app_base
  fi

  readme_file=$app_base/${APP_CONTAINER_NAME}.md
  touch $readme_file

  echo -e "# ${APP_CONTAINER_NAME}\n\n> ${APP_CONTAINER_NAME} is APP Portal" > $readme_file

  echo -e "\n> vist url: http://127.0.0.1:${APP_PORT}\n" >> $readme_file

  # write usage
cat << EOF >> $readme_file

# Usage

- search docker IP

\`\`\`bash
# IP 
ip route

# window
ipconfig

# macOs
ifconfig

\`\`\`

## script command

> How install an app instance

- config env file: cp env.example .env
- init config 


\`\`\`bash
# bash bin/apinto.sh <options> <command>
bash bin/apinto.sh -m7201 -s6 -napinto-dashboard up

\`\`\`

## create app container script

\`\`\`bash
docker run -dt --name ${APP_CONTAINER_NAME} --restart=always \\
    --privileged=true  --network=${NETWORK_NAME}  -p ${APP_PORT}:8080 \\
    -v "$MNT_APP_LOG":/apinto-dashboard/work \\
    -e MYSQL_USER_NAME=${MYSQL_USER_NAME} -e MYSQL_IP=${MYSQL_HOST} \\
    -e MYSQL_PWD=${MYSQL_PWD} -e MYSQL_PORT=${MYSQL_PORT} -e MYSQL_DB=${MYSQL_DB} \\
    -e REDIS_ADDR=${REDIS_ADDR} \\
    -e REDIS_PWD=${REDIS_PASSWORD} eolinker/apinto-dashboard
\`\`\

EOF

}

function clean_app_data(){
  app_base=$ROOT_DIR/$APP_DATA_BASE

  if [ ! -d $app_base ];then
    mdkir -p $app_base
  fi

  rm -rf $app_base/${APP_CONTAINER_NAME}/*

  touch $app_base/.gitkeep
}

prepare_app_data_dir
export_redis_addr
# EC_CMD
if [[ $EC_CMD =~ ^(up|u)$ ]];then 
  check_env_args
  write_readme_md
  up_apinto_dashboard
  exit 0
elif [[ $EC_CMD =~ ^(down|d|remove|rmi)$ ]];then
  show_help
  exit 0  
elif [[ $EC_CMD =~ ^(clean|c)$ ]];then 
  check_env_args
  clean_app_data
  exit 0
elif [[ $EC_CMD =~ ^(init|i)$ ]];then 
  check_env_args
  clean_app_data
  exit 0 
elif [[ $EC_CMD =~ ^(w)$ ]];then 
  check_env_args
  write_readme_md
  exit 0 
else
  show_help
  exit 0 
fi