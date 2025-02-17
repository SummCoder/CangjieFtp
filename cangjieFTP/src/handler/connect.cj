package ftp.handler


public class ConnectionHandler {

    private var auth = false

    private var stop = false

    public func isAuthenticated() {
        return auth
    }

    public func setAuthenticated() {
        auth = true
    }

    public func needsAuth(label: String) {
        if (label == "USER" || label == "PASS" || label == "QUIT") {
            return false
        }
        return true
    }

    public func shouldStop() {
        return stop
    }

    public func disconnect() {
        stop = true
    }

}