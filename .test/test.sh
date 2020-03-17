source ./config.conf
test_name=console-dev

b_group=${test_name%%-*}
echo $b_group

echo "$BUILD_ENABEL_TEMPLATE"
module_name=console-zuul
if [[ $module_name =~ zuul$ ]];
then
   echo 'yes'
else
   echo 'no'
fi


enable_templates=$BUILD_ENABEL_TEMPLATE
templates=(${enable_templates//,/ })

echo xxx:$templates
is_has_enabel_template=false
echo $is_has_enabel_template
module_name=console-zuul
for template in ${templates[@]}
do
echo ccc$template
if [[ $module_name == $template ]]
then
   echo 'find it'
   is_has_enabel_template=true
   echo	$is_has_enabel_template
fi
done
echo $is_has_enabel_template
if [ "$is_has_enabel_template" = false ]
then
   echo 'find nothing'
fi

