# couchbeam developer tasks.

COUCHDB_URL  ?= http://127.0.0.1:5984
COUCHDB_USER ?= admin
COUCHDB_PASS ?= admin
COMPOSE      ?= docker compose

export COUCHDB_URL COUCHDB_USER COUCHDB_PASS

.PHONY: all compile eunit xref dialyzer test e2e e2e-up e2e-run e2e-down clean

all: compile

compile:
	rebar3 compile

eunit:
	rebar3 eunit

xref:
	rebar3 xref

dialyzer:
	rebar3 dialyzer

test: eunit xref

## Run the end-to-end suite against a throwaway CouchDB (start, run, stop).
e2e: e2e-up
	@./support/run-e2e.sh; status=$$?; $(COMPOSE) down -v; exit $$status

## Start CouchDB and create the system databases.
e2e-up:
	$(COMPOSE) up -d
	@echo "Waiting for CouchDB at $(COUCHDB_URL)..."
	@for i in $$(seq 1 60); do \
	  curl -sf $(COUCHDB_URL)/_up >/dev/null 2>&1 && break; \
	  sleep 1; \
	done
	@for db in _users _replicator _global_changes; do \
	  curl -s -u $(COUCHDB_USER):$(COUCHDB_PASS) -X PUT $(COUCHDB_URL)/$$db >/dev/null || true; \
	done
	@echo "CouchDB ready at $(COUCHDB_URL)"

## Run the e2e suite against an already-running CouchDB.
e2e-run:
	./support/run-e2e.sh

## Stop and remove the CouchDB container and its data.
e2e-down:
	$(COMPOSE) down -v

clean:
	rebar3 clean
