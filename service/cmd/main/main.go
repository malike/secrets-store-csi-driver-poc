package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

const (
	SECRETS_LOC = "/mnt/secrets-store/password"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/home", Home)
	mux.HandleFunc("/vault", Vault)
	mux.HandleFunc("/healthz", Health)

	s := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
	}
	if err := s.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal("Server startup failed")
	}
}

func Home(w http.ResponseWriter, r *http.Request) {
	log.Println("Accessed home")
	fmt.Fprint(w, "Hello World, "+os.Getenv("VAULT_SECRET"))
}

func Vault(w http.ResponseWriter, r *http.Request) {
	log.Println("Accessed vault")
	dat, err := ioutil.ReadFile(SECRETS_LOC)
	if err != nil {
		log.Println("Failed." + err.Error())
	}
	fmt.Fprint(w, "Hello Vault, "+string(dat))
}

func Health(w http.ResponseWriter, r *http.Request) {
	log.Println("Accessed health")
	fmt.Fprint(w, "{'ping':'ok'}")
}
