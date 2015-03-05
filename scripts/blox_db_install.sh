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

MIGRATE=$1
OLD_VERSION=$2
NEW_VERSION=$3

if [ "$1" == "migrate" ]
then
yes | PW=cemsbc /usr/local/sbin/opensipsdbctl migrate opensips_$OLD_VERSION opensips_$NEW_VERSION
else
NEW_VERSION=1_11
yes | PW=cemsbc /usr/local/sbin/opensipsdbctl create opensips_$NEW_VERSION
fi

/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < /etc/blox/sql/create_location.sql
/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < /etc/blox/sql/create_blox_config.sql
/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < /etc/blox/sql/alter_acc.sql
/usr/bin/mysql -u opensips opensips_$NEW_VERSION --password="opensipsrw" < /etc/blox/sql/alter_usr_preferences.sql
