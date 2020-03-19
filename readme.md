# srillia/devops
### 作者：张正涵

## 简介
基于jenkins publish over ssh 插件，执行的devops cicd远程脚本

## 开始使用
jenkins的部署
```
直接在任何一台机器上部署jenkins，安装publish over ssh插件，详细说明，后补0.0

如果通过 publish over ssh 远程执行脚本找不到命令，则需要在/$HOME/.bashrc文件中添加环境变量
```
添加环境变量
```
DEVOPS_HOME=/项目所在路径/devops/

PATH=$PATH:$DEVOPS_HOME/bin
```
前置准备工作
```
版本管理工具：git,svn的安装

java项目：安装java,gradle,maven的编译工具 ;node.js项目：安装node.js(选择一种安装)

容器：docker安装 

容器管理平台：docker-swarm ,k8s （选择一个安装运行）
```
配置工作空间
```
devops目录下workspace 中的enabel.conf文件，配置你的工作目录，每一个工作目录互不干涉
```

示例用法 
```
devops run java --git-url http://192.168.10.44/sample/sample.git --java-opts "--profile=dev" sample

devops run node --git-url http://192.168.10.44/sample/sample.git  --dockerfile node --template node  sample

devops run node --svn-url http://192.168.10.44/sample/sample.git  --dockerfile node --template node  sample

devops run java --git-url https://github.com/springframeworkguru/helloworld.git --build-tool maven hello-world

devops run vue --svn-url https://192.168.10.253/svn/sample  --dockerfile node --template node --build-env "dev" sample

devops run vue --svn-url https://192.168.10.253/svn/sample  --dockerfile node --template node --build-cmds "npm run build:test" sample

```

## 详细说明
+ 可以构建java项目，或者node的vue项目，更多语言构建支持后续发布
+ 可以选择不同的代码管理工具 --git-url --svn-url,这两个是必传参数
+ 可以选择不同的构建工具，java项目下，可以选择，gradle模式，或者maven模式
+ 可以选择不同的构建平台，docker-swarm,或者k8s,通过配置文件配置config.conf中

## 项目结构
### bin目录，执行文件所在位置
```
build.sh 是脚本所有方法定义的地方 

devops 是脚本执行命令的入口

log.sh 日志脚本 
```
### deploy 部署模板生成的地方
### workspace 工作空间
```
enable.conf 是当前启动的工作目录

meal 示例工作目录,同级的都是示例工作目录 
```
#### 示例工作目录 meal
+ config.conf 当前工作空间的主配置文件
+ dockerfile 存放每一个服务的dockerfile
+ template 存放，不同构建平台的模板文件，支持docker-swarm,k8s等平台
### readme.md
+ 项目简介文件

