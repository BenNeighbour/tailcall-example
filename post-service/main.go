package main

import (
	"context"
	"log"
	"net"

	pb "myproject/proto/generated/post"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

type postServer struct {
	pb.UnimplementedPostServiceServer
}

// GetPosts returns a list of posts based on provided IDs
func (s *postServer) GetPosts(ctx context.Context, req *pb.GetPostsRequest) (*pb.GetPostsResponse, error) {
	// Example posts
	posts := []*pb.Post{
		{Id: 1, UserId: 1, Title: "First Post", Body: "This is the first post."},
		{Id: 2, UserId: 2, Title: "Second Post", Body: "This is the second post."},
	}

	var filteredPosts []*pb.Post

	// Create a map for quick lookup of IDs
	idMap := make(map[int32]struct{})
	for _, id := range req.Ids {
		idMap[id] = struct{}{}
	}

	// Filter posts by requested IDs
	for _, post := range posts {
		if _, exists := idMap[post.Id]; exists {
			filteredPosts = append(filteredPosts, post)
		}
	}
	
	// Now, let's construct a proto response object
	return &pb.GetPostsResponse{Items: filteredPosts}, nil
}

// registerHealthCheck sets up health check for the specified service.
func registerHealthCheck(grpcServer *grpc.Server, serviceName string) {
	healthServer := health.NewServer()
	healthServer.SetServingStatus(serviceName, grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)
}

func main() {
	lis, err := net.Listen("tcp", ":50052")
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterPostServiceServer(s, &postServer{})

	// Register health check
	registerHealthCheck(s, "PostService")

	// Enable reflection
	reflection.Register(s)

	log.Println("PostService gRPC server is running on port 50052...")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
