# Timer
A timer for Swift 2.1 designed to be simple. Here's an example on how to use it:

```
let timer = Timer(initial: 0)

timer.tick(every: 1) {
  print($0)
  
  if $0 == 10 {
    timer.stop()
  }
}
```


