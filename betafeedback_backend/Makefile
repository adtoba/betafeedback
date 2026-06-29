.PHONY: run build tidy vet test db-create db-drop db-reset

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
