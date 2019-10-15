shopt -s expand_aliases

. env.sh

echo
cyan "Testing Vault Policies"
unset PGUSER PGPASSWORD
echo
green "Login as an IT user with LDAP"
unset VAULT_TOKEN
pe "vault login -method=ldap -path=ldap-um username=deepak password=${USER_PASSWORD}"
echo
green "Test KV paths for IT"
pe "vault kv put kv-blog/it/servers/hr/root password=rootntootn"
vault kv get kv-blog/it/servers/hr/root
echo
green "ACL template path test"
pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"
vault kv get kv-blog/deepak/email

echo
green "Log in as an HR user with LDAP"
unset VAULT_TOKEN
pe "vault login -method=ldap -path=ldap-mo username=frank password=${USER_PASSWORD}"

green "ACL template path test"
pe "vault kv put kv-blog/frank/email password=doesntlooklikeanythingtome"

green "Dynamic DB credentials test"
echo
p "vault read db-blog/creds/mother-hr-full-1h"
creds=$(vault read db-blog/creds/mother-hr-full-1h)
PGUSER="$(echo $creds | xargs -n2 | grep -w username | awk '{ print $NF}')"
PGPASSWORD="$(echo $creds | xargs -n2 | grep -w password | awk '{ print $NF}')"
echo $creds | xargs -n2
#pe "vault read -format=json db-blog/creds/mother-hr-full-1h | jq -r '.data | .[\"PGUSER\"] = .username | .[\"PGPASSWORD\"] = .password | del(.username, .password) | to_entries | .[] | .key + \"=\" + .value ' > .temp_db_creds"
#pe ". .temp_db_creds && rm .temp_db_creds"
echo
green "By setting the postgres environment variables to the dynamic creds, we can now run PSQL with the dynamic creds"
yellow "export PGUSER=${PGUSER}"
yellow "export PGPASSWORD=${PGPASSWORD}"

export PGUSER=${PGUSER}
export PGPASSWORD=${PGPASSWORD}
echo
#green "Turn off globbing for the database query in an environment variable so it doesn't pick up file names instead"
set -o noglob
pe "QUERY='select email,id from hr.people;'"
pe "psql"
echo
cyan "This is the process your applications will use to encrypt data with Vault"
echo
green "Find alice's user id and encrypt it"
yellow "WARNING!   When doing this in production, it's best to schedule a maintenance window unless your application logic can consume both encrypted and unencrypted values"
echo
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
export PG_OPTIONS="-A -t"
user_id=$(psql)
echo ${user_id}
export PG_OPTIONS=""
echo
green "Encrypt the user_id"
pe "enc_id=\$(vault write -field=ciphertext transit-blog/encrypt/hr plaintext=\$( base64 <<< \${user_id} ) )"
p "echo \${enc_id}"
echo ${enc_id}
echo
green "Update the db with the encrypted id"
pe "QUERY=\"UPDATE hr.people SET id='\${enc_id}' WHERE email='alice@ourcorp.com'\""
psql

# Turn off headings and aligned output
green "Query the updated table"
pe "QUERY=\"select email,id from hr.people\""
psql

cyan "This is the process your applications will use to decrypt data with Vault"
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
export PG_OPTIONS="-A -t"
enc_user_id=$(psql)
echo "${enc_user_id}"
export PG_OPTIONS=""
echo
pe "user_id=\$(vault write -field=plaintext transit-blog/decrypt/hr ciphertext=\${enc_user_id} | base64 --decode)"
pe "echo \${user_id}"

green "Notice the value is still encrypted in the database.   It should only decrypted by your applications when needed to be displayed"
pe "QUERY=\"select email,id from hr.people\""
psql

echo
green "Negative Tests. Expect failures"

yellow "Write kv secrets to another LDAP users path"
pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"

yellow "Try to query the engineering schema from here."
pe "QUERY=\"select * from engineering.catalog\""
psql

yellow "Can the Vault token read IT kv secrets?"
#pe "vault read db-blog/creds/mother-full-read-1h"
pe "vault kv get kv-blog/it/servers/hr/root"
