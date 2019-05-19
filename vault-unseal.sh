#!/bin/bash
#
# Copyright 2019 Jonathan T. Moore
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export VAULT_ADDR=http://127.0.0.1:8200
if [ -f /etc/vault.d/init.log ]; then
    /usr/local/bin/vault operator unseal `cat /etc/vault.d/init.log | awk '/Unseal Key 1/ { print $4}'`
    /usr/local/bin/vault operator unseal `cat /etc/vault.d/init.log | awk '/Unseal Key 2/ { print $4}'`
    /usr/local/bin/vault operator unseal `cat /etc/vault.d/init.log | awk '/Unseal Key 3/ { print $4}'`
fi
