#!/bin/bash
basepath=$(cd `dirname $0`;pwd);

app_name=apinto
api_version=0.17.7
xai_app_base=/opt/xai-app

install() {
    local version=$1
    local installDir=$2

    # Download
    # https://github.com/eolinker/apinto/releases/download/v0.17.7/apinto_v0.17.7_linux_amd64.tar.gz
    local downloadUrl="https://github.com/eolinker/apinto/releases/download/v${version}/apinto_v${version}_linux_amd64.tar.gz"

    if [ -z "$(command -v wget)" ]; then
        apt-get install -f -y wget

        if [ $? -eq 0 ];then
            echo -e "\033[32mwget install complete.\033[0m"
        else
            echo -e "\033[31mwget install fail.\033[0m"
            exit 1;
        fi
    fi

    # installDir
    if [ ! -d "${installDir}" ];then
        mkdir -p "${installDir}"

        if [ $? -eq 0 ];then
            echo -e "\033[32m Work dir ${installDir} creation.\033[0m"
        else
            echo -e "\033[31mPlease check permission.\033[0m"
            exit 1;
        fi
    fi

    tar_file="/tmp/apinto_v${version}_linux_amd64.tar.gz"
    if [ ! -f "$tar_file" ];then
        wget "$downloadUrl" -P /tmp

        if [ $? -eq 0 ];then
            echo -e "\033[32mDownload ${tar_file} $? complete.\033[0m"
        else
            echo -e "\033[31mDownload apinto_v${version}_linux_amd64.tar.gz fail \n\033[33mForm url : ${downloadUrl}.\033[0m"
            exit 1
        fi
    else
        echo -e "\033[33mFile ${tar_file} exists.\033[0m"
    fi

    if [ -d "$installDir/$app_name" ];then 
        echo -e "\033[33m clean app [$app_name] old data.\033[0m"
        rm -rf "$installDir/$app_name"
    fi

    # unzip
    tar -zxvf "$tar_file" -C "$installDir"

    if [ $? -eq 0 ];then
        echo -e "\033[33mDecompression ${tar_file} complete.\033[0m"
    else
        echo -e "\033[31m Decompression ${tar_file} failed.\033[0m"
        exit 1
    fi

    cd "$installDir/$app_name" && ./install.sh install && "${app_name}" start

    if [ $? -eq 0 ];then
        echo -e "\033[33mInstall ${app_name} success ✨✨✨✨.\033[0m"
    else 
        echo -e "\033[31mStart ${app_name} failed.\033[0m"
        exit 1;
    fi
}

install "$api_version" "$xai_app_base"