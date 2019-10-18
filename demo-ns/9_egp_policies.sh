. env.sh

echo
lblue "###########################################"
lcyan "  Configure Policies"
lblue "###########################################"
echo

POLICY=$(base64 policies/cidr-check.sentinel)

vault write sys/policies/egp/cidr-check \
        policy="${POLICY}" \
        paths="kv-blog/*" \
        enforcement_level="advisory"

vault read sys/policies/egp/cidr-check

vault write sys/policies/egp/business-hrs \
        policy="$(base64 policies/business-hrs.sentinel)" \
        paths="secret/accounting/*" \
        enforcement_level="advisory"
vault read sys/policies/egp/business-hrs

#vault delete sys/policies/egp/business-hrs
#vault delete sys/policies/egp/cidr-check