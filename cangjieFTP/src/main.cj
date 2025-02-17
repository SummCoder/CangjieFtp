package ftp

import std.fs.*
import ftp.auth.*
import ftp.server.*

// FTP服务器程序主入口程序
main(): Unit {
    // 注册用户，提供用户名以及密码
    var auth: User = User()
    auth.register("user1", "123456")
    auth.register("user2", "123456")
    auth.register("anonymous", "")

    // 确保项目目录下存在data目录，同时目录中存在user1和user2目录
    if (!Directory.exists("data/user1")) {
        Directory.create(Path("data/user1"), recursive: true)
    }
    if (!Directory.exists("data/user2")) {
        Directory.create(Path("data/user2"), recursive: true)
    }
    // 注册用户和文件夹的关系
    // 匿名用户仅可查看并下载user1上传文件
    auth.addPermission("anonymous", Path("data/user1"), true, false)
    // user1可以查看并下载自己以及user2上传的文件
    auth.addPermission("user1", Path("data/user1"), true, true)
    auth.addPermission("user1", Path("data/user2"), true, false)
    // user2仅可以查看并下载自己上传的文件
    auth.addPermission("user2", Path("data/user2"), true, true)

    // 创建一个FTP实例
    var server = FTPServer(auth, Path("data"))
    // 注册一个listener作为FTP事件的监听器
    var listener: Listener = Listener()
    server.addListener(listener)
    // 超时时间还是默认为5min
    server.setTimeout(5 * 60 * 1000)
    // 设置缓冲区大小为4kb
    server.setBufferSize(4 * 1024)
    // 以同步方式启动ftp服务器
    server.listen()
}
