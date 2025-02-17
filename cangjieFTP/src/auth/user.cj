package ftp.auth

import std.collection.*
import std.fs.*
import std.os.*

// User类用以进行身份认证
public class User {
    // 通过HashMap维护一个用户列表
    private var userList = HashMap<String, String>()
    private var permList = ArrayList<Permission>()

    // 注册用户，存入用户名和密码
    public func register(username: String, password: String) {
        userList.put(username, password)
    }

    // 是否需要密码，默认为true，除了anonymous用户
    public func needsPassword(username: String) {
        if (username == "anonymous") {
            return false
        }
        return true
    }

    // 进行用户的身份认证
    public func authenticate(username: String, password: String) {
        // 检查是否存在该用户名
        if (!userList.contains(username)) {
            return false
        }
        if (password != userList[username]) {
            return false
        }
        return true
    }

    // 添加文件权限
    public func addPermission(username: String, filepath: Path, read: Bool, write: Bool) {
        permList.append(Permission(username, filepath, read, write))
    }

    // 添加文件权限
    public func addPermission(username: String, filepath: Path) {
        permList.append(Permission(username, filepath))
    }

    // 获取文件读权限
    public func readPerm(username: String, filepath: Path) {
        for (perm in permList) {
            // 查找到相匹配的
            // 根据目录递归匹配，所以这里直接看绝对路径是否呈现出包含关系
            if (perm.username == username && filepath
                .toCanonical()
                .toString()
                .startsWith(perm.filepath.toCanonical().toString())) {
                return perm.read
            }
        }
        // 查找不到一律返回false
        return false
    }

    // 获取文件写权限
    public func writePerm(username: String, filepath: Path) {
        for (perm in permList) {
            // 同理
            if (perm.username == username && filepath
                .toCanonical()
                .toString()
                .startsWith(perm.filepath.toCanonical().toString())) {
                return perm.write
            }
        }
        // 查找不到一律返回false
        return false
    }
}

// 维护用户和对应文件关系的表
public class Permission {
    public let username: String
    public let filepath: Path
    public let read: Bool
    public let write: Bool

    // 不提供读和写权限时默认为无权限
    public init(username: String, filepath: Path) {
        this.username = username
        this.filepath = filepath
        this.read = false
        this.write = false
    }

    public init(username: String, filepath: Path, read: Bool, write: Bool) {
        this.username = username
        this.filepath = filepath
        this.read = read
        this.write = write
    }
}
