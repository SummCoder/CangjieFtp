// config.h

#define LS 1
#define PWD 2
#define GET 3
#define IFGO 4
#define CD 5
#define PUT 6
#define LLS 7
#define LCD 8
#define QUIT 9

#define USERNAME_MAX_LEN 32
#define PASSWORD_MAX_LEN 32

struct AuthMessage
{
        char username[USERNAME_MAX_LEN];
        char password[PASSWORD_MAX_LEN];
};

// 采用结构体存储指令信息
struct Message
{
        char fileFlag;         // 处理get指令的文件判断标志
        char cmd[1024];        // 指令
        char contentBuf[4096]; // 文件内容
};