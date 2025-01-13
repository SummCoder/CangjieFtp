//config.h
 
#define LS  1
#define PWD  2
#define GET 3
#define IFGO  4
#define CD   5
#define PUT  6
#define LLS  7
#define LCD  8
#define QUIT 9
 
//采用结构体存储指令信息
struct Message {
        char fileFlag; //处理get指令的文件判断标志
        char cmd[1024];//指令
        char contentBuf[4096];//文件内容
 
};