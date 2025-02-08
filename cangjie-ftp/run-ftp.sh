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

# 检查 /ftp_data 目录以及 user1 和 user2 子目录
echo "检查 /ftp_data 目录及子目录..."
if [ ! -d "/ftp_data" ]; then
    echo "/ftp_data 目录不存在，正在创建..."
    mkdir -p /ftp_data
fi

# 检查 user1 和 user2 子目录
for dir in user1 user2; do
    if [ ! -d "/ftp_data/$dir" ]; then
        echo "/ftp_data/$dir 目录不存在，正在创建..."
        mkdir "/ftp_data/$dir"
    fi
done

# 编译ftp_server
cjc ftp_server.cj -o ftp_server

echo "正在启动ftp服务器..."

# 启动执行
./ftp_server