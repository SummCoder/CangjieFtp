package ftp.server

import std.collection.*
import std.socket.*
import std.sync.*
import std.io.*
import std.convert.*
import std.fs.*
import std.time.Duration
import ftp.handler.ConnectionHandler

// FTP连接类
public class FTPConnection {

    // 存储可用的FTP命令
    private var commands: Map<String, CommandInfo> = HashMap<String, CommandInfo>()
    // // 存储服务器支持的功能列表
    // private var features: ArrayList<String> = ArrayList<String>()
    // 处理此连接的服务器实例
    private var server: FTPServer
    // 与客户端的连接套接字
    private var client: TcpSocket
    // 设置超时时间
    private let timeout: UInt32
    // 设置缓冲区大小
    private let bufferSize: UInt32
    // 指示是否已经发送响应
    private var whetherSend = true
    // // 负责连接的线程
    // private var thread: Future<Unit>
    // 处理连接的程序实例
    private var connnectHandler: ConnectionHandler
    // 主动模式下连接的主机IP
    private var activeHost: String = "127.0.0.1"
    // 主动模式下传送数据的端口号
    private var activePort: UInt16 = 0
    // 默认用户名为anoynmous
    private var username = "anonymous"
    // 当前所处目录
    private var currentDir: Path

    public init(server: FTPServer, client: TcpSocket, timeout: UInt32, bufferSize: UInt32) {
        this.server = server
        this.client = client
        this.timeout = timeout
        this.bufferSize = bufferSize
        this.currentDir = server.getRoot()
        this.connnectHandler = ConnectionHandler()
        // 设置读取客户端超时时间
        this.client.readTimeout = Duration.second * Int64(timeout)
        // 启动处理连接的线程
        // TODO
        let thread = spawn {
            =>
            while (!client.isClosed()) {
                // 持续更新连接状态
                try {
                    update()
                } catch (e: SocketException) {
                    println("Connection closed by the remote host...")
                    close()
                }
            }
            try {
                client.close()
            } catch (e: Exception) {
                println("An Exception happen!")
            }
        }

        // 注册FTP命令
        registerCommands()
        // 通知连接已经建立，需进行验证
        sendResponse(220, "Waiting for authentication...")
    }

    // 用以注册常用的FTP命令，暂时实现ls、pwd、quit、get、put共五种功能
    public func registerCommands() {
        // 设置用户名
        addCommand("USER")
        // 输入密码
        addCommand("PASS")
        // 主动模式
        addCommand("PORT")
        // 文件列表
        addCommand("LIST")
        addCommand("NLST")
        // 从远端下载
        addCommand("RETR")
        // pwd
        addCommand("XPWD")
        // 上传
        addCommand("STOR")
        // 断开连接
        addCommand("QUIT")
        // 切换目录
        addCommand("CWD")
    }

    // 发送响应
    public func sendResponse(code: Int32, response: String) {
        if (client.isClosed()) {
            return
        }
        try {
            // 根据响应首字符发送不同格式的响应
            if (response.startsWith("-")) {
                client.write((code.toString() + response + "\r\n").toArray())
            } else {
                client.write((code.toString() + " " + response + "\r\n").toArray())
            }
        } catch (e: IOException) {
            // 发生异常关闭连接
            close()
        }
        // 指示响应已发送
        whetherSend = true
    }

    // 发送数据，采用主动模式，采用Byte数组形式
    public func sendData(data: Array<Byte>) {
        if (client.isClosed()) {
            return
        }
        // 创建数据连接的套接字
        var socket: TcpSocket
        try {
            println("Attempting to connect to ${activeHost}:${activePort}")
            socket = TcpSocket(activeHost, activePort)
            socket.connect()
            println("Connected. Sending data...")
            socket.write(data)
            println("Data sent. Closing connection...")
            // 关闭数据连接
            socket.close()
            println("Connection closed.")
        } catch (e: SocketException) {
            sendResponse(426, "Transfer aborted")
        } catch (e: IOException) {
            sendResponse(425, "An error happened while transferring data")
        }
    }

    // 接收数据
    public func receiveData(path: Path) {
        if (client.isClosed()) {
            return
        }
        let byteArrayStream = ByteArrayStream()
        let bufferedOutputStream = BufferedOutputStream(byteArrayStream)
        let socket: TcpSocket
        socket = TcpSocket(activeHost, activePort)
        socket.connect()
        // 接收ftp客户端传来的文件数据
        while (true) {
            let buf = Array<Byte>(Int64(bufferSize), item: 0)
            var count = 0
            try {
                count = socket.read(buf)
            } catch (e: SocketException) {
                break
            }
            if (count == 0) {
                break
            }
            // 不断写入数据到输出流
            bufferedOutputStream.write(buf)
        }
        bufferedOutputStream.flush()
        File.writeTo(path, byteArrayStream.readToEnd())
        socket.close()
    }

    // 注册相关指令
    public func addCommand(label: String) {
        commands.put(label.toAsciiUpper(), CommandInfo(label))
    }

    // 处理命令
    private func process(cmd: String, count: Int64) {
        // 查找第一个空格的位置
        var firstSpace = cmd.indexOf(' ').getOrDefault({=> count - 2})
        let label = cmd[0..firstSpace]
        println(label)
        if (!commands.contains(label)) {
            sendResponse(502, "Unknown command: " + label)
            return
        }
        // 正常解析，进行命令的执行
        let args: String
        if (firstSpace != count - 2) {
            args = cmd[(firstSpace + 1)..count - 2]
        } else {
            args = ""
        }
        processCommand(CommandInfo(label), args)
    }

    // 进行处理
    private func processCommand(info: CommandInfo, args: String) {
        // 需要身份验证的指令
        if (connnectHandler.needsAuth(info.getLabel()) && !connnectHandler.isAuthenticated()) {
            sendResponse(530, "Needs authentication")
            return
        }
        try {
            // 执行命令
            // println(info.getLabel())
            run(info.getLabel(), args)
        } catch (e: Exception) {
            sendResponse(550, e.message)
        }
    }

    // 更新连接
    private func update() {
        if (connnectHandler.shouldStop()) {
            client.close()
            return
        }
        var buf = Array<Byte>(Int64(bufferSize), item: 0)
        var count = 0
        try {
            count = client.read(buf)
        } catch (e: Exception) {
            return
        }

        if (count != 0) {
            process(String.fromUtf8(buf), count)
        }
    }

    // 中止连接
    public func close() {
        client.close()
        server.removeConnection(this)
    }

    // 处理不同的指令
    private func run(label: String, args: String) {
        if (label == "USER") {
            user(args)
        } else if (label == "PASS") {
            pass(args)
        } else if (label == "QUIT") {
            quit()
        } else if (label == "PORT") {
            port(args)
        } else if (label == "NLST" || label == "LIST") {
            nlst(args)
        } else if (label == "XPWD") {
            xpwd()
        } else if (label == "CWD") {
            cwd(args)
        } else if (label == "RETR") {
            retr(args)
        } else if (label == "STOR") {
            stor(args)
        }
    }

    // 处理USER指令
    private func user(username: String) {
        // 已验证身份
        if (connnectHandler.isAuthenticated()) {
            sendResponse(230, "Logged in...")
            return
        }

        // 获取身份认证器实例进行验证
        let auth = server.getAuthenticator()
        if (auth.needsPassword(username)) {
            this.username = username
            sendResponse(331, "Needs a password...")
        } else {
            if (auth.authenticate(username, "")) {
                this.username = username
                connnectHandler.setAuthenticated()
                sendResponse(230, "Logged in...")
            } else {
                sendResponse(530, "Authentication failed...")
                close()
            }
        }
    }

    // 处理PASS指令
    private func pass(password: String) {
        if (connnectHandler.isAuthenticated()) {
            sendResponse(230, "Logged in...")
        }

        // 进行身份验证
        let auth = server.getAuthenticator()
        if (auth.authenticate(username, password)) {
            connnectHandler.setAuthenticated()
            sendResponse(230, "Logged in...")
        } else {
            sendResponse(530, "Authentication failed...")
            close()
        }
    }

    // 处理QUIT指令
    private func quit() {
        sendResponse(221, "Closing connection...")
        // 关闭连接
        connnectHandler.disconnect()
    }

    // 处理PORT指令，主动模式下需使用
    private func port(args: String) {
        // 前4位为IP位，后2位为端口位，端口位1*256+端口位2=指定开启的端口
        // 示例数据：127,0,0,1,219,111
        let tmp = args.split(",")
        // 拼接得到客户端主机IP
        activeHost = tmp[0] + "." + tmp[1] + "." + tmp[2] + "." + tmp[3]
        activePort = UInt16.parse(tmp[4]) * 256 + UInt16.parse(tmp[5])
        sendResponse(200, "Enabled Active Mode...")
    }

    // 处理NLST指令，暂未对参数进行解析
    private func nlst(args: String) {
        sendResponse(150, "Sending file list...")
        let path = Directory(currentDir)
        let files = path.entryList()
        var data = ""
        // 当前目录下的文件
        for (file in files) {
            data += file.path.fileName.toString()
            data += "\r\n"
        }
        sendData(data.toArray())
        sendResponse(226, "The list was sent...")
    }

    // 处理XPWD指令
    private func xpwd() {
        sendResponse(257, "CWD NAME: " + currentDir.toString())
    }

    // 处理CWD指令
    private func cwd(path: String) {
        // 首先判断是否存在子目录而后判断是否仍为目录
        if (Directory.exists(currentDir.join(path)) && currentDir.join(path).isDirectory()) {
            currentDir = currentDir.join(path)
            sendResponse(250, "Working directory changed...")
            return
        }
        sendResponse(550, "Not a valid dictory...")
    }

    // 处理RETR指令，用以从服务器下载文件
    private func retr(path: String) {
        if (File.exists(currentDir.join(path))) {
            // 进行权限验证，判断是否具有读和下载的权限
            if (!server.getAuthenticator().readPerm(username, currentDir.join(path))) {
                sendResponse(552, "Permission denied...")
                return
            }
            sendResponse(150, "Sending the file...")
            try {
                let file = File.openRead(currentDir.join(path))
                let bytes = file.readToEnd()
                sendData(bytes)
                sendResponse(226, "File send...")
            } catch (e: Exception) {
                sendResponse(999, e.message)
            }
            return
        }
        sendResponse(550, "Not a valid file...")
    }

    // 处理STOR指令，用以上传文件到服务器
    private func stor(path: String) {
        if (!server.getAuthenticator().writePerm(username, currentDir)) {
            sendResponse(552, "Permission denied...")
            return
        }
        sendResponse(150, "Receiving a file...")
        if (File.exists(currentDir.join(path))) {
            // 文件存在，进行覆盖操作
            File.delete(currentDir.join(path))
        }
        File.create(currentDir.join(path))
        try {
            receiveData(currentDir.join(path))
            sendResponse(226, "file received...")
        } catch (e: Exception) {
            sendResponse(999, e.message)
        }
    }
}
