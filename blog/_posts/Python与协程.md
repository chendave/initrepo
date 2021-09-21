---
title: Python与协程
date: 2018-05-26 17:36:10
tags: Python
thumbnail: /css/images/lake.jpg
---

这篇博文对Python的协程(Coroutines)做个小结，记得多年之前在学校之时，学到的是进程，线程。即便工作之后用Python开始编写代码了，也很少会用到协程。那么协程是什么？提到协程我们得先去了解一下Python生成器(generator)与迭代器(iterator)。

简单来说迭代器(iterator)是一个你可以去顺序遍历的对象，是一个可以迭代(iterable)的Python类实例化的对象，这样的类一般来说是一个Python的容器类型，常见的容器类型如list，tuple，string都是可以迭代的(iterable)，也就是说通过它们可以实例化为迭代器，有点拗口，下面这张图可以帮助理解：

![](https://github.com/chendave/chendave.github.io/raw/master/css/images/relationships.png "我的博客")

迭代器必须实现`__iter__`与`__next__`两种内置方法，迭代器的优势在于节省内存的开销，例如下面的例子：

``` python

class xrange:
    def __init__(self, max):
        self.i = 0
        self.max = max

    def __iter__(self):
        return self

    def next(self):
        if self.i < self.max:
            i = self.i
            self.i += 1
            return i
        else:
            raise StopIteration()

```
每次调用`next()`会生成一个元素，这有点类似`C`语言里的指针，这对于无需一次访问整个列表而只访问某个元素来说是非常有益的，因为*内存*的占用始终是一个常数。如果返回的是一个列表类型的话，将会将所有的结果都保存在内存中，如果max特别大的话，消耗的内存将是一个必须考虑的问题。

生成器是一个特殊的迭代器，通过引入`yield`关键字简化了迭代器的代码：

``` python

def xrange(max):
    i = 0
    while i < max:
        yield i
        i += 1

```

与上面的代码作用相同，每调用`next()`方法生成一个值直到值等于`max`为止。在某些场合下或者某些语言中，一个生成器可以理解为一个协程，但是又有细微的不同:
- 生成器一般用来产生数据
- 协程一般用来消费数据

但这是通常的使用场合的不同，实现上看不出来什么区别，也就是说如果我们需要对`yield`出来的数据做进一步的处理，则可以将其理解为协程。

协程有时和多线程可以用来实现相同的目的，那协程相对于线程来说有什么不同和优势呢？最明显的区别在于协程将控制权交由程序自己来控制，本质上就是一个线程，因为没有多线程场景下的CPU中断，也没有线程切换，自然系统的开销就要小的多，那么多核的平台上，又要并发，又要灵活的控制程序的执行，则可以将协程和多线程结合起来。下面来看一个协程的例子:

``` python
>>> def grep(pattern):
    print("Searching for", pattern)
    while True:
        line = (yield)  # 2
        if pattern in line:
            print(line)

            
>>> search = grep("hello")  # 0
>>> next(search)         # 1
('Searching for', 'hello')
>>> search.send("i love you") # 3
>>> search.send("helloworld")  # 4
helloworld
```

0: 初始化此协程
1: 用`next()`方法来启动此协程，line此时被赋值为"hello"，且在“2”处暂停。
3：调用`send()`方法来匹配字符串"hello"，因为没有匹配上所以没有输出。
4：继续匹配“hello”，匹配成功，输出匹配结果。程序继续在2处暂停。


`Python`语言中，对协程支持的并不是很好，目前看来，`greenlet`对`yield`进行封装实现对协程的支持，`Eventlet`再对`greenlet`进行了二次封装，后面有空再对`greenlet`和`Eventlet`做个小结吧。

