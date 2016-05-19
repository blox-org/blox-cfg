#!/bin/sh

# Blox is an Opensource Session Border Controller
# Copyright (c) 2015-2018 "Blox" [http://www.blox.org]
#
# This file is part of Blox.
#
# Blox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>

/usr/bin/mysqladmin -u root password "cemsbc"

OLD_VERSION=$1
NEW_VERSION=$2

BLOX_TABLES="locationpbx locationtrunk locationpresence blox_config blox_domain\
		blox_config_ext blox_profile_config blox_param_config \
		blox_codec blox_subscribe blox_presence_subscriber \
		blox_lb blox_lb_rules"
BLOX_ALTER_TABLES="/etc/blox/sql/alter_acc.sql \
		/etc/blox/sql/alter_blox_config.sql \
		/etc/blox/sql/alter_usr_preferences.sql"

if [ -n "$OLD_VERSION" -a -n "$NEW_VERSION" ] #Migration
then
	if [ "$OLD_VERSION" = "$NEW_VERSION" ]
	then
                OPENSIPS_TABLES="acc subscriber registrant dr_gateways dr_rules dr_groups userblacklist"

		rm -f /etc/blox/sql/blox.migrate.sql /etc/blox/sql/opensips.migrate.sql
		for bt in ${BLOX_TABLES}
		do
			mysqldump -u opensips --password="opensipsrw" opensips_$OLD_VERSION $bt >> /etc/blox/sql/blox.migrate.sql
			if [ $? -eq 6 ]; then #If table not present create it
				cat /etc/blox/sql/create_${bt}.sql >> /etc/blox/sql/blox.migrate.sql
			fi
		done
		mysqldump -u opensips --password="opensipsrw" opensips_$OLD_VERSION $OPENSIPS_TABLES > /etc/blox/sql/opensips.migrate.sql

		yes | PW=cemsbc /usr/local/sbin/opensipsdbctl migrate opensips_$OLD_VERSION _opensips_$NEW_VERSION
		/usr/bin/mysql -u opensips --password="opensipsrw" -e "DROP DATABASE opensips_$OLD_VERSION"
		yes | PW=cemsbc /usr/local/sbin/opensipsdbctl migrate _opensips_$NEW_VERSION opensips_$NEW_VERSION
		/usr/bin/mysql -u opensips --password="opensipsrw" -e "DROP DATABASE _opensips_$NEW_VERSION"
	else
		yes | PW=cemsbc /usr/local/sbin/opensipsdbctl migrate opensips_$OLD_VERSION opensips_$NEW_VERSION
	fi
else
	NEW_VERSION=1_11
	yes | PW=cemsbc /usr/local/sbin/opensipsdbctl create opensips_$NEW_VERSION
fi

if [ -n "$OLD_VERSION" -a -n "$NEW_VERSION" -a "$OLD_VERSION" = "$NEW_VERSION" ]
then
	CREATE_SQL="/etc/blox/sql/blox.migrate.sql /etc/blox/sql/opensips.migrate.sql $BLOX_ALTER_TABLES"
else
	for bt in ${BLOX_TABLES}
	do
		CREATE_SQL="$CREATE_SQL /etc/blox/sql/create_${bt}.sql";
	done
	CREATE_SQL="$CREATE_SQL $BLOX_ALTER_TABLES" 
fi

for sqlFile in $CREATE_SQL
do
	echo "Executing $sqlFile" ;
	/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < $sqlFile
done

IFS="
"
for sql in $(cat /etc/blox/sql/blox_version.sql)
do
	echo "Executing $sql" ;
	/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" -e $sql
done
