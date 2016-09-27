#!/bin/sh

EXEC_SQL()
{
	SQL=$1
	if [ -n "$SQL" ]
	then
		echo "Executing SQL: $SQL"
		mysql -u opensips opensips_1_11 --password=opensipsrw -e "$SQL"
	fi
}

CLEAR_USR_PREFERENCE()
{
	ATTR=$1
	INTERVAL=${2:-1}

	if [ -z "$ATTR" ]; then
		EXEC_SQL "DELETE FROM USR_PREFERENCES WHERE last_modified < NOW() - INTERVAL $INTERVAL MINUTE ;"
	else
		EXEC_SQL "DELETE FROM USR_PREFERENCES WHERE attribute = '$ATTR' and last_modified < NOW() - INTERVAL $INTERVAL MINUTE ;"
	fi
}

MAIN()
{
	mkdir -p /var/log/blox/
	CLEAR_USR_PREFERENCE "cfgparam"
}

MAIN
