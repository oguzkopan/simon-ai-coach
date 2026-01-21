package sse

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// Init initializes SSE headers and returns a flusher
func Init(w http.ResponseWriter) (http.Flusher, bool) {
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no") // Disable nginx buffering

	flusher, ok := w.(http.Flusher)
	return flusher, ok
}

// Data sends a data event
func Data(w http.ResponseWriter, v interface{}) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(w, "data: %s\n\n", string(b))
	return err
}

// Event sends a named event
func Event(w http.ResponseWriter, event string, v interface{}) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, string(b))
	return err
}

// EventWithID sends a named event with an ID
func EventWithID(w http.ResponseWriter, id string, event string, v interface{}) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(w, "id: %s\nevent: %s\ndata: %s\n\n", id, event, string(b))
	return err
}

// KeepAlive sends a keep-alive comment
func KeepAlive(w http.ResponseWriter) error {
	_, err := fmt.Fprintf(w, ": keep-alive\n\n")
	return err
}
