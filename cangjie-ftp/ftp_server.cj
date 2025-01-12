// ftp服务端，简易实现6种基本操作：ls、pwd、get、cd、put、quit

import std.socket.*
import std.fs.*
import std.os.*
import std.sync.*
import std.time.*
import std.collection.*
import std.os.posix.*
import std.io.SeekPosition

// 服务端绑定端口号为21
const SERVER_PORT: UInt16 = 21

// 定义命令的可能枚举值
const Error = 0
const LS = 1
const PWD = 2
const GET = 3
const CD = 4
const PUT = 5
const QUIT = 6
enum Message {
    | LS | PWD | GET | CD | PUT | QUIT | Error
}

// 用以权限验证的类
struct User {  
    var username: String  
    var password: String

    public init(username:String, password:String) {
        this.username = username
        this.password = password
    }  
}  



// 用于客户端和服务端传输内容的结构体
struct Trans {
    var fileFlag: Byte
    var cmd: Array<Byte>
    var contentBuf: Array<Byte>

    // 进行结构体初始化工作
    public init() {
        this.fileFlag = 0
        this.cmd = Array<Byte>(1024, item: 0)
        this.contentBuf = Array<Byte>(4096, item: 0)
    }

    public func toString() {
        return fileFlag.toString() + cmd.toString() + contentBuf.toString()
    }
}

// getCommandType函数，将收到的命令字符串转换到上述对应的枚举值
func getCommandType(cmd: String) {

    if (cmd == "ls") {
        return Message.LS
    } else if (cmd == "pwd") {
        return Message.PWD
    } else if (cmd == "quit") {
        return Message.QUIT
    } else if (cmd.startsWith("cd")) {
        return Message.CD
    } else if (cmd.startsWith("get")) {
        return Message.GET
    } else if (cmd.startsWith("put")) {
        return Message.PUT
    } else {
        // 未被定义的操作，反馈给用户即可
        return Message.Error
    }

}

// 此函数用于获取参数中的路径或文件
func getDestDir(cmd: String) {
    return cmd.split(" ")[1]
}

// 服务端处理接收到的消息，核心代码
func messageHandler(buf: Array<Byte>, client: TcpSocket) {
    // 解析指令类型
    var msg = Trans()
    buf.copyTo(msg.cmd, 1, 0, 1024)
    buf.copyTo(msg.contentBuf, 1025, 0, 4096)
    let commandType = getCommandType(msg.cmd.toString())

    // 依据类型执行不同操作
    match (commandType) {
        case Message.LS =>
            let info = currentDir().fileList()
            var files: String = ""
            for (file in info) {
                files += file.path.fileName.toString() + "\n"
            }
            client.write(files.toArray())
        case Message.PWD => 
            // 获取当前路径
            let path = currentDir().info.path.toString()
            client.write(path.toArray())
        case Message.Error => client.write("Command undefined!".toArray())
        case Message.GET => 
            // 首先判断文件是否存在
            let path = getDestDir(msg.cmd.toString())
            let exists = File.exists(path)
            if (exists) {
                // 文件存在，读取文件到dataBuf中
                let dataBuf = Array<Byte>(4096, item: 0)
                msg.fileFlag = 1
                // 以只读模式打开文件
                var file: File = File(path, OpenOption.Open(true, false))
                file.seek(SeekPosition.Begin(0))
                file.read(dataBuf)
                file.close()
                msg.contentBuf = dataBuf
                client.write(msg.toString().toArray())
            } else {
                client.write("file does not exist!".toArray())
            }
        case Message.PUT => 
            // 首先判断文件是否存在
            let path = getDestDir(msg.cmd.toString())
            let exists = File.exists(path)
            if (exists) {
                // 文件存在，先将其删除
                File.delete(path)
            }
            var file: File = File(path, OpenOption.Create(false))
            if (File.exists(path)) {
                println("The file ${path} is created successfully in current directory.\n")
            }
            let bytes: Array<Byte> = msg.contentBuf
            file.write(bytes)
            file.close()
        case Message.QUIT => println("Disconnect")
        case Message.CD => 
        // 更改当前工作路径
            let dir = getDestDir(msg.cmd.toString())
            chdir(dir)
            client.write("change the dictory".toArray())     
    }
}

main() {

    try (serverSocket = TcpServerSocket(bindAt: SERVER_PORT)){
        serverSocket.bind()
        // 不断获取客户端连接
        while(true) {
            try (client = serverSocket.accept()) {
                println("Server has established a connect with:" + client.remoteAddress.toString())

                // 创建一个新线程进行处理，从而实现并发
                spawn { =>
                    while(true) {
                        let buf = Array<Byte>(5120, item: 0)
                        let count = client.read(buf)
                        println("Server read ${count} bytes")
                        if (count == 0) {
                            // 读取结果为0字节，表示客户端已经中止连接
                            println("client disconnected!")
                            break
                        } 
                        // 否则表示存在信息，进行处理
                        messageHandler(buf, client)
                    }
                }
            }
        }
    }
}
