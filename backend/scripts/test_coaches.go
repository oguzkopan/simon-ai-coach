package main

import (
	"context"
	"encoding/json"
	"log"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"simon-backend/internal/models"
)

func main() {
	ctx := context.Background()

	// Initialize Firestore
	projectID := "simon-7a833"
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer client.Close()

	log.Println("Querying coaches...")

	// Query public coaches
	query := client.Collection("coaches").Where("visibility", "==", "public")
	iter := query.Documents(ctx)
	defer iter.Stop()

	count := 0
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Printf("Error iterating: %v", err)
			break
		}

		count++
		log.Printf("\n=== Coach %d ===", count)
		log.Printf("ID: %s", doc.Ref.ID)
		
		// Try to parse as Coach
		var coach models.Coach
		if err := doc.DataTo(&coach); err != nil {
			log.Printf("Error parsing coach: %v", err)
			// Print raw data
			data := doc.Data()
			jsonData, _ := json.MarshalIndent(data, "", "  ")
			log.Printf("Raw data: %s", string(jsonData))
		} else {
			log.Printf("Title: %s", coach.Title)
			log.Printf("Tags: %v", coach.Tags)
			log.Printf("Visibility: %s", coach.Visibility)
			
			// Try to marshal to JSON
			jsonData, err := json.Marshal(coach)
			if err != nil {
				log.Printf("Error marshaling to JSON: %v", err)
			} else {
				log.Printf("JSON: %s", string(jsonData))
			}
		}
	}

	log.Printf("\nTotal coaches found: %d", count)
}
