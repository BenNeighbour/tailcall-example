package main

import (
	"context"
	"log"
	"net"

	pb "myproject/proto/generated/user"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

type userServer struct {
	pb.UnimplementedUserServiceServer
}

// User represents a simple in-memory user storage.
var users = map[int32]*pb.User{
	1: {Id: 1, Name: "John Doe", Username: "johndoe", Email: "john@example.com"},
	2: {Id: 2, Name: "Jane Smith", Username: "janesmith", Email: "jane@example.com"},
}

// GetUsers returns a list of users based on the provided IDs.
func (s *userServer) GetUsers(ctx context.Context, req *pb.GetUsersRequest) (*pb.GetUsersResponse, error) {
	var filteredUsers []*pb.User

	// Filter users based on the requested IDs
	for _, id := range req.Ids {
		if user, exists := users[id]; exists {
			filteredUsers = append(filteredUsers, user)
		}
	}

	// Now, let's construct a proto response object
	return &pb.GetUsersResponse{Items: filteredUsers}, nil
}

// registerHealthCheck sets up health check for the specified service.
func registerHealthCheck(grpcServer *grpc.Server, serviceName string) {
	healthServer := health.NewServer()
	healthServer.SetServingStatus(serviceName, grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Create the grpc server
	s := grpc.NewServer()
	pb.RegisterUserServiceServer(s, &userServer{})

	// Register health check
	registerHealthCheck(s, "UserService")

	// Enable reflection
	reflection.Register(s)

	log.Println("UserService gRPC server is running on port 50051...")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
