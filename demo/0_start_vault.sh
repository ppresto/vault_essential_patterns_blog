#!/bin/bash

. env.sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
IP_ADDRESS=$(ipconfig getifaddr en0)

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "###########################################"
lcyan "  Setup Vault Environment"
lblue "###########################################"
echo

./1_launch_db.sh
./2_launch_ldap.sh

echo
p "docker run vault server -dev"
docker run -d --rm -p 8200:8200 --name vaultdev \
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=notsosecure' \
    -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
    -e 'VAULT_ADMIN_USER=vault_admin' \
    -e 'VAULT_ADMIN_PW=notsosecure' \
    vault
sleep 2

export VAULT_TOKEN=notsosecure
export VAULT_ADDR="http://${IP_ADDRESS}:8200"
vault status
open "http://${IP_ADDRESS}:8200"

echo
cyan "Enable Vault Audit Logging"
pe "vault audit enable file file_path=/vault/logs/vault_audit.log"

echo
cyan "Tail Vault Audit Log"
${DIR}/launch_iterm.sh $HOME "docker exec vaultdev tail -f /vault/logs/vault_audit.log | jq" &

echo
lblue "###########################################"
lcyan "  Configure Vault Services"
cyan  "    * LDAP Provider"
cyan  "    * K/V Engine"
cyan  "    * Transit (Encryption as a Service)"
cyan  "    * DB Engine (Dynamic Secrets)"
lblue "###########################################"
echo
p

echo
lblue "###########################################"
lcyan "  Enable LDAP Identity Provider"
lblue "###########################################"
echo
./6_enable_ldap_auth.sh

echo
lblue "###########################################"
lcyan "  Enable KV Secrets Engine"
lblue "###########################################"
echo
./3_enable_kv.sh
./3_kv_policy.sh
./7_generate_dynamic_policy.sh

# associate policies
echo
cyan "Associate policies to members of the IT group"
pe "vault write auth/ldap-um/groups/it policies=kv-it,kv-user-template"

echo
lblue "###########################################"
lcyan "  Enable Transit Secrets Engine"
lblue "###########################################"
echo
./5_enable_transit.sh
./5_transit_policy.sh

echo
lblue "###########################################"
lcyan "  Enable Dynamic DB Secrets Engine"
lblue "###########################################"
echo
./4_enable_db.sh
./4_db_policy.sh

echo
cyan "Associate policies to members of the HR group"
pe "vault write auth/ldap-um/groups/hr policies=db-hr,transit-hr,kv-user-template"
vault write auth/ldap-mo/groups/hr policies=db-hr,transit-hr,kv-user-template
echo
cyan "Associate policies to members of the Security group"
vault write auth/ldap-um/groups/security policies=db-full-read,kv-user-template
echo
cyan "Associate policies to members of the Engineering group"
vault write auth/ldap-mo/groups/engineering policies=db-engineering,kv-user-template

echo
lblue "###########################################"
lcyan "  Test hr"
lblue "###########################################"
echo
./test_hr.sh

echo
cyan "Clean Up"
pe "./shutdown.sh"