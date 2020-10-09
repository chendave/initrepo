package main

import (
	"fmt"
	"time"

	"k8s.io/apimachinery/pkg/util/wait"
)

//expected to see:
//before the sleep
//after the sleep
//value of a is:  2
//before the sleep
//after the sleep
//value of a is:  2
//before the sleep
//after the sleep
//value of a is:  2
//we have a error here: %v timed out waiting for the condition
func podSleep() (bool, error) {
	fmt.Println("before the sleep")
	time.Sleep(5 * time.Second)
	fmt.Println("after the sleep")
	a := 2
	fmt.Println("value of a is: ", a)
	return false, nil
}

func main() {
	if err := wait.Poll(time.Second, time.Second*10, podSleep); err != nil {
		fmt.Println("we have a error here: %v", err)
	}
}
