#!/usr/bin/env bash

#This script is to parse and generate route for sip header manipulation based on /etc/blox/siphm.conf

BLOX_SIPHM=/etc/blox/siphm.conf
BLOX_CONFIG_DIR=/usr/local/etc/opensips
SIPHM_SWITCH_CFG=$BLOX_CONFIG_DIR/blox-sip-header-manipulation-switch.cfg
SIPHM_ROUTES_CFG=$BLOX_CONFIG_DIR/blox-sip-header-manipulation-routes.cfg
SIPHM_ROUTES_ACTION_CFG=$BLOX_CONFIG_DIR/blox-sip-header-manipulation-routes-action.cfg

commands=(remove_hf append_hf insert_hf append_urihf append_time append_cturi append_ctparam)
max_commands_param=(2 2 2 2 0 1 1)
#MAXIMUM 2 param Support for condition
condition=(eq ne is_present_hf is_not_present_hf is_method is_not_method has_body has_no_body)
max_condition_param=(2 2 1 1 1 1 1 1)
START_ROUTE_ID=500
START_ROUTE_ACTION_ID=600

LOG_ERR()
{
	echo $* > /dev/stderr
}

remove_hf()
{
	if [ $#	-eq 2 ]; then
		echo "remove_hf(\"$1\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "remove_hf(\"$1\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for remove_hf $# $*"
}

append_hf()
{
	if [ $#	-eq 2 ]; then
		echo "append_hf(\"$1\\r\\n\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "append_hf(\"$1\\r\\n\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_hf $# $*"
}

insert_hf()
{
	if [ $#	-eq 2 ]; then
		echo "insert_hf(\"$1\\r\\n\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "insert_hf(\"$1\\r\\n\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for insert_hf $# $*"
}

append_urihf()
{
	if [ $#	-eq 2 ]; then
		echo "append_urihf(\"$1\", \"$2\\r\\n\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "append_urihf(\"$1\", \"\\r\\n\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_urihf $# $*"
}

append_time()
{
	if [ $#	-eq 0 ]; then
		echo "append_hf(\"Time: \$Tf\\r\\n\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_time $# $*"
}

append_cturi()
{
	if [ $# -eq 1 ]; then
		echo "$dlg_val(th_cthdr) = '$1';" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_cturi $# $*"
}

eq()
{
	if [ $# -eq 2 ]; then
		echo "if(pcre_match(\"$1\",\"$2\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for eq $# $*"
}

ne()
{
	if [ $# -eq 2 ]; then
		echo "if(!pcre_match(\"$1\",\"$2\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for ne $# $*"
}

is_method()
{
	if [ $# -eq 1 ]; then
		echo "if(is_method(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for is_method $# $*"
}

is_not_method()
{
	if [ $# -eq 1 ]; then
		echo "if(!is_method(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for is_not_method $# $*"
}

has_body()
{
	if [ $# -eq 0 ]; then
		echo "if(has_body())" ; return ;
	elif [ $# -eq 1 ]; then
		echo "if(has_body(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for has_body $# $*"
}

has_no_body()
{
	if [ $# -eq 0 ]; then
		echo "if(!has_body())" ; return ;
	elif [ $# -eq 1 ]; then
		echo "if(!has_body(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for has_no_body $# $*"
}

is_present_hf()
{
	if [ $# -eq 1 ]; then
		echo "if(is_present_hf(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for is_present_hf $# $*"
}

is_not_present_hf()
{
	if [ $# -eq 1]; then
		echo "if(is_not_present_hf(\"$1\"))" ; return ;
	fi
	LOG_ERR "Invalid Argument for is_not_present_hf $# $*"
}

export MAX_SIPHM_PROFILES=20

GetCommandIndex()
{
	if [ $# -eq 1 ]; then
		for idx in $(seq 0 ${#commands[@]})
		do
			if [ "$1" == "${commands[$idx]}" ] ; then
				echo $idx ;  return ;
			fi
		done
	fi
	LOG_ERR "Invalid Argument for GetCommandIndex $# $*"
}

GetConditionIndex()
{
	if [ $# -eq 1 ]; then
		for idx in $(seq 0 ${#condition[@]})
		do
			if [ "$1" == "${condition[$idx]}" ] ; then
				echo $idx ;  return ;
			fi
		done
	fi
	LOG_ERR "Invalid Argument for GetConditionIndex $# $*"
}

AddCondition()
{
	line=$1
	cnd=$(echo $line|awk -F '|' '{print $3}')
	cndidx=$(GetConditionIndex $cnd)
	if [ -z "$cndidx" ] ;then  #Command index not found
		LOG_ERR "No condition called $cnd"
		break;
	fi
	maxcndparam=${max_condition_param[$cndidx]}
	i=1
	unset param
	while [ $i -le $maxcndparam ]
	do
		evalparam="param[$((i-1))]=\$(echo \$line|awk -F '|' '{print \$$((i+3))}')"
		eval $evalparam
		i=$((i+1))
	done
	$cnd ${param[@]}
}

AddCommand()
{
	line=$1
	cmd=$(echo $line|awk -F '|' '{print $6}')
	cmdidx=$(GetCommandIndex $cmd)
	if [ -z "$cmdidx" ] ;then  #Command index not found
		LOG_ERR "No commands called $cmd"
		break;
	fi
	maxcmdparam=${max_commands_param[$cmdidx]}
	i=1
	unset param
	while [ $i -le $maxcmdparam ]
	do
		evalparam="param[$((i-1))]=\$(echo \$line|awk -F '|' '{print \$$((i+6))}')"
		eval $evalparam
		i=$((i+1))
	done
	$cmd ${param[@]}
}


#MAIN
>$SIPHM_ROUTES_CFG
>$SIPHM_SWITCH_CFG
>$SIPHM_ROUTES_ACTION_CFG
exec 1>$SIPHM_ROUTES_CFG #Default STDOUT to create routes
exec 5>$SIPHM_SWITCH_CFG #Descriptor 5 to create switch case statements
exec 6>$SIPHM_ROUTES_ACTION_CFG #Default 6 to create action routes

if [ $(wc -l $BLOX_SIPHM | awk '{print $1}') -gt 0 ]; then
	echo "switch(\$(var(siphmr){s.int})) {" >&5
	CURRENT_ROUTE_ID=0
	IFS="
	"
	for line in $(sort -t '|' -n --key=1,2 $BLOX_SIPHM)
	do
		if [ -n "$line" -a -z "$(echo $line|grep "^[	| ]*#")" ] #Ignore Matching ^#
		then
			id=$(echo $line|awk -F '|' '{print $1}')
			if [ $id -gt $MAX_SIPHM_PROFILES ]
			then
				LOG_ERR "MAX_SIPHM_PROFILES reached $MAX_SIPHM_PROFILES"
				break
			fi
			if [ $CURRENT_ROUTE_ID != $id ] ; then #START THE NEW ROUTE
				if [ $CURRENT_ROUTE_ID != 0 ] ; then #CLOSE THE PREVIOUS ROUTE
					echo "}"
				fi
				echo "route[$((START_ROUTE_ID+id))] {"
				echo "case $((START_ROUTE_ID+id)):" >&5
				echo "route($((START_ROUTE_ID+id)));" >&5
				echo "break;" >&5
				CURRENT_ROUTE_ID=$id ;
			fi
	
			START_ROUTE_ACTION_ID=$((START_ROUTE_ACTION_ID+1))
			echo "case $((START_ROUTE_ACTION_ID)):" >&5
			echo "route($((START_ROUTE_ACTION_ID)));" >&5
			echo "break;" >&5
	
	
			cnd=$(echo $line|awk -F '|' '{print $3}')
			if [ -n "$cnd" ] ; then
				AddCondition $line
				echo '{'
			fi
cat <<EOACTRT
	    if(\$var(SHMPACT)) {
	        \$var(SHMPACT) = \$var(SHMPACT) + "$((START_ROUTE_ACTION_ID)):" ;
	    } else {
	        \$var(SHMPACT) = "$((START_ROUTE_ACTION_ID)):" ;
	    }
EOACTRT
	
			echo "route[$((START_ROUTE_ACTION_ID))] {" >&6
			cmd=$(echo $line|awk -F '|' '{print $6}')
			if [ -n "$cmd" ]; then
				AddCommand $line >&6
			fi
			echo '}' >&6
	
			if [ -n "$cnd" ] ; then
				echo '}'
			fi
		fi
	done
	if [ $CURRENT_ROUTE_ID != 0 ] ; then #CLOSE THE PREVIOUS ROUTE
		echo "}"
	fi
	
	echo "default:" >&5
	echo "xlog(\"L_ERR\",\"No route \$var(siphmr) for SIP Header Manipulation\n\");" >&5
	echo "}" >&5
fi

exit 0
