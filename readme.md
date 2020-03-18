# srillia/devops
### 作者：张正涵

## 简介
基于jenkins publish over ssh 插件，执行的devops cicd远程脚本

## 开始使用
示例用法 
```
./devops run java --git-url http://192.168.10.44/unsun/framework-console.git --build-env console-dev console-config

./devops run node --git-url http://192.168.10.44/front-end/teacher-cloud-community.git  --dockerfile node --template node  teacher-cloud-community

./devops run node --svn-url https://192.168.10.253/svn/教师云/2.0/3.项目实施/移动端代码/teacher-cloud-community  --dockerfile node --template node  teacher-cloud-community
```

## 详细说明
+ 可以构建java项目，或者node的vue项目，更多语言构建支持后续发布
+ 可以选择不同的代码管理工具 --git-url --svn-url,这两个是必传参数
+ 可以选择不同的构建工具，java项目下，可以选择，gradle模式，或者maven模式(代码没上)
+ 可以选择不同的构建平台，docker-swarm,或者k8s,通过配置文件配置config.conf中

## 项目结构

### build.sh
+ 是脚本所有方法定义的地方
### devops
+ 是脚本执行命令的入口
### deploy
+ 部署模板生成的地方
### config
每一个工作者的工作空间
```
enable.conf 是当前启动的工作目录
meal 示例工作目录,同级的都是示例工作目录 	
```
#### 示例工作目录 meal
+ config.conf 当前工作空间的主配置文件
+ dockerfile 存放每一个服务的dockerfile
+ env 存放不同服务，不同环境的文件
+ template 存放，不同构建平台的模板文件，支持docker-swarm,k8s等平台
### readme.md
+ 项目简介文件

