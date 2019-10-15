. env.sh

echo
cyan "Enabling database engine"
pe "vault secrets enable -path=${DB_PATH} database"

green "Configure the account that Vault will use to manage credentials in Postgres."
p "vault write ${DB_PATH}/config/${PGDATABASE} \\
    plugin_name=postgresql-database-plugin \\
    allowed_roles=* \\
    connection_url=\"postgresql://{{username}}:{{password}}@${IP_ADDRESS}:${PGPORT}/${PGDATABASE}?sslmode=disable\" \\
    username=\"${VAULT_ADMIN_USER}\" \\
    password=\"${VAULT_ADMIN_PW}\""

vault write ${DB_PATH}/config/${PGDATABASE} \
    plugin_name=postgresql-database-plugin \
    allowed_roles=* \
    connection_url="postgresql://{{username}}:{{password}}@${IP_ADDRESS}:${PGPORT}/${PGDATABASE}?sslmode=disable" \
    username="${VAULT_ADMIN_USER}" \
    password="${VAULT_ADMIN_PW}"

green "Rotate the credentials for ${VAULT_ADMIN_USER} so no human has access to them anymore"
pe "vault write -force ${DB_PATH}/rotate-root/${PGDATABASE}"

green "Configure the database roles for the different teams"
echo

# Just set this here as all will likely use the same one
MAX_TTL=24h

echo
cyan "db-blog/roles/${PGDATABASE}-hr-full-1h"
green "hr-full : The hr team will be granted full access to their schema"
ROLE_NAME="hr-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; 
GRANT USAGE ON SCHEMA hr TO \"{{name}}\"; 
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr TO \"{{name}}\";"
TTL=1h
write_db_role_debug
TTL=1m
write_db_role

echo
cyan "db-blog/roles/${PGDATABASE}-full-read-1h"
green "full-read : security teams can use this to scan for credentials in any schema"
ROLE_NAME="full-read"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
  GRANT USAGE ON SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\"; 
  GRANT SELECT ON ALL TABLES IN SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\";"
TTL=1h
write_db_role
TTL=1m
write_db_role

echo
cyan "db-blog/roles/${PGDATABASE}-engineering-full-1h"
green "engineering-full : The Eng team will be granted full access to their schema"
ROLE_NAME="engineering-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; 
GRANT USAGE ON SCHEMA engineering TO \"{{name}}\"; 
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA engineering TO \"{{name}}\";"
TTL=1h
write_db_role
TTL=1m
write_db_role
