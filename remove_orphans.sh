#!/bin/sh
# Usage: ./remove_orphans.sh [-f]
# Remove orphans from the dlna mediaserver on synology
# inspired from http://wacha.ch/wiki/synology
#
# Copyright 2016 Kevin Lagaisse
# 
# Licensed under the Creative Commons BY-NC-SA 4.0 licence (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://creativecommons.org/licenses/by-nc-sa/4.0/
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

test "$1" = "-f" && REMOVE=1


getOrphansCandidates() {
    local db="$1"
    /usr/syno/pgsql/bin/psql mediaserver admin -tA -c "select path from ${db};"
}

for db in music video photo directory
do
    getOrphansCandidates ${db} | while read testfile
    do
        if test ! -e "${testfile}"
            then
                echo "MISSING: ${testfile}"
                if test -n "$REMOVE" 
                then
                    if test "${db}" = "directory"
                    then
                        echo " removing directory"
                        synoindex -D "$testfile"
                    else
                        echo " removing file"
                        synoindex -d "$testfile"
                    fi
                fi
        fi
    done
done

exit 0