rust-analyzer is a new "IDE backend" for the
[Rust](https://www.rust-lang.org/) programming language. Support
rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/) or [GitHub
Sponsors](https://github.com/sponsors/rust-analyzer).

铁锈分析器是铁锈编程语言的一个新的“IDE后端”。支持Open Collective或GitHub赞助商的防锈分析仪。

This post documents a couple of fun tricks we use in rust-analyzer for
measuring memory consumption.

这篇文章记录了我们在锈蚀分析器中用来测量内存消耗的几个有趣的技巧。

In general, there are two broad approaches to profiling the memory usage
of a program.

一般来说，分析程序的内存使用情况主要有两种方法。

*The first approach* is based on “heap parsing”. At a particular point
in time, the profiler looks at all the memory currently occupied by the
program (the heap). In its raw form, the memory is just a bag of bytes,
`Vec<u8>`. However the profiler, using some help from the language’s
runtime, is able to re-interpret these bytes as collections of object
(“parse the heap”). It then traverses the graph of objects and computes
how many instances of each object are there and how much memory they
occupy. The profiler also tracks the ownership relations, to ferret out
facts like “90% of strings in this program are owned by the `Config`
struct”. This is the approach I am familiar with from the JVM ecosystem.
Java’s garbage collector needs to understand the heap to search for
unreachable objects, and the same information is used to analyze heap
snapshots.

第一种方法基于“堆解析”。在特定的时间点，分析器查看程序(堆)当前占用的所有内存。在其原始形式中，内存只是一个字节袋，即`VEC<U8>`。但是，分析器使用来自语言运行时的一些帮助，能够将这些字节重新解释为对象集合(“解析堆”)。然后，它遍历对象图并计算每个对象有多少个实例，以及它们占用了多少内存。分析器还跟踪所有权关系，以查找诸如“此程序中90%的字符串由`Config`结构拥有”之类的事实。这是我在JVM生态系统中熟悉的方法。Java的垃圾收集器需要了解堆才能搜索无法访问的对象，并使用相同的信息来分析堆快照。

*The second approach* is based on instrumenting the calls to allocation
and deallocation routines. The profiler captures backtraces when the
program calls `malloc` and `free` and constructs a flamegraph displaying
“hot” functions which allocate a lot. This is how, for example,
[heaptrack](https://github.com/KDE/heaptrack) works (see also [alloc
geiger](https://github.com/cuviper/alloc_geiger)).

第二种方法基于检测对分配和释放例程的调用。分析器捕获程序调用`malloc`和`fre`时的回溯，并构造一个火焰图，显示分配大量的“热”函数。例如，这就是heaptrace的工作方式(另请参阅alloc Geiger)。

The two approaches are complementary. If the problem is that the
application does too many short-lived allocations (instead of re-using
the buffers), it would be invisible for the first approach, but very
clear in the second one. If the problem is that, in a steady state, the
application uses too much memory, the first approach would work better
for pointing out which data structures need most attention.

这两种方法是相辅相成的。如果问题是应用程序执行了太多的短期分配(而不是重用缓冲区)，那么在第一种方法中是不可见的，但在第二种方法中是非常明显的。如果问题是在稳定状态下，应用程序使用了太多内存，那么第一种方法会更好地指出哪些数据结构最需要注意。

In rust-analyzer, we are generally interested in keeping the overall
memory usage small, and can make better use of heap parsing approach.
Specifically, most of the rust-analyzer’s data is stored in the
incremental computation tables, and we want to know which table is the
heaviest.

在锈蚀分析器中，我们通常对保持较小的总内存使用量感兴趣，并且可以更好地利用堆解析方法。具体地说，生锈分析仪的大部分数据都存储在增量计算表中，我们想知道哪个表最重。

Unfortunately, Rust does not use garbage collection, so just parsing the
heap bytes at runtime is impossible. The best available alternative is
instrumenting data structures for the purposes of measuring memory size.
That is, writing a proc-macro which adds `fn total_size(&self) → usize`
method to annotated types, and calling that manually from the root of
the data. There is Servo’s
[`malloc_size_of`](https://github.com/servo/servo/tree/2d3811c21bf1c02911d5002f9670349c5cf4f500/components/malloc_size_of)
crate for doing that, but it is not published to crates.io.

不幸的是，Rust不使用垃圾收集，因此在运行时只解析堆字节是不可能的。最好的可用替代方案是为了测量内存大小而检测数据结构。也就是说，编写一个过程宏，将`fn TOTAL_SIZE(&Self)→usize`方法添加到带注释的类型，并从数据根手动调用该方法。Servo的‘malloc_size_of’板条箱就是这样做的，但是它没有发布到crates.io。

Another alternative is running the program under valgrind to gain
runtime introspectability.
[Massif](https://www.valgrind.org/docs/manual/ms-manual.html) and and
[DHAT](https://www.valgrind.org/docs/manual/dh-manual.html) work that
way. Running with valgrind is pretty slow, and still doesn’t give
Java-level fidelity.

另一种选择是在valgrind下运行该程序，以获得运行时自省能力。Massif和And dhat就是这样工作的。使用valgrind运行相当慢，而且仍然不能提供Java级别的保真度。

Instead, rust-analyzer mainly relies on a much simpler approach for
figuring out which things are heavy. This is the first trick of this
article:

取而代之的是，铁锈分析仪主要依靠一种简单得多的方法来确定哪些东西重。这是本文的第一个诀窍：

# Archimedes' Method

# 阿基米德法

It’s relatively easy to find out the total memory allocated at any given
point in time. For glibc, there’s
[mallinfo](https://man7.org/linux/man-pages/man3/mallinfo.3.html)
function, a [similar
API](https://docs.rs/jemalloc-ctl/0.3.3/jemalloc_ctl/stats/struct.allocated.html)
exists for jemalloc. It’s even possible to implement a
[`GlobalAlloc`](https://doc.rust-lang.org/stable/std/alloc/trait.GlobalAlloc.html)
which tracks this number.

找出在任何给定时间点分配的总内存相对容易。对于glibc，有mallinfo函数，对于jemalloc也有类似的API。甚至可以实现一个跟踪这个数字的`GlobalAlloc`。

And, if you can measure total memory usage, you can measure memory usage
of any specific data structure by:

而且，如果可以测量总内存使用率，则可以通过以下方式测量任何特定数据结构的内存使用率：

1. measuring the current memory usage
   
   测量当前内存使用情况

1. dropping the data structure
   
   删除数据结构

1. measuring the current memory usage again
   
   再次测量当前内存使用情况

The difference between the two values is the size of the data structure.
And this is exactly what rust-analyzer does to find the largest caches:
[source](https://github.com/rust-analyzer/rust-analyzer/blob/b988c6f84e06bdc5562c70f28586b9eeaae3a39c/crates/ide_db/src/apply_change.rs#L104-L238).

这两个值之间的差异在于数据结构的大小。而这正是铁锈分析器要找到最大的储藏物所做的事情：来源。

Two small notes about this method:

关于此方法有两个小注意事项：

* It’s important to ask the allocator about the available memory, and
  not the operating system. OS can only tell how many pages the
  program consumes. Only the allocator knows which of those pages are
  free and which hold allocated objects.
  
  向分配器询问可用内存，而不是操作系统，这一点很重要。操作系统只能告诉程序消耗了多少页。只有分配器知道这些页面中哪些是空闲的，哪些保存已分配的对象。

* When measuring relative sizes, it’s important to note the
  unaccounted-for amount in the end, such that the total adds up to
  100%. It might be the case that the bottleneck lies in the dark
  matter outside of explicit measurements!
  
  在测量相对大小时，重要的是要注意最后未计入的金额，这样总数加起来就是100%。可能的情况是，瓶颈存在于显式测量之外的暗物质中！

# Amdahl’s Estimator

# 阿姆达尔(氏)估计器

The second trick is related to the [Amdahl’s
law](https://en.wikipedia.org/wiki/Amdahl’s_law). When optimizing a
specific component, it’s important to note not only how much more
efficient it becomes, but also overall contribution of the component to
the system. Making an algorithm twice as fast can improve the overall
performance only by 5%, if the algorithm is only 10% of the whole task.

第二个把戏与阿姆达尔定律有关。在优化特定组件时，不仅要注意它的效率提高了多少，还要注意该组件对系统的总体贡献，这一点很重要。如果算法只占整个任务的10%，则使算法的速度提高两倍只能将整体性能提高5%。

In rust-analyzer’s case, the optimization we are considering is adding
interning to `Name`. At the moment, a `Name` is represented with a small
sized optimized string (24 bytes inline + maybe some heap storage):

在铁锈分析器的例子中，我们正在考虑的优化是在`Name`中添加interning。目前，`Name`用一个较小的优化字符串表示(24字节内联+可能是一些堆存储)：

```rust
struct Name {
    text: SmolStr,
}
```

Instead, we can use an interned index (4 bytes):

相反，我们可以使用内部索引(4字节)：

```rust
struct Name {
    idx: u32
}
```

However, just trying out this optimization is not easy, as an interner
is a thorny piece of global state. Is it worth it?

然而，仅仅尝试这种优化并不容易，因为实习生是一个棘手的全球问题。值得吗？

If we look at the `Name` itself, it’s pretty clear that the optimization
is valuable: it reduces memory usage by 6x! But how important is it in
the grand scheme of things? How to measure the impact of `Name`s on
overall memory usage?

如果我们看一下“Name”本身，很明显优化是有价值的：它将内存使用量减少了6倍！但是，在宏伟的计划中，它有多重要呢？如何衡量`NAME‘s对整体内存使用的影响？

One approach is to just apply the optimization and measure the
improvement after the fact. But there’s a lazier way: instead of making
the `Name` smaller and measuring the improvement, we make it **bigger**
and measure the worsening. Specifically, its easy to change the `Name`
to this:

一种方法是只应用优化，并在事后测量改进。但还有一种更懒惰的方式：我们不是把“名字”变小并衡量改进，而是把它变大并衡量恶化的程度。具体来说，`Name`很容易改成这样：

```rust
struct Name {
    text: SmolStr,
    // Copy of `text`
    _ballast: SmolStr,
}
```

Now, if the new `Name` increases the overall memory consumption by `N`,
we can estimate the total size of old `Name`s as `N` as well, as they
are twice as small.

现在，如果新的`Name`增加了`N`的整体内存消耗，我们可以估计旧`Name的总大小也是`N`，因为它们是原来的两倍小。

Sometimes, quick and simple hacks works better than the finest
instruments :).

有时，快速而简单的破解比最好的乐器更有效：)。