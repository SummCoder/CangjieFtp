package ftp.server

public class Listener {
    public func onConnected(connection: FTPConnection) {
        println("Connection is established")
    }

    public func onDisconnected(connection: FTPConnection) {
        println("Connection is closed")
    }
}
