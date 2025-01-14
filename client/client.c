#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include "config.h"
#include <fcntl.h>

static int count = 0;

char *getLocalDir(char *cmd)
{
	char *p = NULL;
	//::char *strtok(char *str, const char *delim);
	p = strtok(cmd, " ");
	p = strtok(NULL, " ");
	return p;
}

int commandHandler(struct Message msg, int fd)
{

	char *filePath = NULL;
	char *dir;
	int file_fd;
	int cmdType = getCommandType(msg.cmd);
	char tempBuf[32];
	printf("commandHandler:msg.cmd is %s\n", msg.cmd);
	switch (cmdType)
	{
	case LS:
	case PWD:
	case CD:
		count++;
		write(fd, &msg, sizeof(msg));
		break;

	case GET:
		count++;
		write(fd, &msg, sizeof(msg));
		break;
	case PUT:
		count++;
		strcpy(tempBuf, msg.cmd);
		// strtok函数会改变msg.cmd ，采用临时变量替代msg.cmd
		filePath = getLocalDir(tempBuf);
		printf("filePath is %s\n", filePath);
		if (access(filePath, F_OK) == -1)
		{
			printf("%s doesn't exist!\n", filePath);
		}
		else
		{

			// 本地存在待和上传的文件
			file_fd = open(filePath, O_RDWR);
			memset(msg.contentBuf, 0, sizeof(msg.contentBuf));
			read(file_fd, msg.contentBuf, sizeof(msg.contentBuf));
			close(file_fd);
			write(fd, &msg, sizeof(msg));
		}
		break;
	case LLS:
		count++;
		system("ls");
		break;

	case LCD:
		count++;
		dir = getLocalDir(msg.cmd);
		chdir(dir);
		break;

	case QUIT:
		count++;
		write(fd, &msg, sizeof(msg));
		close(fd);
		exit(-1);
	}
	return cmdType;
}

// 指令转换为整形 供switch处理
int getCommandType(char *cmd)
{

	if (!strcmp("ls", cmd))
		return LS;
	if (!strcmp("lls", cmd))
		return LLS;
	if (!strcmp("pwd", cmd))
		return PWD;
	if (!strcmp("quit", cmd))
		return QUIT;

	if (strstr(cmd, "lcd"))
		return LCD;
	if (strstr(cmd, "cd"))
		return CD;
	if (strstr(cmd, "get"))
		return GET;
	if (strstr(cmd, "put"))
		return PUT;

	return -1;
}

// 处理服务端响应的信息
void serverMessageHandler(int fd, struct Message msg)
{

	struct Message recMsg;
	int nread = read(fd, &recMsg, sizeof(recMsg));
	// TCP协议某一方关闭连接时，read（）返回0，读不到数据
	if (nread == 0)
	{
		puts("server disconnected...");
		exit(-1);
	}
	else if (recMsg.fileFlag == 1)
	{
		char *dir = getLocalDir(msg.cmd);
		printf("local fileName:%s\n", dir);
		int newFilefd = open(dir, O_RDWR | O_CREAT, 0600);
		write(newFilefd, recMsg.contentBuf, strlen(recMsg.contentBuf));
		putchar('>');
		fflush(stdout);
	}
	else
	{
		puts("----------------------------");
		printf("%s\n", recMsg.cmd);
		puts("----------------------------");
		putchar('>');
		fflush(stdout);
	}
}

int main(int argc, char **argv)
{
	// 变量定义
	int c_fd;
	int n_read;

	struct sockaddr_in c_addr;
	struct Message msg;
	// 参数个数判断
	if (argc != 3 && argc != 1)
	{

		printf("error:please input username and password\n", argc);
		exit(-1);
	}
	// 初始化内存
	memset(&c_addr, 0, sizeof(struct sockaddr_in));

	// socket
	//  int socket(int domain, int type, int protocol);
	c_fd = socket(AF_INET, SOCK_STREAM, 0);

	// ip and port
	c_addr.sin_family = AF_INET;
	c_addr.sin_port = htons(21);
	// 字符串IP地址转换为一个32位的网络序列IP地址
	inet_aton("127.0.0.1", &c_addr.sin_addr);

	int clen = sizeof(struct sockaddr_in);
	// int connect(int sockfd, const struct sockaddr *addr,socklen_t addrlen);
	if (connect(c_fd, (struct sockaddr *)&c_addr, clen) == -1)
	{
		perror("create client socket failed...\n");
		exit(-1);
	}

	// 发送用户名和密码
	struct AuthMessage auth;

	// 检查命令行输入参数
	if (argc == 3)
	{
		// 参数数量为3，使用提供的用户名和密码
		strncpy(auth.username, argv[1], USERNAME_MAX_LEN);
		strncpy(auth.password, argv[2], PASSWORD_MAX_LEN);
	}
	else
	{
		// 参数数量为1，使用默认值
		strncpy(auth.username, "anonymous", USERNAME_MAX_LEN);
		strncpy(auth.password, "", PASSWORD_MAX_LEN); // 空密码
	}

	// 发送认证信息给服务器
	send(c_fd, &auth, sizeof(auth), 0); // 发送结构体

	// 接收服务器的响应
	char response[256];					   // 用于接收服务器响应的缓冲区
	memset(response, 0, sizeof(response)); // 清空缓冲区

	int nread = read(c_fd, &response, sizeof(response));
	// TCP协议某一方关闭连接时，read（）返回0，读不到数据
	if (nread == 0)
	{
		puts("wrong username or password!");
		exit(-1);
	}

	// 客户端连接到服务端
	printf("we have been connected with the server\n");

	int mark = 0;

	while (1)
	{
		memset(msg.cmd, 0, sizeof(msg.cmd));
		if (mark == 0)
		{
			putchar('>');
		}
		mark = 1;
		gets(msg.cmd);
		int commandType = commandHandler(msg, c_fd);
		printf("count=%d\n", count);
		if (commandType > QUIT)
		{
			putchar('>');
			fflush(stdout);
			continue;
		}
		if (commandType == -1)
		{
			puts("command not found");
			putchar('>');
			fflush(stdout);
			continue;
		}
		// printf("%d", msg.fileFlag);
		serverMessageHandler(c_fd, msg);
	}

	return 0;
}
