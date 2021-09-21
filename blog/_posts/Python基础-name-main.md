---
title: Python基础-__name__ == '__main__'
date: 2018-10-06 15:44:32
tags: Python
thumbnail: /css/images/苏州.jpg
---

今年国庆节过的比较悠闲，中间只有一天来了一个短途去了苏州，其余大部分时间都是在家休息，这是我第二次去苏州，印象中对苏州园林的印象还一直来自于中学课本，园林应该是一个大的公园，有竹林，小桥，流水，假山，凉亭。算得上是一个自然景观吧。这次去亲身体验发现我的假设大部分还是对的，只是它不是一座公园，而是有钱人的私家宅院。读万卷书，行万里路，可见没有实践的永远不能保证是完全正确的，想象和现实总是有着各种差距。

看了Pence的演讲，即便我无意于或者不忍于贬低自己的祖国，但却又无法说服自己这些个烂疮实实在在的存在于这个国度。无奈，无力，失语。但愿正如Pence引用的那句话，Heaven not only see the future, but also give us the hope!

---

回过头来看看Python为什么需要\__name\__ == '\__main\__'？ 先看看两段代码：

``` python
# executor.py
def entry():
    print ("implement something here...")

print ("do something here...")
print __name__

if __name__ == '__main__':
    pass

```

``` python
# caller.py
import executor

if __name__ == '__main__':
    pass
```


如果直接运行第一段程序，我们将得到下面的结果：

``` bash
>python executor.py
do something here...
__main__
```

运行第二段程序输出下面的结果：

``` bash
>python caller.py
do something here...
executor
```

这里我们得出两条结论：
1）Python里可以直接在模块里写不属于任何function的语句，例如第一段程序里的两个print语句，这个有点类似shell，而不同于java或者c语言，这些语句无论在本模块被执行或者被import到其它python文件中去，都会被自动执行，这有时不是我们希望看到的。而实际上这些语句常常被理解为Python的main函数。我们可以忽略所谓的main函数，因为这对于我们的理解无益，但是我们可以将其改写为下面的形式：

``` python
# executor.py
def entry():
    print ("implement something here...")

def main():
    print ("do something here...")
    print __name__

if __name__ == '__main__':
    main()
```

这样以第一种方式直接执行此文件，得到的将是相同的结果。

2）\__name\__被解释为不同的名字，第一种方式被解释为\__main\__, 而第二种被解释为executor，所以当我们将程序改写为上面的形式的时候，main中的定义的语句这次将得不到执行。这时候将没有任何输出。但同时可以通过显示的调用*executor.main()*来让这两行语句得到执行。


所以，python程序中if \__name\__ == '\__main\__' 这行语句的目的就是希望有些语句能有条件的得到执行，或者说只有本模块直接运行时才会被调用。这样保证了此模块被其它模块引入时这些语句不会被调用，即便它时所谓的main函数。
那什么时候需要用这样的语句呢？一个典型的例子比如在做模块的单元测试的时候。


---
[1] https://interactivepython.org/runestone/static/CS152f17/Functions/mainfunction.html
