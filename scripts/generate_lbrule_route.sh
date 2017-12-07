#!/bin/sh

#This script is to parse and generate route for sip header manipulation based on /etc/blox/siphm.conf

BLOX_LBRULE=/etc/blox/lbrules.conf
BLOX_CONFIG_DIR=/usr/local/etc/opensips
LBRULE_SWITCH_CFG=$BLOX_CONFIG_DIR/blox-lb-rule-match-switch.cfg
LBRULE_ROUTES_CFG=$BLOX_CONFIG_DIR/blox-lb-rule-match-routes.cfg

commands=(remove_hf append_hf insert_hf append_urihf append_time append_cturi append_ctparam)
max_commands_param=(2 2 2 2 0 1 1)
#MAXIMUM 2 param Support for condition
condition=(eq ne is_present_hf is_not_present_hf is_method is_not_method has_body has_no_body)
max_condition_param=(2 2 1 1 1 1 1 1)
START_ROUTE_ID=700

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
		echo "append_hf(\"$1\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "append_hf(\"$1\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_hf $# $*"
}

insert_hf()
{
	if [ $#	-eq 2 ]; then
		echo "insert_hf(\"$1\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "insert_hf(\"$1\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for insert_hf $# $*"
}

append_urihf()
{
	if [ $#	-eq 2 ]; then
		echo "append_urihf(\"$1\", \"$2\");" ; return ;
	elif [ $# -eq 1 ]; then
		echo "append_urihf(\"$1\");" ; return ;
	fi
	LOG_ERR "Invalid Argument for append_urihf $# $*"
}

append_time()
{
	if [ $#	-eq 0 ]; then
		echo "append_time();" ; return ;
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

export MAX_LBRULE_PROFILES=20

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
exec 1>$LBRULE_ROUTES_CFG #Default STDOUT to create routes
exec 5>$LBRULE_SWITCH_CFG #Descriptor 5 to create switch case statements

echo "\$var(lbrule) = \$(param(1){s.int}) + $START_ROUTE_ID;" >&5
echo "switch(\$var(lbrule)) {" >&5
CURRENT_ROUTE_ID=0
IFS="
"
for line in $(sort -t '|' -n --key=1,2 $BLOX_LBRULE)
do
	if [ -n "$line" -a -z "$(echo $line|grep "^[	| ]*#")" ] #Ignore Matching ^#
	then
		id=$(echo $line|awk -F '|' '{print $1}')
		if [ $id -gt $MAX_LBRULE_PROFILES ]
		then
			LOG_ERR "MAX_LBRULE_PROFILES reached $MAX_LBRULE_PROFILES"
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

		cnd=$(echo $line|awk -F '|' '{print $3}')
		if [ -n "$cnd" ] ; then
			AddCondition $line
			echo '{'
		fi

		if [ -n "$cnd" ] ; then
			echo '} else { return; }'
		fi
	fi
done
if [ $CURRENT_ROUTE_ID != 0 ] ; then #CLOSE THE PREVIOUS ROUTE
	echo "\$var(match)=yes;"
	echo "}"
fi

echo "default:" >&5
echo "xlog(\"L_ERR\",\"BLOX_DBG::: No route \$var(lbrule) for Load Balancing\n\");" >&5
echo "}" >&5

exec 5<&- #Close the descriptor

if [ $CURRENT_ROUTE_ID == 0 ] ; then #empty switch case
	echo -n > $LBRULE_SWITCH_CFG
fi

exit 0
