#!/bin/bash

. env.sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! $( ps -ef | grep "vault server" | grep -v grep) ]]; then
  echo "Start vault server in a new window first"
  echo "ex: ./0_start_vault.sh"
  exit
fi

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "###########################################"
lcyan "  Setup Vault Environment"
lcyan "  Configure Vault Services"
cyan  "    * LDAP Provider"
cyan  "    * K/V Engine"
cyan  "    * Transit (Encryption as a Service)"
cyan  "    * DB Engine (Dynamic Secrets)"
lcyan "  Demo Vault Services"
lblue "###########################################"
echo
p

export VAULT_TOKEN=notsosecure
export VAULT_ADDR="http://${IP_ADDRESS}:8200"
echo
yellow "export VAULT_TOKEN=notsosecure"
yellow "export VAULT_ADDR=\"http://${IP_ADDRESS}:8200\""

vault status
open "http://${IP_ADDRESS}:8200"

echo
vault read sys/license

echo
cyan "Apply New License"
vault_key=$(cat /Users/patrickpresto/Projects/binaries/vault/*.hclic)
p "vault write sys/license text=\$(cat vault_license.hclic)"
vault write sys/license text=${vault_key}
vault read sys/license

echo
cyan "Enable Vault Audit Logging"
pe "vault audit enable file file_path=/tmp/vault_audit.log"

echo
cyan "Tail Vault Audit Log"
${DIR}/launch_iterm.sh /tmp "tail -f /tmp/vault_audit.log | jq " &
echo

echo
lblue "###########################################"
lcyan "  Configure Root Namespace"
lblue "###########################################"
echo
green "Enable LDAP Auth Method"
./6_enable_ldap_auth.sh

echo
green "Enable KV Secrets for all Users"
pe "vault secrets enable -path=${KV_PATH} -version=${KV_VERSION} kv"
./7_generate_dynamic_policy.sh

# associate policies
echo
cyan "Associate policies to members of the IT group"
#pe "vault write auth/ldap/groups/it policies=kv-it,kv-user-template"
pe "vault write auth/ldap/groups/it policies=kv-user-template"
vault write auth/ldap/groups/hr policies=kv-user-template
echo
lblue "###########################################"
lcyan "  Configure IT Namespaces"
lblue "###########################################"
echo
#vault namespace create -namespace=ns-it hr
#vault policy write -namespace=ns-it/hr it-hr-admin policies/it-hr-admin.hcl

vault namespace create IT
vault namespace create -namespace=IT hr
vault secrets enable -namespace=IT -path=kv-blog -version=2 kv
vault secrets enable -namespace=IT/hr -path=kv-blog -version=2 kv

vault policy write -namespace=IT kv-blog policies/kv-blog-it-policy.hcl
vault policy write -namespace=IT/hr kv-blog policies/kv-blog-hr-policy.hcl

vault policy write -namespace=IT it-admin policies/it-admin.hcl
vault policy write -namespace=IT/hr it-hr-admin policies/it-hr-admin.hcl

echo
# "Create Ext/Int Group for IT"
cyan "Create Ext Group (egroup_it)"
# Create an Ext Group in the Root NS for each ldap group you want to map policies too.
accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
it_groupid=$(vault write -format=json identity/group name="egroup_it" type="external" | jq -r ".data.id")
# Alias Name must match LDAP group name exactly
vault write -format=json identity/group-alias name="it" mount_accessor=$accessor canonical_id=$it_groupid
echo
cyan "Create Internal Group with member (egroup_it)"
# Create an Internal group in the namespace (ns-it) that has the external group as a member.
vault write -namespace=IT identity/group name="igroup_it" policies="kv-blog,it-admin" member_group_ids=$it_groupid

# "Create Ext/Int Group for HR"
hr_groupid=$(vault write -format=json identity/group name="egroup_hr" type="external" | jq -r ".data.id")
vault write -format=json identity/group-alias name="hr" mount_accessor=$accessor canonical_id=$hr_groupid
#vault write -namespace=IT/hr identity/group name="igroup_hr" policies="it-hr-admin,db-hr,transit-hr,kv-user-template" member_group_ids=$hr_groupid


# "Create Ext/Int Group for Engineering"
eng_groupid=$(vault write -format=json identity/group name="egroup_eng" type="external" | jq -r ".data.id")
vault write -format=json identity/group-alias name="engineering" mount_accessor=$accessor canonical_id=$eng_groupid
vault write identity/group name="igroup_eng" policies="db-engineering,kv-user-template" member_group_ids=$eng_groupid

# "Create Ext/Int Group for Security"
sec_groupid=$(vault write -format=json identity/group name="egroup_security" type="external" | jq -r ".data.id")
vault write -format=json identity/group-alias name="security" mount_accessor=$accessor canonical_id=$sec_groupid
vault write identity/group name="igroup_security" policies="db-full-read,kv-user-template" member_group_ids=$sec_groupid


echo
cyan "Login as deepak from it"
unset VAULT_TOKEN
vault login -method=ldap -path=ldap username=deepak password=thispasswordsucks
#vault token lookup

echo
green "Test our ACL template (kv-blog/deepak/*)"
vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome
vault kv get kv-blog/deepak/email

export VAULT_NAMESPACE="IT"
green "Test KV paths for IT"
vault kv put kv-blog/it/servers/hr/root password=rootntootn
vault kv get kv-blog/it/servers/hr/root
unset VAULT_NAMESPACE

echo
lblue "#################################"
lcyan "  Enable Transit Secrets (EaaS)"
lblue "#################################"
echo

export VAULT_TOKEN=notsosecure
export VAULT_NAMESPACE=${SUB_NAMESPACE}

./5_enable_transit.sh
./5_transit_policy.sh
echo
yellow "Note:"
green "We will associate this policy to the HR team \\
at the same time as the DB Policies we are building next..."
echo
lblue "####################################"
lcyan "  Enable Dynamic DB Secrets Engine"
lblue "####################################"
echo
./4_enable_db.sh
./4_db_policy.sh

echo
green "Associate DB policies to the proper team"
echo
# "Create Ext/Int Group for HR"
vault write -namespace=IT/hr identity/group name="igroup_hr" policies="it-hr-admin,db-hr,transit-hr,kv-user-template" member_group_ids=$hr_groupid

unset VAULT_NAMESPACE

echo
lblue "#"
lcyan "###  Testing Time"
lblue "#"
echo
./test_hr.sh

echo
cyan "Clean Up"
pe "./shutdown.sh"
kill % 1
