#!/usr/bin/env bash
INPUT_BASE_DIR=
INPUT_PORTS=
IS_REMOTE=false
. $(dirname $0)/common.sh

# echo original parameters=[$@]
ARGS=$(getopt -o 'hrd:n:p:v::' --long 'help,remote,node-data:,name:,expose-port:,version::' -n "$0" -- "$@")
# 将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"
echo [$@]

source_env

# Command build[b] publish[p] check
function show_help() {
  echo -e "\033[33mCommands Help :\033[0m";
  echo -e "\033[34m\t${CMD}/node-delpoy.sh \033[35m<options?> <command>\033[0m";
  echo -e "\033[34m\nOptions: \033[0m ";
  echo -e "\033[35m\t-d<node-data-dir> or --node-data=<node-data-dir>: set node base dir, default user (cd ~;pwd).\033[0m"; 
  echo -e "\033[35m\t-n<node-name> or --name=<node-name>: set node name , default apinto-node.\033[0m";  
  echo -e "\033[35m\t-p<expose-ports> or --expose-ports=<expose-ports>: set docker expose-ports,like 8099,9400 default 8099,9400 max 3 port.\033[0m";  
  echo -e "\033[35m\t-v<version> or --version=<version> : image version,default 0.17.7.\033[0m";
  echo -e "\033[34mCommand:\033[0m";
  echo -e "\033[33m\t up or u   : up container .\033[0m";
  echo -e "\033[33m\t down or d : down container.\033[0m";
  echo -e "\033[33m\t run       : run docker container .\033[0m";
  echo -e "\033[33m\t rmi       : stop and force remove container.\033[0m";
  echo -e "\033[33m\t start,stop or restart : start,stop or restart container.\033[0m \n";
}

while true ; do 
    case "$1" in 
        -h|--help) show_help; shift ;exit 1;;
        -d|--node-data)
            case "$2" in 
                "") shift 2 ;;
                *)
                    if [[ ! "$2" =~ /$ && "$2" =~ ^(/|\./)?([\.a-zA-Z0-9_\-]+/?)+$ ]];then
                        INPUT_BASE_DIR=$2
                    else
                        echo -e "\033[31mNode basic path arg illegal. $2.\033[0m"
                        exit 1
                    fi
                    shift 2 ;;
            esac ;;
        -r|--remote) IS_REMOTE=true ; shift ;;            
        -n|--name)
            case "$2" in
                "") shift 2 ;;
                *)
                    if [[ "$2" =~ ^[a-zA-Z]+([a-zA-Z0-9_]+)?[a-zA-Z0-9]+$ ]];then
                        ApintoNodeName=$2
                    else
                        echo -e "\033[31mnode name arg illegal. $2.\033[0m"
                        exit 1;
                    fi
                    shift 2 ;;
            esac ;;   
        -p|--expose-port)
            case "$2" in
                "") shift 2 ;;
                *)
                    if [[ "$2" =~ ^([0-9]+)\,([0-9]+)$ ]];then
                        INPUT_PORTS=$2
                    else
                        echo -e "\033[31mNode expose ports[$2] illegal,require like 8099,9400 or xxxx,xxxx,xxxx .\033[0m"
                        exit 1;
                    fi
                    shift 2 ;;
            esac ;;  
        -v|--version) 
            case "$2" in 
                "") shift 2 ;;
                *) 
                    if [[ "$2" =~ ^([0-9]+\.[0-9]+\.[0-9]{1,3})$ ]];then 
                        VERSION=$2
                    else
                        echo -e "\033[31mVersion arg illegal. $2 shuld x.x.x \n\033[0m"
                    fi
                    shift 2;;
            esac ;;                                 
        --) shift ; break ;;
        *) echo "Interanl error" ; exit 1 ;;
    esac
done

if [ "$1" != "" ];then
  if [[ "$1" =~ ^(up|u|down|d|publish|p|run|remove|rmi|start|stop|restart)$ ]];then
    EC_CMD=$1
  else
    echo -e "\033[31m请选择操作 up[u],down[d],publish[p],run,remove[rmi],start,stop or restart.\033[0m"
    exit 0;
  fi
else
  show_help;
  exit 0;
fi


function run_node(){
    echo -e "run_node"

    local docker_image=$(getImageName $IS_REMOTE)
    local node_dir=$(prepare_node_base $INPUT_BASE_DIR)

    local expose_port_args=$(parse_expose_ports $INPUT_PORTS)
    echo "$docker_image $node_dir $expose_port_args $ApintoNodeName"

    create_config_yml "$node_dir/conf/config.yml"

    local dock_run_cmd="docker run -td ${expose_port_args} \\
    -v $node_dir/data:/var/lib/apinto \\
    -v $node_dir/conf/config.yml:/etc/apinto/config.yml \\
    -v $node_dir/log:/var/log/apinto \\
    --name ${ApintoNodeName} $docker_image
    "

    echo -e "$dock_run_cmd"

    # docker run -td ${expose_port_args} \
    # -v $node_dir/data:/var/lib/apinto \
    # -v $node_dir/conf/config.yml:/etc/apinto/config.yml \
    # -v $node_dir/log:/var/log/apinto \
    # --name ${ApintoNodeName} $docker_image

    sleep 3
    show_apinto_success_doc $INPUT_PORTS
}

# EC_CMD
if [[ $EC_CMD =~ ^(run)$ ]];then
    run_node
# elif [[ $EC_CMD =~ ^(pull|p)$ ]];then
#   login_repo  
#   pull_image
# elif [[ $EC_CMD =~ ^(down|d)$ ]];then
#   down_container
# elif [[ $EC_CMD =~ ^(rmi|remove)$ ]];then
#   remove_image  
# elif [[ "$EC_CMD" == "start" ]];then
#   start_container
# elif [[ "$EC_CMD" == "stop" ]];then
#   stop_container
# elif [[ "$EC_CMD" == "restart" ]];then
#   restart_container  
else 
  show_help
  exit 0 
fi  