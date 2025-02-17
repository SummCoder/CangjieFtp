package ftp.server

import std.collection.*
import std.socket.*
import std.sync.*
import std.fs.*
import ftp.auth.User

// FTP服务器类
public class FTPServer {
    // 存储当前连接列表
    private var connections: ArrayList<FTPConnection> = ArrayList<FTPConnection>()
    // 存储当前监听器列表
    private var listeners: ArrayList<Listener> = ArrayList<Listener>()
    // 用以互斥访问连接列表
    var mtxConnection: ReentrantMutex = ReentrantMutex()
    // 用以互斥访问监听器列表
    var mtxListener: ReentrantMutex = ReentrantMutex()
    // 身份验证
    private let auth: User
    // 空闲超时时间，默认为5分钟
    private var timeout: UInt32 = 5 * 60 * 1000
    // 缓冲区大小，默认为1024字节
    private var bufferSize: UInt32 = 1024
    // 是否启动被动模式
    private var passive = true
    // 服务端套接字
    private var serverSocket: TcpServerSocket = TcpServerSocket(bindAt: 21)
    // 所有用户数据存放的初始目录
    private let root: Path

    // 构造函数，并为其设置用户身份列表
    public init(user: User, root: Path) {
        this.auth = user
        this.root = root
    }

    // 获取是否采用被动模式
    public func getPassive() {
        return passive
    }

    // 设置是否启用被动模式，被动模式将在短暂端口范围内创建一个数据服务器用以连接
    public func setPassive(passive: Bool) {
        this.passive = passive
    }

    // 设置空闲超时
    public func setTimeout(timeout: UInt32) {
        this.timeout = timeout
    }

    // 设置缓冲区大小，注意是以字节为单位
    public func setBufferSize(bufferSize: UInt32) {
        this.bufferSize = bufferSize
    }

    // 添加监听器实例
    public func addListener(listener: Listener) {
        synchronized(mtxListener) {
            listeners.append(listener)
        }
    }

    // 移除一个监听器实例
    public func removeListener(listener: Listener) {
        synchronized(mtxListener) {
            for (i in 0..listeners.size) {
                // 比较两个对象是否是同一引用，移除该监听器
                if (refEq(listeners[i], listener)) {
                    listeners.remove(i)
                    break
                }
            }
        }
    }

    // 采用同步方式启动FTP服务器，会阻塞当前线程
    public func listen() {
        // 创建服务器套接字
        // 持续接受连接以不断更新状态
        // 设置backlog大小为50
        serverSocket.backlogSize = 50
        serverSocket.bind()
        // 检查连接是否关闭
        while (!serverSocket.isClosed()) {
            update()
        }
    }

    // 更新服务器状态
    private func update() {
        try {
            createConnection(serverSocket.accept())
        } catch (e: Exception) {
            println("An Exception happen!")
        }
    }

    // 创建一个FTP连接
    private func createConnection(client: TcpSocket) {
        // 创建连接实例
        let conncetion = FTPConnection(this, client, timeout, bufferSize)
        // TODO：如何理解？
        synchronized(mtxListener) {
            for (listener in listeners) {
                // 通知所有监听器连接已经建立
                listener.onConnected(conncetion)
            }
        }
        // 将连接添加到当前连接列表中去 
        synchronized(mtxConnection) {
            connections.append(conncetion)
        }
    }

    // 连接中止
    public func removeConnection(connection: FTPConnection) {
        synchronized(mtxListener) {
            for (listener in listeners) {
                // 通知所有监听器连接已经断开
                listener.onDisconnected(connection)
            }
        }
        // 将连接从列表中移除
        synchronized(mtxConnection) {
            for (i in 0..connections.size) {
                if (refEq(connections[i], connection)) {
                    connections.remove(i)
                    break
                }
            }
        }
    }

    // 连接中止
    public func close() {
        connections.clear()
        serverSocket.close()
    }

    public func getAuthenticator() {
        return this.auth
    }

    public func getRoot() {
        return this.root
    }
}
