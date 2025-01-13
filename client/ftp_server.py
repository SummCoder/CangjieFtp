# ftp_server.py  
import logging
import os
import hashlib


from pyftpdlib.authorizers import DummyAuthorizer, AuthenticationFailed
from pyftpdlib.handlers import FTPHandler  
from pyftpdlib.servers import FTPServer  

# 定义权限控制  
class CustomAuthorizer(DummyAuthorizer):  
    def __init__(self):  
        super().__init__()  
        # 匿名用户（主目录）  
        self.add_anonymous('/ftp_data/user1')  
        hash_ = hashlib.md5('123456'.encode('latin1')).hexdigest()
        # user1 用户（主目录）  
        self.add_user("user1", hash_, homedir='/ftp_data', perm='elr')  
        # user2 用户（主目录）  
        self.add_user("user2", hash_, homedir='/ftp_data/user2', perm='elradfmwMT')  
        # user1 可以查看user2的文件
        self.override_perm("user1", "/ftp_data/user1", perm='elradfmwMT', recursive=True)

    # 采用md5加密用户名和密码
    def validate_authentication(self, username, password, handler):
        if username != "anonymous":
            hash_ = hashlib.md5(password.encode('latin1')).hexdigest()
            try:
                if self.user_table[username]['pwd'] != hash_:
                    raise KeyError
            except KeyError:
                raise AuthenticationFailed


def main():  
    # 初始化权限管理器  
    authorizer = CustomAuthorizer()  
    handler = FTPHandler  
    handler.authorizer = authorizer  

    # 允许被动模式，端口范围为2000-2332
    handler.passive_ports = range(2000, 2333)

    # 确保 FTP 数据目录存在  
    data_dir = '/ftp_data'  
    os.makedirs(data_dir, exist_ok=True)  
    os.makedirs(os.path.join(data_dir, 'user1'), exist_ok=True)  
    os.makedirs(os.path.join(data_dir, 'user2'), exist_ok=True)  

    # 添加日志管理功能
    logging.basicConfig(filename='/var/log/pyftpd.log', level=logging.INFO)

    # 启动 FTP 服务器  
    server = FTPServer(('0.0.0.0', 21), handler)
    try:  
        server.serve_forever()
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':  
    main()
