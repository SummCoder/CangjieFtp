## 说明

目录结构：
- cangjie-ftp：使用仓颉编程语言开发的ftp服务端
    - 已完成：
        - ls、cd、pwd、quit、get
    - 未完成：
        - put、权限控制
- python-ftp：使用python开发的ftp服务器，已完成
- client：与cangjie-ftp配套的客户端程序，采用C语言编写

注：

- client中的程序参照：https://blog.csdn.net/HermanIu/article/details/134107201 ，只是进行了少量修改。cangjie-ftp的实现思路以及基本方法也是参考本教程，同时结合仓颉语言的特性进行代码实现工作。

- 目前cangjie-ftp并不支持同一IP未断开原有连接就进行新的连接，且并不支持ftp实现标准，只是一个简易的ftp服务端程序。

python-ftp的介绍请参考 `python-ftp` 目录下的 `README` 或者 `作品简介`

下面主要介绍一下 `cangjie-ftp` 服务端程序的功能，更加详细设计实现说明请参考 [FTP服务器开发文档](FTP服务器开发文档.pdf)

## 仓颉FTP服务器

我们使用仓颉编程语言实现了FTP常见的几个命令工具，`ls`、`pwd`、`cd`、`get`以及`put`

### ls

`ls` 用以列出所在目录下的文件以及目录

![](./asset/ls.png)

核心代码：

```cangjie
let info = currentDir().fileList()
var files: String = ""
for (file in info) {
    files += file.path.fileName.toString() + "\n"
}
client.write(("0" + files + '\0').toArray())
```

通过cangjie为我们提供的获取当前所在工作目录以及目录下文件的功能即可实现。

### cd

`cd`指令帮助我们进行工作目录的切换

![](./asset/cd.png)

核心代码：

```cangjie
// 更改当前工作路径
let dir = getDestDir(String(cmd))
chdir(dir)
client.write(("0change the dictory" + "\0").toArray())
```

只需获取命令中的路径将其设置为当前工作目录即可实现该功能

### pwd

`pwd`用以获知当前所在工作目录

![](./asset/pwd.png)

核心代码：

```cangjie
// 获取当前路径
let path = currentDir().info.path.toString()
client.write(("0" + path + '\0').toArray())
```

同样可以使用cangjie已经为我们封装好的方法直接获取。

### get

`get`命令用以拉取文件将其下载到客户端本地

![](./asset/get.png)

查看效果：

![](./asset/get2.png)

上述文件已被下载到本地。

![](./asset/get3.png)

文件内容也被正确传输下载下来

