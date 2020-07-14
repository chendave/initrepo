// important notes:
// 1. the "checkNode" is run in parallel, number larger than 5 has the chance to be called.
// 2. code after the cancel() is also got executed.
// 3. the code cannot guarantee the business run only 5 times but minimize the cost (>=5 hit).

// expected result looks like:
//
//i is: 0
//i is: 1
//i is: 2
//i is: 7
//i is: 21
//cancel got called!
//after the cancel
//i is: 3
//i is: 14
//cancel got called!
//after the cancel
//cancel got called!
//after the cancel


//patch
```patch
diff --git a/context.go b/context.go.bak
index b08fbbe..b561968 100644
--- a/context.go
+++ b/context.go.bak
@@ -49,7 +49,6 @@ package context

 import (
        "errors"
-       "fmt"
        "internal/reflectlite"
        "sync"
        "sync/atomic"
@@ -233,10 +232,7 @@ type CancelFunc func()
 func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
        c := newCancelCtx(parent)
        propagateCancel(parent, &c)
-       return &c, func() {
-               fmt.Println("cancel got called!")
-               c.cancel(true, Canceled)
-       }
+       return &c, func() { c.cancel(true, Canceled) }
 }
```


package main

import (
	"context"
	"fmt"

	"k8s.io/kubernetes/pkg/scheduler/internal/parallelize"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	allNodes := 100
	checkNode := func(i int) {
		fmt.Printf("i is: %v\n", i)
		//business: do someting here.
		if i >= 5 {
			cancel()
			fmt.Println("after the cancel")
		}
	}
	parallelize.Until(ctx, allNodes, checkNode)
}
