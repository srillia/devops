# srillia/devops
### 作者：张正涵

## 最新动态
devops 1.6发布
1.6 增加新功能:
```
本地一套环境，支持任意远程集群发布

(解决，devops必须在集群主机上进行构建的局限，现在可以用一个主机作构建，完全和远程集群服务器解耦和)

需要配置 deploy-target文件到 $HOME/.deploy/ 下，在workspace目录里面有样本文件

deploy-target 不配置不启用远程部署，使用本地构建

配置key需要和 --workspace 参数，和工作目录一致 例:

	--workspace meal ,工作目录 meal, deploy-target 文件中存在 key 为meal 的主机配置
```
devops 1.5.1已经发布release

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
vim /etc/profile 添加环境变量

DEVOPS_HOME=/项目所在路径/devops/

PATH=$PATH:$DEVOPS_HOME/bin

同时需要添加环境变量到 /root/.bashrc文件中

vim /root/.bashrc

包括 devops java git svn maven gradle npm docker 等等命令到.bashrc中，不然jenkins远程执行找不到命令

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

devops run java --git-url https://github.com/springframeworkguru/helloworld.git --build-tool maven hello-world

devops run vue --git-url http://192.168.10.44/sample/sample.git  --dockerfile node --template node  sample

devops run vue --svn-url https://192.168.10.253/svn/sample  --dockerfile node --template node --build-env "dev" sample

devops run vue --svn-url https://192.168.10.253/svn/sample  --dockerfile node --template node --build-cmds "npm run build:test" sample

注意: 最后一个参数，应该为你需要构建项目的那个直接的项目名.
      如果是单级项目，为主项目名，如果为多级项目，为那个直接的子项目名.
      比如java 项目, maven pom中指定的那(如果是多级项目的话)个子项目名

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
### workspace 工作空间(工作空间的目的，是为了区分，当存在多个构建环境时，每个工作空间配置文件互不影响)
```
enable 激活当前的工作目录的配置文件

meal 示例工作目录,同级的都是示例工作目录 
```
#### 示例工作目录 meal
+ config 当前工作空间的主配置文件
+ dockerfile 存放每一个服务的dockerfile
+ template 存放，不同构建平台的模板文件，支持docker-swarm,k8s等平台
### readme.md
+ 项目简介文件

