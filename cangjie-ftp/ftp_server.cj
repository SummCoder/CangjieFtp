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

    if (cmd.startsWith("ls")) {
        return Message.LS
    } else if (cmd.startsWith("pwd")) {
        return Message.PWD
    } else if (cmd.startsWith("quit")) {
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
    try {
        return cmd.split(" ")[1].split("\0")[0]
    }
    catch (e: Exception) {
        println("Error happen!")
    }
    // 路径出错时默认保持当前路径不变
    return "."
}

// 服务端处理接收到的消息，核心代码
func messageHandler(buf: Array<Byte>, client: TcpSocket) {
    // 解析指令类型
    var msg = Trans()
    // println(buf)
    buf.copyTo(msg.cmd, 1, 0, 1024)
    buf.copyTo(msg.contentBuf, 1025, 0, 4096)

    // 将命令转化为字符数组进而转化为字符串 
    var cmd = Array<Rune>(1024, item: r'\0')
    for(i in 0..=1023) {
        cmd[i] = Rune(msg.cmd[i])
    }
    // println(String(cmd))
    
    let commandType = getCommandType(String(cmd))

    // 依据类型执行不同操作
    match (commandType) {
        case Message.LS =>
            let info = currentDir().fileList()
            var files: String = ""
            for (file in info) {
                files += file.path.fileName.toString() + "\n"
            }
            client.write(("0" + files + '\0').toArray())
        case Message.PWD => 
            // 获取当前路径
            let path = currentDir().info.path.toString()
            client.write(("0" + path + '\0').toArray())
        case Message.CD => 
            // 更改当前工作路径
            let dir = getDestDir(String(cmd))
            chdir(dir)
            client.write(("0change the dictory" + "\0").toArray())     
        case Message.Error => client.write(("0Command undefined!" + "\0").toArray())
        case Message.GET => 
            // 首先判断文件是否存在
            let path: Path = Path(getDestDir(String(cmd)))
            println(path)
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
                client.write("0file does not exist!\0".toArray())
            }
        case Message.PUT => 
            // 首先判断文件是否存在
            let path = getDestDir(String(cmd))
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
    }
}

main() {

    try (serverSocket = TcpServerSocket(bindAt: SERVER_PORT)){
        serverSocket.bind()
        // 不断获取客户端连接
        while(true) {
            try (client = serverSocket.accept()) {
                println("Server has established a connect with:" + client.remoteAddress.toString())

                while(true) {
                    let buf = Array<Byte>(5121, item: 0)
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
