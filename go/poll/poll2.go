package main

import (
	"errors"
	"fmt"
	"time"

	"k8s.io/apimachinery/pkg/util/wait"
)

//expected to see:
//we have a error here: %v emit macho dwarf: elf header corrupted
func podSleep() (bool, error) {
	err := errors.New("emit macho dwarf: elf header corrupted")
	return true, err
}

func main() {
	if err := wait.Poll(time.Second, time.Second*10, podSleep); err != nil {
		fmt.Println("we have a error here: %v", err)
	}
}
