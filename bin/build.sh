#!/bin/bash
source ${dic[cfg_devops_bin_path]}/log.sh

function check_env_by_cmd_v() {
	command -v $1 > /dev/null 2>&1 || (error "Need to install ##$1## command first and run this script again." && exit 1)
}

function parse_params() {
        case "$1" in
	-v) echo "devops version 1.6.5" ; exit 1;;
        --version) echo "devops version 1.6.5" ; exit 1;;
        -h)  devops_help ; exit 1;;
        *) 
                dic[cmd_1]=$1
                shift 1
                case "$1" in
                -h)  echo "thanks for use devops!" ; exit 1;;
                *)
                        dic[cmd_2]=$1
                        shift 1
                        while [ true ] ; do
                                if [[ $1 == -* ]];then
                                        case "$1" in
                                        --build-tool) dic[opt_build_tool]=$2; shift 2;;
                                        --git-url) dic[opt_git_url]=$2;  shift 2;;
                                        --svn-url) dic[opt_svn_url]=$2; shift 2;;
                                        --java-opts) dic[opt_java_opts]=$2; shift 2;;
                                        --dockerfile) dic[opt_dockerfile]=$2; shift 2;;
										--template) dic[opt_template]=$2; shift 2;;
										--git-branch) dic[opt_git_branch]=$2; shift 2;;
										--build-cmds) dic[opt_build_cmds]=$2; shift 2;;
                                        --build-env) dic[opt_build_env]=$2; shift 2;;
										--workspace) dic[opt_workspace]=$2; shift 2;;
                                        *) error "unknown parameter or command $1 ." ; exit 1 ; break;;
                                        esac
                                else
                                        dic[cmd_3]=$1
                                        shift 1
                                        break
                                fi
                        done

                ;;  esac
        ;; esac
}


function devops_help() {
	echo -e 'Usage:  devops [OPTIONS] COMMAND

	A cicd tool for devops
	
	Options:
	      --build-tool string    java build tool "maven" or "gradle"
	      --git-url string       the url of git registry
	      --git-branch string    the branch of git registry
	      --svn-url string       the url of svn registry
	      --java-opts string     the java -jar ${java-opts} foo.jar
	      --dockerfile string    the use of the dockerfile for this job
	      --template string      the use of the docker swram or k8s template for this job
	      --build-cmds string    the cmd rewrite for building this job
	      --build-env string     build env "dev" "test" "gray" "prod" etc.
	      --version              the version of devops
	
	Commands:
	  run      now you can "run java" or "run vue"'
	exit 1;
	
}

function run() {
        case ${dic[cmd_1]} in
        run) 
                if test -n ${dic[cmd_2]}; then
                        run_${dic[cmd_2]}
                else
                        echo "run need be followed by a cammand"; exit 1
                fi
         ;;
        *) error "cannot find the cammand ${dic[cmd_1]}"; exit 1 ; ;;
	esac
}

function check_post_parmas() {
 	if [[ -z ${dic[cmd_3]} ]];then
                warn "job name can not be null ## $1 ##."; exit 1;
	 fi
	dic[cmd_job_name]=${dic[cmd_3]} 
	dic[cfg_temp_dir]=/tmp/devops/${dic[opt_workspace]}/${dic[cmd_job_name]}
	rm -rf ${dic[cfg_temp_dir]}
}


function run_java() {
        run_devops java_build
}


function run_go() {
	run_devops go_build
}


function run_vue() {
	run_devops vue_build
}

function run_devops() {
        #检测前置参数
	check_post_parmas
	#从版本管理工具加载代码
	scm 
	#复制dockerfile文件
	choose_dockerfile 
	#开始构建，构建不同的项目，java,vue,go等
	$1
	#渲染模板
	render_template 
	#执行部署
	deploy 
	#清除冗余镜像
	prune 

}


function scm() {
	cfg_temp_dir=${dic[cfg_temp_dir]}
	opt_git_url=${dic[opt_git_url]}
	opt_git_branch=${dic[opt_git_branch]}
	opt_svn_url=${dic[opt_svn_url]}

	if [ -n "$opt_git_url" ]; then 
		check_env_by_cmd_v git
		#克隆代码
		if test -n "${opt_git_branch}" ; then
			info "开始使用git拉取代码,当前分支:${opt_git_branch}"
			#处理存在orgin/test的问题
			real_branch=${opt_git_branch##*/}
			echo "埋点:git的real_branch:$real_branch"
			git clone -b  ${real_branch}  --single-branch $opt_git_url  $cfg_temp_dir
		else 
			 info "开始使用git拉取代码,当前使用默认分支"
		        git clone --single-branch $opt_git_url  $cfg_temp_dir
		fi
		cd $cfg_temp_dir
		#生成日期和git日志版本后六位
		date=`date +%Y-%m-%d_%H-%M-%S`
		last_log=`git log --pretty=format:%h | head -1`
		dic[tmp_docker_image_suffix]="${date}_${last_log}"
	elif [ -n "$opt_svn_url" ]; then 
		check_env_by_cmd_v svn
		info '开始使用 svn 拉取代码'
		debug '此处忽略svn拉取日志'
		svn checkout -q $opt_svn_url $cfg_temp_dir
		cd $cfg_temp_dir
		date=`date +%Y-%m-%d_%H-%M-%S`
		tmp_log=`svn log | head -2 | tail -1`
		last_log=${tmp_log%% *}
                dic[tmp_docker_image_suffix]="${date}_${last_log}"
	else 
		error "--git-url and --svn-url must has one"; exit 1;
	fi
}

function go_build() {
	cfg_temp_dir=${dic[cfg_temp_dir]}
	cmd_job_name=${dic[cmd_job_name]}
	opt_build_tool=${dic[opt_build_tool]}
	opt_build_cmds=${dic[opt_build_cmds]}
	cfg_harbor_address=${dic[cfg_harbor_address]}
	cfg_harbor_project=${dic[cfg_harbor_project]}
	tmp_dockerfile=${dic[tmp_dockerfile]}
	tmp_docker_image_suffix=${dic[tmp_docker_image_suffix]}	

	dic[tmp_go_workspace]=/tmp/devops-go
	dic[tmp_go_workspace_src]=${dic[tmp_go_workspace]}/src
	dic[tmp_go_workspace_src_ws]=${dic[tmp_go_workspace_src]}/${dic[opt_workspace]}
	#生成gopath和src
	if test ! -d "${dic[tmp_go_workspace_src_ws]}" ;then
		mkdir -p ${dic[tmp_go_workspace_src_ws]}
	fi
	export GOAPTH=${dic[tmp_go_workspace]}
	
	rm -rf ${dic[tmp_go_workspace_src_ws]}/${cmd_job_name}

	\mv $cfg_temp_dir ${dic[tmp_go_workspace_src_ws]}
	dic[cfg_temp_dir]=${dic[tmp_go_workspace_src_ws]}/${cmd_job_name}


	module_path=`find ${dic[cfg_temp_dir]}/* -type d  -name  ${cmd_job_name}`
        if test -z "$module_path"; then module_path=${dic[cfg_temp_dir]}; fi


        #go语言构建不会把静态文件构建进二进制文件，dockerfile build的时，需要自定义dockerfile将，静态文件copy到容器中
	check_env_by_cmd_v go
	info "开始使用go构建项目"
	#构建代码
	if test -n "$opt_build_cmds" ;then
		cd $module_path && $opt_build_cmds
    	else
		cd $module_path && go build -o ./
    	fi
	dic[tmp_build_dist_path]=$module_path


    	info "开始go项目镜像的构建"

	check_env_by_cmd_v docker
	# 构建镜像
	image_path=$cfg_harbor_address/$cfg_harbor_project/${cmd_job_name}_${tmp_docker_image_suffix}:latest
	tar -cf dist.tar *
	docker build  --build-arg DEVOPS_RUN_ENV=${dic[opt_build_env]} \
		 -t $image_path -f  $tmp_dockerfile  ${dic[tmp_build_dist_path]}

	#推送镜像
	info "开始向harbor推送镜像"
	docker push $image_path
	dic[tmp_image_path]=$image_path
}

function java_build() {
	cfg_temp_dir=${dic[cfg_temp_dir]}
	cmd_job_name=${dic[cmd_job_name]}
	opt_build_tool=${dic[opt_build_tool]}
	opt_build_cmds=${dic[opt_build_cmds]}
	opt_java_opts=${dic[opt_java_opts]}
	tmp_dockerfile=${dic[tmp_dockerfile]}	
	cfg_harbor_address=${dic[cfg_harbor_address]}
	cfg_harbor_project=${dic[cfg_harbor_project]}
	tmp_docker_image_suffix=${dic[tmp_docker_image_suffix]}

	module_path=`find $cfg_temp_dir/* -type d  -name  ${cmd_job_name}`
        if test -z "$module_path"; then module_path=$cfg_temp_dir; fi


	case "$opt_build_tool"  in
	gradle)
		check_env_by_cmd_v gradle
		info "开始使用gradle构建项目"
		#构建代码
		if test -n "$opt_build_cmds" ;then
			cd $module_path && $opt_build_cmds
        	else
			cd $module_path && gradle -x test clean build
        	fi
		dic[tmp_build_dist_path]=$module_path/build/libs
	 ;;
	maven)
		check_env_by_cmd_v mvn
		info "开始使用gradle构建项目"
		 #构建代码
                if test -n "$opt_build_cmds" ;then
			cd $module_path && ${opt_build_cmds}
		else
			cd $module_path && mvn clean -Dmaven.test.skip=true  compile package -U -am
		fi
		dic[tmp_build_dist_path]=$module_path/target
       	#to do
	 ;;
	*) warn "java project only support gradle or maven build"; exit 1; ;;
    	esac


	info "开始java项目镜像的构建"

	# 查找jar包名
	cd ${dic[tmp_build_dist_path]}
	jar_name=`ls | grep -v 'source'| grep ${cmd_job_name}`
	
	check_env_by_cmd_v docker

	# 构建镜像
	image_path=$cfg_harbor_address/$cfg_harbor_project/${cmd_job_name}_${tmp_docker_image_suffix}:latest
	docker build --build-arg jar_name=$jar_name\
	       --build-arg java_opts="$opt_java_opts"\
	       -t $image_path -f $tmp_dockerfile ${dic[tmp_build_dist_path]}

	#推送镜像
	info "开始向harbor推送镜像"
	docker push $image_path
	dic[tmp_image_path]=$image_path
}

function vue_build() {
    cfg_temp_dir=${dic[cfg_temp_dir]}
    cmd_job_name=${dic[cmd_job_name]}
	opt_build_cmds=${dic[opt_build_cmds]}
	opt_build_env=${dic[opt_build_env]}	
	cfg_harbor_address=${dic[cfg_harbor_address]}
	cfg_harbor_project=${dic[cfg_harbor_project]}
	tmp_dockerfile=${dic[tmp_dockerfile]}	
	tmp_docker_image_suffix=${dic[tmp_docker_image_suffix]}

	check_env_by_cmd_v npm	
	info "开始使用node构建vue项目"
        module_path=`find $cfg_temp_dir/* -type d  -name  ${cmd_job_name}`
        if test -z "$module_path"; then module_path=$cfg_temp_dir; fi
	if test -n "$opt_build_cmds" ;then
		cd $module_path &&  npm --unsafe-perm install && $opt_build_cmds
	else
		if test -n "$opt_build_env" ;then
			cd $module_path && npm --unsafe-perm install && npm run build:$opt_build_env
		else
			cd $module_path && npm --unsafe-perm install && npm run build
		fi
	fi

	dic[tmp_build_dist_path]=$module_path/dist

        info "开始vue项目镜像的构建"
	cd ${dic[tmp_build_dist_path]}
	tar -cf dist.tar *
	check_env_by_cmd_v docker
	# 构建镜像
	image_path=$cfg_harbor_address/$cfg_harbor_project/${cmd_job_name}_${tmp_docker_image_suffix}:latest
	docker build -t $image_path -f  $tmp_dockerfile  ${dic[tmp_build_dist_path]}

	#推送镜像
	info "开始向harbor推送镜像"
	docker push $image_path
	dic[tmp_image_path]=$image_path
}

function choose_dockerfile() {
	cmd_job_name=${dic[cmd_job_name]}
	opt_dockerfile=${dic[opt_dockerfile]}
	cfg_dockerfile_path=${dic[cfg_dockerfile_path]}
	cfg_enable_dockerfiles=${dic[cfg_enable_dockerfiles]}
	tmp_build_dist_path=${dic[tmp_build_dist_path]}

        if test ! -d ${tmp_build_dist_path} ; then
		error "please check scm url or job name(the last command),job name must be the module name";
                exit 1;
	fi		
	#info "开始复制dockerfile到构建目录"
	if test -n "${opt_dockerfile}"
	then
		echo "埋点:执行命令行指定dockerfile${opt_dockerfile}"
   		dic[tmp_dockerfile]=$cfg_dockerfile_path/${opt_dockerfile}-dockerfile 
	else
		dockerfiles=(${cfg_enable_dockerfiles//,/ })
		is_has_enable_docker_file=false
		for dockerfile in ${dockerfiles[@]} ;do
			if [[ $cmd_job_name == $dockerfile ]]
			then
			  echo "埋点:执行在config.conf配置的dockerfile:${dockerfile}"
			  dic[tmp_dockerfile]=$cfg_dockerfile_path/${dockerfile}-dockerfile
			  is_has_enable_docker_file=true
			fi
		done
		if [ "$is_has_enable_docker_file" = false ]; then
			echo "埋点:执行默认指定dockerfile"
		   	dic[tmp_dockerfile]=$cfg_dockerfile_path/dockerfile
		fi
	fi
}



function render_template() {
	opt_template=${dic[opt_template]}
	cfg_devops_path=${dic[cfg_devops_path]}
	cfg_swarm_network=${dic[cfg_swarm_network]}
	cfg_template_path=${dic[cfg_template_path]}
	cfg_enable_templates=${dic[cfg_enable_templates]}
	cfg_deploy_gen_location=${dic[cfg_deploy_gen_location]}
	cmd_job_name=${dic[cmd_job_name]}
	tmp_image_path=${dic[tmp_image_path]}

        #info "开始渲染模板文件"
	cd $cfg_template_path
	gen_long_time_str=`date +%s%N`

	 #处理模板路由信息
	if test -n "${opt_template}"; then
		\cp ./${opt_template}-template.yml ./${gen_long_time_str}.yml
	else
		templates=(${cfg_enable_templates//,/ })
	        is_has_enable_template=false
	        for template in ${templates[@]}
	        do
	        if [[ $cmd_job_name == $template ]]
	        then
	           \cp ./$cmd_job_name-template.yml ./${gen_long_time_str}.yml
	           is_has_enable_template=true
       		fi
	        done
       		if [ "$is_has_enable_template" = false ]
        	then
            	\cp ./template.yml ./${gen_long_time_str}.yml
        	fi
	fi

	#执行替换
	sed -i "s#?module_name#${cmd_job_name}#g"  ./${gen_long_time_str}.yml
	sed -i "s#?image_path#${tmp_image_path}#g"  ./${gen_long_time_str}.yml
	sed -i "s#?network#${cfg_swarm_network}#g"  ./${gen_long_time_str}.yml
	#生成文件
	if [ ! -d "$cfg_deploy_gen_location" ];then
	mkdir -p $cfg_deploy_gen_location
	fi
	\mv ./${gen_long_time_str}.yml $cfg_deploy_gen_location/${cmd_job_name}.yml
}

function deploy() {
        cfg_deploy_target=${dic[cfg_deploy_target]}
	if test -z "$cfg_deploy_target"  ; then
		info "执行本地部署"
		local_deploy
	else
		echo "执行远程部署"
		remote_deploy
	fi

}

function local_deploy() {
  	cfg_devops_path=${dic[cfg_devops_path]}
    cfg_build_platform=${dic[cfg_build_platform]}
    cfg_swarm_stack_name=${dic[cfg_swarm_stack_name]}
	cfg_deploy_gen_location=${dic[cfg_deploy_gen_location]}
    cmd_job_name=${dic[cmd_job_name]}

	deploy_job_yml=$cfg_deploy_gen_location/${cmd_job_name}.yml
        #创建或者更新镜像
        if [ "$cfg_build_platform" = "KUBERNETES" ]
        then
                check_env_by_cmd_v kubectl
                info "开始使用k8s部署服务"
                kubectl apply -f  ${deploy_job_yml}
        elif [ "$cfg_build_platform" = "DOCKER_SWARM" ]
        then
                info "开始使用docker swarm部署服务"
                docker stack deploy -c ${deploy_job_yml} ${cfg_swarm_stack_name}  --with-registry-auth
        else
                info "开始使用docker swarm部署服务"
                docker stack deploy -c ${deploy_job_yml} ${cfg_swarm_stack_name} --with-registry-auth
        fi
}

function remote_deploy() {

	cfg_devops_path=${dic[cfg_devops_path]}
    cfg_build_platform=${dic[cfg_build_platform]}
    cfg_swarm_stack_name=${dic[cfg_swarm_stack_name]}
	cfg_deploy_target=${dic[cfg_deploy_target]}
	cfg_deploy_gen_location=${dic[cfg_deploy_gen_location]}
    cmd_job_name=${dic[cmd_job_name]}

	deploy_job_yml=$cfg_deploy_gen_location/${cmd_job_name}.yml

        array=(${cfg_deploy_target//:/ })
        user=${array[0]}
        ip=${array[1]}
        password=${array[2]}

        if test -z "$user" -o -z "$ip" -o -z "$password" ; then
                error '执行远程构建，deploy_target的配置不正确'
                exit 1
        fi


        #创建或者更新镜像
        if [ "$cfg_build_platform" = "KUBERNETES" ]
        then
                info "开始使用k8s部署服务"
		remote_command="cat $deploy_job_yml | ssh $user@$ip 'kubectl apply -f -'"
        elif [ "$cfg_build_platform" = "DOCKER_SWARM" ]
        then
                info "开始使用docker swarm部署服务"
		remote_command="cat $deploy_job_yml | ssh $user@$ip 'docker stack deploy -c - ${cfg_swarm_stack_name} --with-registry-auth'"
        else
                info "开始使用docker swarm部署服务"
		remote_command="cat $deploy_job_yml | ssh $user@$ip 'docker stack deploy -c - ${cfg_swarm_stack_name} --with-registry-auth'"
        fi
	
	remote_common_command="echo 'start prune remote images:';docker image prune -af --filter='label=maintainer=corp'"

	remote_command="$remote_command;$remote_common_command"

	expect << EOF

	spawn bash -c "$remote_command"
	expect {
	"yes/no" {send "yes\r"; exp_continue}
	"password" {send "$password\r"}
	}
	expect eof

EOF
}

function prune() {
	cfg_devops_path=${dic[cfg_devops_path]}
	cfg_temp_dir=${dic[cfg_temp_dir]}

	#删除源代码
	cd $cfg_devops_path
	rm -rf $cfg_temp_dir

	#!清除没有运行的无用镜像
	echo 'start prune local images:'
	docker image prune -af --filter="label=maintainer=corp" --filter="until=24h"
}
