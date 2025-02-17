#!/bin/bash  

# 定义下载地址和文件名  
DOWNLOAD_URL="https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=Cangjie-0.53.13-linux_x64.tar.gz&objectKey=6719f1eb3af6947e3c6af327"  
FILE_NAME="Cangjie-0.53.13-linux_x64.tar.gz"

# 检查 cangjie 工具链是否已安装

echo "确保 cangjie 工具链已安装..."  
if ! command -v cjc -v &> /dev/null  
then  
    echo "cangjie工具链 未安装，尝试进行安装..."  
    # 下载文件  
    echo "Downloading Cangjie compiler..."  
    curl -L -o "$FILE_NAME" "$DOWNLOAD_URL"

    # 检查下载是否成功  
    if [ $? -eq 0 ]; then  
        echo "Download completed successfully."  
    else  
        echo "Download failed."  
        exit 1  
    fi

    # 解压文件  
    echo "Extracting $FILE_NAME..."  
    tar -xvf "$FILE_NAME"  

    # 检查解压是否成功  
    if [ $? -eq 0 ]; then  
        echo "Extraction completed successfully."  
    else  
        echo "Extraction failed."  
        exit 1  
    fi

    # 检查 envsetup.sh 是否存在并进行 source  
    if [[ -f "cangjie/envsetup.sh" ]]; then
    	echo "envsetup.sh found!"  
        source cangjie/envsetup.sh  
    else  
        echo "envsetup.sh not found!"  
        exit 1  
    fi

fi

# 检查 openEuler 防火墙状态
echo "检查 openEuler 防火墙状态..."
if systemctl status firewalld | grep "active (running)" &> /dev/null; then
  echo "防火墙已开启，尝试开放 21 端口..."
  firewall-cmd --zone=public --add-port=21/tcp --permanent
  firewall-cmd --reload
  echo "21 端口已开放。"
else
  echo "防火墙未开启，无需开放端口。"
fi

# 切换到 cangjieFTP 目录
cd cangjieFTP || { echo "cangjieFTP 目录不存在"; exit 1; }

# 编译ftp_server
echo "正在编译 ftp_server..."
cjpm build

# 检查编译是否成功
if [ $? -eq 0 ]; then
    echo "编译成功."
else
    echo "编译失败."
    exit 1
fi

# 运行 ftp_server
echo "正在启动 ftp 服务器..."
cjpm run