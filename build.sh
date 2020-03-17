#!/bin/bash

function java() {

	scm $dic

	java_build $dic

	cp_dockerfile $dic

	java_build_image $dic

	render_template $dic

	deploy $dic

	prune $dic

}

function node() {
	dic=$1

	scm $dic

	node_build $dic

	cp_dockerfile $dic

	node_build_image $dic

	render_template $dic

	deploy $dic

	prune $dic

}

function scm() {
	dic=$1
	cfg_temp_dir=${dic[cfg_temp_dir]}
	opt_git_url=${dic[opt_git_url]}
	opt_svn_url=${dic[opt_svn_url]}

	if [-z $opt_git_url ]; then 
		#克隆代码
		git clone $git_url  $cfg_temp_dir
		#生成日期和git日志版本后六位
		date=`date +%Y-%m-%d_%H-%M-%S`
		last_log=`git log --pretty=format:%h | head -1`
		echo -e "\n关键变量值:\n last_log:$last_log\n"
		dic[tmp_docker_image_suffix]="${date}_${last_log}"
	elif [ -z $opt_svn_url ]; then 
		echo 'do svn thing'
	 	# to do
	else 
		echo "--git-url and --svn-url must has one"; exit 1;
	fi
}

function java_build() {
	dic=$1
	cfg_temp_dir=${dic[cfg_temp_dir]}
	cmd_job_name=${dic[cmd_job_name]}
	opt_build_tool=${dic[opt_build_tool]}
	case "$opt_build_tool"  in
	gradle)
		module_path=`find $cfg_temp_dir/* -type d  -name  ${cmd_job_name}`
		echo -e "\n关键变量值:\n module_path:$module_path\n"
		#构建代码
		cd $module_path && gradle -x test clean build
		dic[tmp_build_dist_path]=$module_path/build/libs
	 ;;
	maven)
	   echo 'do maven thing'
       	#to do
	 ;;
	*) echo "java project only support gradle or maven build"; exit 1; ;;
    	esac
}

function node_build() {
	dic=$1
	cfg_temp_dir=${dic[cfg_temp_dir]}
	#构建代码
	cd $cfg_temp_dir && npm install && npm run build
	dic[tmp_build_dist_path]=$cfg_temp_dir/
}

function cp_dockerfile() {
	dic=$1
	cfg_dockerfile_path=${dic[cfg_dockerfile_path]}
	cfg_enable_dockerfiles=${dic[cfg_enable_dockerfiles]}
	tmp_build_dist_path=${dic[tmp_build_dist_path]}

	dockerfiles=(${cfg_enable_dockerfiles//,/ })
	echo "关键变量:cfg_enable_dockerfiles:$cfg_enable_dockerfiles,dockerfiles:$dockerfiles"
	is_has_enable_docker_file=false
	for dockerfile in ${dockerfiles[@]} ;do
		if [[ $module_name == $dockerfile ]]
		then
		   cp $cfg_dockerfile_path/${dockerfile}-dockerfile ${tmp_build_dist_path}/dockerfile
		   is_has_enable_docker_file=true
		fi
	done
	if [ "$is_has_enable_docker_file" = false ]; then
	   cp $cfg_dockerfile_path/dockerfile ${tmp_build_dist_path}/
	fi
}


function java_build_image() {
	dic=$1
	cmd_job_name=${dic[cmd_job_name]}
	cfg_harbor_address=${dic[cfg_harbor_address]}
	cfg_harbor_project=${dic[cfg_harbor_project]}
	tmp_build_dist_path=${dic[tmp_build_dist_path]}
	tmp_docker_image_suffix=${dic[tmp_docker_image_suffix]}


	# 查找jar包名
	cd ${tmp_build_dist_path}
	jar_name=`ls | grep -v 'source'| grep ${cmd_job_name}`

	# 构建镜像
	image_path=$cfg_harbor_address/$cfg_harbor_project/${cmd_job_name}_${tmp_docker_image_suffix}:latest
	docker build --build-arg module_name=$cmd_job_name\
	       --build-arg jar_name=$jar_name\
	       --build-arg java_opts="$java_extra_opts"\
	       --tag $image_path .

	#推送镜像
	docker push $image_path
	dic[tmp_image_path]=$image_path
}

function node_build_image() {
	dic=$1
	cmd_job_name=${dic[cmd_job_name]}
	cfg_harbor_address=${dic[cfg_harbor_address]}
	cfg_harbor_project=${dic[cfg_harbor_project]}
	tmp_build_dist_path=${dic[tmp_build_dist_path]}
	tmp_docker_image_suffix=${dic[tmp_docker_image_suffix]}


	# 查找jar包名
	cd ${tmp_build_dist_path}

	# 构建镜像
	image_path=$cfg_harbor_address/$cfg_harbor_project/${cmd_job_name}_${tmp_docker_image_suffix}:latest
	docker build -t $image_path .

	#推送镜像
	docker push $image_path
	dic[tmp_image_path]=$image_path
}


function render_template() {
	dic=$1
	opt_build_env=${dic[opt_build_env]}
	cfg_devops_path=${dic[cfg_devops_path]}
	cfg_swarm_network=${dic[cfg_swarm_network]}
	cfg_template_path=${dic[cfg_template_path]}
	cfg_enable_templates=${dic[cfg_enable_templates]}
	cmd_job_name=${dic[cmd_job_name]}
	tmp_image_path=${dic[tmp_image_path]}


	gen_long_time_str=`date +%s%N`

	#取环境变量的前缀，获取主项目名称，主项目相关的deploy文件放在一下文件夹下
	main_project_name=${opt_build_env%%-*}

	#处理模板路由信息
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


	#执行替换
	sed -i "s#?module_name#${cmd_job_name}#g"  ./${gen_long_time_str}.yml
	sed -i "s#?image_path#${tmp_image_path}#g"  ./${gen_long_time_str}.yml
	sed -i "s#?network#${cfg_swarm_network}#g"  ./${gen_long_time_str}.yml

	#生成文件
	if [ ! -d "$cfg_devops_path/deploy/$main_project_name" ];then
	mkdir -p $cfg_devops_path/deploy/$main_project_name
	fi
	\mv ./${gen_long_time_str}.yml $cfg_devops_path/deploy/$main_project_name/${cmd_job_name}.yml
}

function deploy() {
	dic=$1
	cfg_build_platform=${dic[cfg_build_platform]}
	cfg_swarm_stack_name=${dic[cfg_swarm_stack_name]}
	#创建或者更新镜像
	if [ "$cfg_build_platform" = "KUBERNETES" ]
	then
	    echo "build_platform_k8s"
	    kubectl apply -f  ${current_path}/deploy/${module_name}/${module_name}.yml
	elif [ "$cfg_build_platform" = "DOCKER_SWARM" ]
	then
	    echo "build_platform_docker_swarm"
	    docker stack deploy -c ${current_path}/deploy/${main_project_name}/${module_name}.yml ${cfg_swarm_stack_name}  --with-registry-auth
	else
	    echo "build_platform_default"
	    docker stack deploy -c ${current_path}/deploy/${main_project_name}/${module_name}.yml ${cfg_swarm_stack_name} --with-registry-auth
	fi
}

function prune() {
	dic=$1
	cfg_devops_path=${dic[cfg_devops_path]}
	cfg_temp_dir=${dic[cfg_temp_dir]}

	#删除源代码
	cd $cfg_devops_path
	rm -rf $cfg_temp_dir

	#!清除没有运行的无用镜像
	docker image prune -af --filter="label=maintainer=corp"
}
