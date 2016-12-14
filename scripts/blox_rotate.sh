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

DUMP_TABLE()
{
	TABLE=$1
	if [ -n "$TABLE" ]
	then
		#echo "Dumping $TABLE"
		mysqldump -u opensips opensips_1_11 --password=opensipsrw $TABLE
	fi
}

BLOX_CDR_RORATE()
{
	mkdir -p /var/log/blox/acc

	if [ -z "$ACC_MAX_COUNT" ]
	then
		echo "Set Enviromnet ACC_MAX_COUNT"
		exit 1
	fi
	
	COUNT=$(EXEC_SQL "SELECT count(*) FROM acc" | tail -1)
	TIMESTAMP=$(date +%s)
	
	#Will allow double size to reside in acc do not to strip down below ACC_MAX_COUNT
	while [ $COUNT -gt $((ACC_MAX_COUNT+ACC_MAX_COUNT)) ]
	do
		DUMP_LOG_FILE=/var/log/blox/acc/acc.$TIMESTAMP.$RANDOM
		DUMP_TABLE acc2 > $DUMP_LOG_FILE
		EXEC_SQL "DROP TABLE acc2"
		CURRENT_ID=$(EXEC_SQL "SELECT id FROM acc LIMIT 1" | tail -1)
		EXEC_SQL "CREATE TABLE acc2 AS (SELECT  * FROM acc WHERE id < ($CURRENT_ID+$ACC_MAX_COUNT))"
		EXEC_SQL "DELETE FROM acc WHERE id < ($CURRENT_ID+$ACC_MAX_COUNT)"
		echo "CREATING $DUMP_LOG_FILE"
		COUNT=$(EXEC_SQL "SELECT count(*) FROM acc" | tail -1)
		COUNT2=$(EXEC_SQL "SELECT count(*) FROM acc2" | tail -1)
		echo "acc:$COUNT <===>  acc2:$COUNT2"
	done
	
	ls /var/log/blox/acc -1t | sed -n '11,$p' |
	while read old_file
	do
		echo Removing last old file $old_file
		rm -f /var/log/blox/acc/$old_file
	done
}

MAIN()
{
	mkdir -p /var/log/blox/
	BLOX_CDR_RORATE
}

MAIN
