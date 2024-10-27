# Directories for generated Go code
PROTO_OUT=./proto
POST_SERVICE_DIR=./post-service
USER_SERVICE_DIR=./user-service

# Proto files
PROTO_FILES=$(PROTO_OUT)/post.proto $(PROTO_OUT)/user.proto

# Generate Go code from protobuf files
.PHONY: proto
proto:
	protoc --go_out=. --go-grpc_out=. $(PROTO_FILES)

# Build the services
.PHONY: build
build: build-user build-post

build-user:
	go build -o $(USER_SERVICE_DIR)/user_service $(USER_SERVICE_DIR)/main.go

build-post:
	go build -o $(POST_SERVICE_DIR)/post_service $(POST_SERVICE_DIR)/main.go

# Run the services using a shell script
.PHONY: dev
dev:
	@if [ ! -x ./dev.sh ]; then chmod +x ./dev.sh; fi; \
	./dev.sh

# Clean up built binaries
.PHONY: clean
clean:
	rm -rf $(PROTO_OUT)/*.pb.go