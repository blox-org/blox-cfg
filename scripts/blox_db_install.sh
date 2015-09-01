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

if [ -n "$OLD_VERSION" -a -n "$NEW_VERSION" ] #Migration
then
	if [ "$OLD_VERSION" == "$NEW_VERSION" ]
	then
		BLOX_TABLES="locationpbx locationtrunk blox_config blox_profile_config  blox_codec"
		OPENSIPS_TABLES="usr_preferences acc subscriber registrant dr_gateways"
		mysqldump -u opensips --password="opensipsrw" opensips_$OLD_VERSION $BLOX_TABLES     > /etc/blox/sql/blox.migrate.sql
		mysqldump -u opensips --password="opensipsrw" opensips_$OLD_VERSION $OPENSIPS_TABLES > /etc/blox/sql/opensips.migrate.sql
		echo "INSERT INTO version VALUES ( 'locationpbx', '1009');"   >> /etc/blox/sql/blox.migrate.sql
		echo "INSERT INTO version VALUES ( 'locationtrunk', '1009');" >> /etc/blox/sql/blox.migrate.sql

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

if [ -n "$OLD_VERSION" -a -n "$NEW_VERSION" -a "$OLD_VERSION" == "$NEW_VERSION" ]
then
	CREATE_SQL="/etc/blox/sql/blox.migrate.sql /etc/blox/sql/opensips.migrate.sql"
else
	CREATE_SQL="/etc/blox/sql/create_location.sql /etc/blox/sql/create_blox_config.sql /etc/blox/sql/create_blox_codec.sql /etc/blox/sql/alter_acc.sql /etc/blox/sql/alter_usr_preferences.sql"
fi

for sql in $CREATE_SQL
do
	/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < $sql
done
