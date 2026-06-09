#!/usr/bin/env sh
#
# Run the couchbeam end-to-end suite against a real CouchDB.
#
# Each test group runs as a separate `rebar3 ct` invocation so every group
# starts from a fresh suite setup (its own database), which keeps them
# isolated. Honors:
#   COUCHDB_URL  (default http://127.0.0.1:5984)
#   COUCHDB_USER (default empty, i.e. no auth)
#   COUCHDB_PASS (default empty)
#
set -eu

COUCHDB_URL="${COUCHDB_URL:-http://127.0.0.1:5984}"
COUCHDB_USER="${COUCHDB_USER:-}"
COUCHDB_PASS="${COUCHDB_PASS:-}"
export COUCHDB_URL COUCHDB_USER COUCHDB_PASS

e2e_groups="server_ops database_ops document_ops bulk_ops attachment_ops \
        view_ops design_ops changes_ops error_handling \
        view_streaming_ops changes_streaming_ops replication_ops \
        db_management_ops mango_ops uuid_ops"

for group in $e2e_groups; do
    echo "=== e2e group: ${group} ==="
    rebar3 ct --suite=couchbeam_integration_SUITE --group="${group}" --readable=true
done

echo "All e2e groups passed"
