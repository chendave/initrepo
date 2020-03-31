// https://golang.org/pkg/net/http/#ListenAndServe

package main

import (
	"io"
	"log"
	"net/http"
	"time"
)

func main() {
	// Hello world, the web server

	helloHandler := func(w http.ResponseWriter, req *http.Request) {
		io.WriteString(w, "Hello, world!\n")
	}

	log.Printf("Before the listen ...Go to http://127.0.0.1:8181/hello")
	http.HandleFunc("/hello", helloHandler)
	//run forever with the below statement.
	//log.Fatal(http.ListenAndServe(":8181", nil))
	//exit imediately after the go routine.
	go func() {
		log.Printf("in the goroutine...Go to http://127.0.0.1:8181/hello")
		log.Fatal(http.ListenAndServe(":8181", nil))
	}()
	log.Printf("Hit after the listen ...Go to http://127.0.0.1:8181/hello")
	time.Sleep(20 * time.Second)

}
