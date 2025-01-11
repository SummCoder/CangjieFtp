#!/bin/bash  

# 安装 Python 和 pip  
echo "确保 Python 和 pip 已安装..."  
if ! command -v python3 &> /dev/null  
then  
    echo "Python 3 未安装，尝试进行安装..."  
    sudo dnf install -y python3  
fi  

if ! command -v pip3 &> /dev/null  
then  
    echo "pip 未安装，尝试进行安装..."  
    sudo dnf install -y python3-pip  
fi  

# 安装 pyftpdlib  
echo "安装 pyftpdlib ..."  
pip3 install pyftpdlib  

# 检查目录结构  
FTP_DIR="/ftp_data"  
mkdir -p $FTP_DIR/user1 $FTP_DIR/user2  

# 启动 FTP 服务器  
echo "启动 FTP 服务器 ..."  
python3 ftp_server.py &  

echo "FTP 服务器已启动，端口 21 监听中。"
