.PHONY: run build tidy vet test db-create db-drop db-reset redeploy deploy

run:
	go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

tidy:
	go mod tidy

vet:
	go vet ./...

test:
	go test ./...

db-create:
	createdb betafeedback || true

db-drop:
	dropdb betafeedback || true

db-reset: db-drop db-create

# Pull, rebuild, and restart the production systemd unit (run on the VPS).
redeploy:
	./scripts/redeploy.sh

# From your Mac: push, SSH to the VPS, pull/rebuild/restart (needs .deploy.env).
deploy:
	./scripts/deploy.sh
