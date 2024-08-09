#!/bin/bash
# https://blog.csdn.net/zcs2312852665/article/details/135827309
basepath=$(cd `dirname $0`;pwd);
workspace=$(cd `dirname $0`;cd ..;pwd);

REDIS_MIN_PORT=7201
REDIS_MAX_PORT=7206
NODE_COUNTS=

app_name=apserver
apserver_version=3.3.3
apinto_version=0.17.7

xai_app_base=/opt/xai-app
APSERVER_PORT=18080
config_yml_name=config

EC_CMD=
ROOT_DIR=$workspace

IS_APSERVER=false

APINTO_WORK_BASE=$workspace/apinto

app_run_base=/usr/local/apserver

run_config_base=/etc/apinto


# rebuild args
ARGS=$(getopt -o 'ham:s:p:v::' --long 'help,api,min-port:,node-size:,expose-port:,version::' -n "$0" -- "$@")

# 将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"

# Command install|i|uninstall|u|clean|c|start|stop|restart
show_help() {
  echo -e "\033[31mCommands Help :\n\033[0m";
  echo -e '\033[35m$ install \033[0m';
  echo -e "\033[35m$ install <options?> <command>\033[0m";
  echo -e "\033[34mDeploy options: \033[0m";
  echo -e "\033[35m\t-a or --api: -a will operate apinto.\033[0m";  
  echo -e "\033[35m\t-m<redis-min-port> or --min-port=<redis-min-port>: set min redis cluster port.\033[0m";  
  echo -e "\033[35m\t-s<redis-node-size> or --node-size=<redis-node-size> :redis cluster nodes count,default 6.\033[0m";
  echo -e "\033[35m\t-p<expose-port> or --expose-port=<expose-port> : set APP_PORT argument.\033[0m";
  echo -e "\033[35m\t-n<container_name> or --name=<container_name> : set container_name.\033[0m";
  echo -e "\033[34m\nCommand:\033[0m";
  echo -e "\033[33m\t install[i] or uninstall[u] : install or uninstall apinto(or apserver).\033[0m";
  echo -e "\033[33m\t start,stop or restart : start,stop or restart apinto.\033[0m";
  echo -e "\033[33m\t init[i] : init redis config with override files.\033[0m";
  echo -e "\033[33m\t clean[c] : clean redis data.\033[0m";
  echo -e "\033[33m\t wiki[w] : create document file.\033[0m";
}


source_env(){
  if [ ! -f "$workspace/.env" ];then
    echo -e "\033[31m🤮Miss .env in workspace, \033[31mplease cp env.example .env & modify content.\033[0m"
    exit 0
  fi

  source $workspace/.env
}

source_env

# create workspace
if [ ! -d "$APINTO_WORK_BASE" ];then
    mkdir -p "$APINTO_WORK_BASE"
fi 


# parse arguments
# 'hm:s:n:p:v::' --long 'help,min-port:,node-size:,name:,expose-port:,version::'
while true ; do 
  # fetch first args,then use shift clear
  case "$1" in 
    -h|--help) show_help; shift ;exit 1;;
    -a|--api) 
        IS_APSERVER=true;
        app_name=apinto;
        shift ;;
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
          if [[ "$2" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ || "$2" == latest ]];then 
            if [[ "$IS_APSERVER" = true ]];then
                apinto_version=$2
            else
                apserver_version=$2
            fi
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
  if [[ "$1" =~ ^(install|i|uninstall|u|clean|c|start|stop|restart|wiki|w)$ ]];then
    EC_CMD=$1
  else
    echo -e "\033[31m请选择操作 install[i],uninstall[u],clean[c],start,stop,restart or wiki[w].\033[0m"
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

check_env_args(){
    if [[ -z "$MYSQL_HOST" ]];then
        echo -e "\033[31mENV MYSQL_HOST invalid.\033[0m"        
        exit 1;
    fi     
    if [[ -z "$MYSQL_PWD" ]];then
        echo -e "\033[31mENV MYSQL_PWD invalid.\033[0m"        
        exit 1;
    fi
    if [[ -z "$REDIS_PASSWORD" ]];then
        echo -e "\033[31mENV REDIS_PASSWORD invalid.\033[0m"        
        exit 1;
    fi 
    
}

# write_config file_name 
write_config(){
    f=$1

    if [ ! -f "$f" ];then 
        touch "$f"
    fi

    check_env_args

    cfg_db_host=$MYSQL_HOST
    cfg_db_username=$MYSQL_PWD

    cfg_redis_user=""
    if [[ -n "$REDIS_USER" ]];then
        cfg_redis_user=$REDIS_USER
    fi    

    cfg_db_name=apinto
    if [[ -n "$MYSQL_DB" ]];then
        cfg_db_name=$MYSQL_DB
    fi

    cfg_db_port=3306
    if [[ -n "$MYSQL_PORT" ]];then
        cfg_db_port=$MYSQL_PORT
    fi    

    cfg_db_username=apinto
    echo -e "MYSQL_USER_NAME  $MYSQL_USER_NAME"
    if [[ -n "$MYSQL_USER_NAME" ]];then
        cfg_db_username=$MYSQL_USER_NAME
    fi 

    # write begin @ https://help.apinto.com/docs/apinto
cat << EOF > $f
# apinto-${APSERVER_PORT} 
port: ${APSERVER_PORT}
mysql:
  db: ${cfg_db_name}
  user_name: ${cfg_db_username}
  password: ${MYSQL_PWD}
  ip: ${cfg_db_host}
  port: ${cfg_db_port}

error_log:
  dir: work/log
  file_name: error.log
  log_level: warning
  log_expire: 7d
  log_period: day

redis:
  user_name: ${cfg_redis_user}
  password: ${REDIS_PASSWORD}
  addr:
EOF

    for port in $(seq $REDIS_MIN_PORT $REDIS_MAX_PORT);
    do 
        echo -ne "    - ${DOCKER_VHOST}:${port}\n" >> $f
    done

}

write_wiki() {
    if [[ "$IS_APSERVER" = true ]];then
        version=$apinto_version
    else
        version=$apserver_version
    fi
    local wiki_filename="${APINTO_WORK_BASE}/wiki-apserver_${apserver_version}.md"

    if [ ! -f "$wiki_filename" ];then
        touch "$wiki_filename"
    fi
   
    visit_url=$(ip addr | grep 'inet ' | awk '{print $2}'| tail -n 1 | grep -oP '\d+\.\d+\.\d+\.\d+')
    #document head
    echo -ne "# ${app_name} \n\n- version: ${version} \n- App install at: ${app_run_base}\n" > $wiki_filename

    # echo 

cat << EOF >> $wiki_filename

## apinto-dashborad usage

> apserver install dir: ${app_run_base}/apserver_v${apserver_version}

- Vistit url: http://$visit_url:${APSERVER_PORT}
- apserver start,stop or restart

\`\`\`bash
cd ${app_run_base}/apserver_v${apserver_version} && ./run.sh start
cd ${app_run_base}/apserver_v${apserver_version} && ./run.sh stop
cd ${app_run_base}/apserver_v${apserver_version} && ./run.sh restart
\`\`\`

## work dir

- logs : "${app_run_base}/apserver_v${apserver_version}/work/logs"
- config: "${app_run_base}/apserver_v${apserver_version}/config.yml"

\`\`\`bash
# tail logs
tail -n 100 -f ${app_run_base}/apserver_v${apserver_version}/work/logs/stdout-apserver-*.log
\`\`\`

EOF

}

check_wget() {
    if [ -z "$(command -v wget)" ]; then
        apt-get install -f -y wget

        if [ $? -eq 0 ];then
            echo -e "\033[32mwget install complete.\033[0m"
        else
            echo -e "\033[31mwget install fail.\033[0m"
            exit 1;
        fi
    fi    
}

prepare_install_dir() {
    local app_base_path=$1

    local _install_dir="$xai_app_base/$app_base_path"

    if [ ! -d "${_install_dir}" ];then
        mkdir -p ${_install_dir}
        if [ $? -eq 0 ];then
            echo -e "\033[32mCreate Install dir complete.\033[0m"
        else
            echo -e "\033[31mMake sure you have permission.\033[0m"
            exit 1
        fi
    else
        echo -e "\033[32mInstall dir[$_install_dir] has exists.\033[0m"
    fi

    # if [ ! -d "/usr/local/${app_name}" ]; then 
    #     mkdir -p "/usr/local/${app_name}"
    # fi

}

copy_config_yml(){
    local config_yml_file="${APINTO_WORK_BASE}/config.yml"

    local target_base=$1

    write_config "${config_yml_file}"

    \cp -f "$config_yml_file" "$target_base/config.yml"
    echo -e "\033[35mConfig file [$target_base/config.yml] updated.\n\033[0m"
}

# install
install_apserver() {

    local v=$1
    
    local downloadUrl="https://github.com/eolinker/apinto-dashboard/releases/download/v${v}/apserver_v${v}_linux_amd64.tar.gz"
    file_name="/tmp/apserver_v${v}_linux_amd64.tar.gz"
    
    check_wget

    local app_version_path="apserver_v${v}"

    prepare_install_dir "apinto-dashboard"

    app_install_dir="$xai_app_base/apinto-dashboard"

    if [ ! -f "$file_name" ];then
        wget "$downloadUrl" -P /tmp

        if [ $? -eq 0 ];then
            echo -e "\033[32mDownload apinto-dashboard complete.\033[0m"
        else 
            echo -e "\033[31mDownload v${v}/apserver_v${v}_linux_amd64.tar.gz fail.\033[0m"
            exit 1
        fi
    fi

    if [ -d "${app_install_dir}/${app_version_path}" ]; then
        local pid=`ps -ef|grep apserver|grep -v grep|awk '{print $2}'`

        if [ ! -z "${pid}" ]; then
            echo -e "\033[31m Apserver is runing,please stop it.\033[0m"
            exit 1     
        fi    
        rm -rf "${app_install_dir}/${app_version_path}"
        rm -rf "/usr/local/apserver/apserver_v${v}"
    fi

    tar -zxvf "$file_name" -C "$app_install_dir"

    # echo -e ">>>>>>>>>>>>>>>>>>>>>>> ${app_install_dir}/${app_version_path}"
    cd "${app_install_dir}/${app_version_path}"
    bash ./install.sh "/usr/local/apserver"

    # install default dir /usr/local/apserver/apserver_vxxx
    copy_config_yml "/usr/local/apserver/apserver_v${v}"

    cd /usr/local/apserver/apserver_v${v} && ./run.sh restart

    if [ $? -eq 0 ]; then
        echo -e "\033[32m ✨✨✨✨Apinto-dashboard start successful.\033[0m"
        echo -e "\033[33m Please visit :\n\033[34m http://$(ip addr | grep 'inet ' | awk '{print $2}'| tail -n 1 | grep -oP '\d+\.\d+\.\d+\.\d+'):${APSERVER_PORT} .\033[0m"
        echo -e "\033[35m User: admin Password: 123456 .\033[0m"
    else 
        echo -e "\033[31mApinto-dashboard start failure.\033[0m"
        echo -e "\033[31mLog file:\033[33m /usr/local/apserver/apserver_v${v}/work/logs .\033[0m"
    fi

    exit 0
}

install_app(){
    version=$apserver_version
    # echo -e "$version"
    if [[ "$IS_APSERVER" = true ]];then
        version=$apinto_version
    else
        version=$apserver_version
    fi
    
    install_apserver "$version"

}

# EC_CMD
if [[ $EC_CMD =~ ^(install|i)$ ]];then 
  write_wiki
  install_app 
  exit 0
# elif [[ $EC_CMD =~ ^(down|d|remove|rmi)$ ]];then
#   show_help
#   exit 0  
# elif [[ $EC_CMD =~ ^(clean|c)$ ]];then 
#   check_env_args
#   clean_app_data
#   exit 0
# elif [[ $EC_CMD =~ ^(init|i)$ ]];then 
#   check_env_args
#   clean_app_data
#   exit 0 
elif [[ $EC_CMD =~ ^(wiki|w)$ ]];then 
  write_wiki
  exit 0 
else
  show_help
  exit 0 
fi