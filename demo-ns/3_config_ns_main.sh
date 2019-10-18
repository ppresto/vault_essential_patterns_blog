. env.sh

echo
lblue "###########################################"
lcyan "  Configure Root Namespace to Manage Auth"
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
lblue "#############################################"
lcyan "  Configure a new Namespace for the IT Team"
lblue "#############################################"
echo

vault namespace create IT
vault secrets enable -namespace=IT -path=kv-blog -version=2 kv
vault policy write -namespace=IT kv-blog policies/kv-blog-it-policy.hcl
vault policy write -namespace=IT it-admin policies/it-admin.hcl
vault policy write -namespace=IT it-admin2 policies/it-admin2.hcl

echo
# "Create Ext/Int Group for IT"
cyan "Map IT namespace policies to members of the 'it' LDAP group"
# Create an Ext Group in the Root NS for each ldap group you want to map policies too.
accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
it_groupid=$(vault write -format=json identity/group name="egroup_it" type="external" | jq -r ".data.id")
# Alias Name must match LDAP group name exactly
vault write -format=json identity/group-alias name="it" mount_accessor=$accessor canonical_id=$it_groupid
#echo
#cyan "Create Internal Group with member (egroup_it)"
# Create an Internal group in the namespace (ns-it) that has the external group as a member.
vault write -namespace=IT identity/group name="igroup_it" policies="kv-blog,it-admin,it-admin2" member_group_ids=$it_groupid

# "Create Ext/Int Group for IT/hr"
#accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
hr_groupid=$(vault write -format=json identity/group name="egroup_hr" type="external" | jq -r ".data.id")
pe "vault write -format=json identity/group-alias name="hr" mount_accessor=$accessor canonical_id=$hr_groupid"

echo
lblue "################################################"
lcyan "  Configure sub-namespace IT/hr for hr app team"
lblue "################################################"
echo
cyan "Deepak from IT will setup a new namespace for the hr app team"
unset VAULT_TOKEN
vault login -method=ldap -path=ldap username=deepak password=thispasswordsucks

#export VAULT_NAMESPACE=IT
vault namespace create -namespace=IT hr
pe "vault secrets enable -namespace=IT/hr -path=kv-blog -version=2 kv"
vault policy write -namespace=IT/hr kv-blog policies/kv-blog-hr-policy.hcl
pe "vault policy write -namespace=IT/hr it-hr-admin policies/it-hr-admin.hcl"


# "Create Ext/Int Group for IT/hr"
#accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
#hr_groupid=$(vault write -format=json identity/group name="egroup_hr" type="external" | jq -r ".data.id")
#pe "vault write -format=json identity/group-alias name="hr" mount_accessor=$accessor canonical_id=$hr_groupid"
#pe "vault write -namespace=IT/hr identity/group name="igroup_hr" policies="it-hr-admin,kv-user-template" member_group_ids=$hr_groupid"

# Give IT team ability to manage groups in IT/hr
#vault write -namespace=IT/hr identity/group name="igroup_it-hr" policies="it-admin" member_group_ids=$it_groupid

export VAULT_NAMESPACE="IT/hr"
./5_enable_transit.sh
./5_transit_policy.sh
./4_enable_db.sh
./4_db_policy.sh
unset VAULT_NAMESPACE

# hr_groupid=$(vault read -format=json /identity/group/name/egroup_hr | jq -r ".data.id")
pe "vault write -namespace=IT/hr identity/group name="igroup_hr" policies="it-hr-admin,db-hr,transit-hr,kv-user-template" member_group_ids=$hr_groupid"
