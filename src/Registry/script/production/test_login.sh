#!/bin/bash
# Copyright [2015-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


source ${HOME}/perl5/perlbrew/etc/bashrc
cd ${HOME}/src/trackhub-registry/src/Registry/script/production
user=$1
pass=$2
date=`date`
perl test_login.pl $user $pass || {
    printf '%s - Logging does not work. Restarting server...\n' "$date" >> logs/test_loging.log
    # stop_server.sh
    # start_server.sh
    # exit 1
}
