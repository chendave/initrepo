// https://golang.org/pkg/net/http/#ListenAndServe

package main

import (
	"io"
	"log"
	"net/http"
)

func main() {
	// Hello world, the web server

	helloHandler := func(w http.ResponseWriter, req *http.Request) {
		io.WriteString(w, "Hello, world!\n")
	}

	log.Printf("Before the listen ...Go to https://127.0.0.1:8443/")
	http.HandleFunc("/hello", helloHandler)
	//run forever with the below statement.
	//log.Fatal(http.ListenAndServe(":8080", nil))
	//exit imediately after the go routine.
	go func() {
		log.Fatal(http.ListenAndServe(":8080", nil))
	}()
	log.Printf("Hit after the listen ...Go to https://127.0.0.1:8443/")
}
