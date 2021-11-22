Last month, rust-analyzer gained an exciting new feature: find usages.
It was implemented by [@viorina](https://github.com/viorina) in
[\#1892](https://github.com/rust-analyzer/rust-analyzer/pull/1892).

上个月，铁锈分析仪有了一项令人兴奋的新功能：查找用途。它是由@viorina在#1892年实现的。

This post describes how the feature works under the hood. It’s an
excellent case study to compare approaches of traditional compilers with
IDE-oriented compilers (shortened to IDE from now on).

这篇文章描述了这个功能是如何在引擎盖下工作的。这是比较传统编译器和面向IDE编译器(从现在起简称为IDE)方法的一个很好的案例研究。

# Definitions and Usages

# 定义和用法

Let’s start with a simple example:

让我们从一个简单的例子开始：

```rust
fn foo() {
    let x = 92;
    let y = 62;

    if condition {
        y + 1
    } else {
        x + 2
    };
}
```

Suppose that a user invoked **find usages** (also known as **reference
search**) on `x`. An IDE should highlight `x` in `x + 2` as a usage.

假设用户在`x`上调用了查找使用实例(也称为引用搜索)。IDE应该突出显示`x+2`中的`x`作为用法。

But lets start with a simpler problem: **goto definition** (which is the
reverse of **find usages**). How does a compiler or an IDE understands
that `x` in `x + 2` refers to `let x = 92;`?

但让我们从一个更简单的问题开始：转到定义(与查找用法相反)。编译器或IDE如何理解`x+2`中的`x`指的是`let x=92；`？

Terminology Note: we will call the `x` in `let x = 92` a **definition**,
and the `x` in `x + 2` a **reference**.

术语说明：`let x=92`中的`x`为定义，`x+2`中的`x`为参考。

Note: the following presentation is oversimplified and is not based
directly on any existing compiler or IDE. Consider it a text-book
illustration, and not a fossil specimen.

注意：下面的演示过于简化，没有直接基于任何现有的编译器或IDE。把它当作课本插图，而不是化石标本。

# Compiler’s Approach

# 编译器的方法

A typical compiler works by building a symbol table. It does a
depth-first traversal of the syntax tree of a program, maintaining a
hash-map of definitions. For the above example, the compiler does the
following steps, in order:

典型的编译器通过构建符号表来工作。它对程序的语法树进行深度优先遍历，维护定义的哈希图。对于上面的示例，编译器按顺序执行以下步骤：

1. Create an empty map.
   
   创建一个空地图。

1. Visit `let x = 92`. Records this definition in the map under the
   `"x"` key.
   
   访问`let x=92`。将此定义记录在地图中的`“x”`键下。

1. Visit `let y = 62`. Records this definition in the map under the
   `"y"` key.
   
   访问`let y=62`。将此定义记录在地图中的`“y”`键下。

1. Visit `condition`.
   
   访问`条件`。

1. Visit "then" branch of the `if` expression. Lookup `"y"` in the map
   and record association between a reference and a definition.
   
   访问`if`表达式的“THEN”分支。在映射中查找`“y”`，并记录引用和定义之间的关联。

1. Visit "else" branch of the `if` expression. Lookup `"x"` in the map
   and record association between a reference and a definition.
   
   访问`if`表达式的“Else”分支。在映射中查找`“x”`，并记录引用和定义之间的关联。

After the end of the traversal, the compiler knows, for each reference,
what definition this reference points to. If a reference is unresolved,
the compiler emits an error.

遍历结束后，对于每个引用，编译器都知道该引用指向什么定义。如果引用未解析，编译器将发出错误。

We may say that a compiler processes a program **top-down**.

我们可以说编译器自上而下地处理程序。

# IDE Approach

# IDE方法

To figure out where the `x` in `x + 2` points to, a typical IDE does
something different. Instead of starting from the root of the tree, it
starts from the usage, and proceeds upwards.

为了找出`x+2`中的‘x`指向哪里，典型的IDE会做一些不同的事情。它不是从树的根开始，而是从用法开始，向上进行。

So, the IDE would do the following:

因此，IDE将执行以下操作：

1. Start at `x + 2`.
   
   从‘x+2’开始。

1. Look at the parent "else" branch, notice that there are no
   definitions there.
   
   看看父“Else”分支，注意那里没有定义。

1. Look at the parent "if" expression.
   
   看看父“if”表达式。

1. Look at the parent block, notice that it has `x` defined, return
   this definition as an answer.
   
   看看父挡路，注意它定义了`x`，返回这个定义作为回答。

The crucial point here is that IDE skips "then" branch completely. It
doesn’t look like a big deal with this small branch which contains a
single expression only. However, the real world programs are much more
complicated, and an IDE can skip quite a lot of code by only climbing
the tree up.

这里的关键点是IDE完全跳过了“THEN”分支。这个只包含一个表达式的小分支看起来没什么大不了的。然而，现实世界中的程序要复杂得多，IDE只需向上爬树就可以跳过相当多的代码。

This is the **bottom-up** approach.

这是自下而上的方法。

# Which Way is Better?

# 哪条路更好？

It depends! Let’s do a quick estimation of work required to find, for
each reference, a definition it points to.

那得看情况!让我们快速估计一下为每个引用查找它所指向的定义所需的工作。

The compiler’s case is easy: we just traverse a program once, doing
hashmap operations along the way. That would be `O(program_size)`.

编译器的情况很简单：我们只需遍历程序一次，一路上执行散列映射操作。这将是`O(PROGRAM_SIZE)`。

The IDE’s case is more tricky: we still need to traverse a program to
find all references. Then, for each reference, we need to launch the
"traverse tree upwards" procedure. Which gives us
`O(program_size + n_references * program_depth)`. This is clearly worse!

IDE的情况更为棘手：我们仍然需要遍历程序来查找所有引用。然后，对于每个引用，我们需要启动“向上遍历树”过程。这给出了`O(程序_大小+n_引用*程序_深度)‘。这显然更糟！

But let’s now look at the time we need to resolve one specific
reference. A compiler still has to construct the symbol table, so it’s
still `O(program_size)`. An IDE, however, can launch only a single
upward traversal, and that would be only `O(program_depth)`!

但现在让我们看看我们需要解析一个特定引用的时间。编译器仍然需要构造符号表，所以它仍然是`O(PROGRAM_SIZE)`。然而，IDE只能启动一次向上遍历，而且只能是`O(PROGRAM_DEPTH)`！

These observations are exactly the reason why compilers prefer the first
approach, while IDEs favor the second one. A compiler has to check and
compile all the code anyway, so it’s important to do all the work as
efficiently as possible. For IDEs however, the main trick is to ignore
as much code as feasible. An IDE needs to know only about usages under
one specific reference under the cursor in the currently opened file. It
doesn’t care what is the definition of a `spam` variable used in the
`frobnicate` function somewhere in the guts of the standard library.

这些观察结果正是编译器偏爱第一种方法，而IDE偏爱第二种方法的原因。无论如何，编译器必须检查和编译所有代码，因此尽可能高效地完成所有工作非常重要。然而，对于IDE，主要的诀窍是忽略尽可能多的代码。IDE只需要知道当前打开的文件中光标下的一个特定引用下的用法。它不关心标准库毅力中的`frobnicate`函数中使用的`spam`变量的定义是什么。

More generally, an IDE would like - to know everything about a small
droplet of code that is currently on the screen and - to know nothing
about the vast ocean of code that is off-screen.

更广泛地说，IDE希望-了解关于当前屏幕上的一小滴代码的一切，而对屏幕外的浩瀚代码一无所知。

# Find Usages

# 查找用法

Let’s get back to the original problem, find usages.

让我们回到原来的问题上，找出用法。

If a compiler has already constructed a symbol table, the solution is
trivial: just enumerate all the usages. It might need a little bit of
extra bookkeeping (storing the list of usages in the symbol table), but
basically this is just "print the answer we already have".

如果编译器已经构造了符号表，那么解决方案很简单：只需枚举所有用法即可。它可能需要一些额外的记账工作(将用法列表存储在符号表中)，但基本上这只是“打印我们已有的答案”。

For an IDE, something else is required. The trivial solution of doing a
bottom-up traversal from every reference is worse than just launching
the compiler from scratch.

对于IDE，还需要一些其他的东西。从每个引用进行自下而上遍历的琐碎解决方案比仅仅从头开始启动编译器更糟糕。

Instead, IDEs do a cute trick, which can be called a hack even!
IntelliJ, Type Script, and, since last month, rust-analyzer work like
this.

相反，艾德斯做了一个可爱的把戏，甚至可以称之为黑客！IntelliJ，Type Script，从上个月开始，铁锈分析仪就是这样工作的。

First thing an IDE does is a **text** search across all files, which
finds the set of potential matches. As text search is much simpler than
code analysis, this phase finishes relatively quickly. Then the IDE
filters out false positives, by doing bottom-up traversal from candidate
matches.

IDE做的第一件事是对所有文件进行文本搜索，这将查找潜在的匹配集。由于文本搜索比代码分析简单得多，因此此阶段相对较快地完成。然后，IDE通过对候选匹配执行自下而上的遍历来过滤假阳性。

The text-based pre filtering again allows the IDE to skip over most of
the code, and complete find-usages in less time than it would the
compiler to build a symbol table.

基于文本的预过滤再次允许IDE跳过大部分代码，并在比编译器构建符号表的时间更短的时间内完成查找用法。

# Incrementality vs Laziness

# 增量VS懒惰

Can we make the top-down approach as effective as bottom-up (and maybe
even more so), by just making the calculation of symbol table
incremental? The idea is to maintain a data structure that connects
references and definitions and, when a user changes a piece of code,
apply the diff to the data structure, instead of re-computing it from
scratch.

我们能使自上而下的方法和自下而上的方法一样有效(甚至可能更有效)，只需增加符号表的计算就可以了吗？其思想是维护一个连接引用和定义的数据结构，当用户更改一段代码时，将DIFF应用于数据结构，而不是从头开始重新计算。

The fundamental issue with this approach is that it solves the problem
an IDE doesn’t have in the first place. From that symbol data structure,
only a tiny part is interesting for an IDE at any given moment of time.
Most of the code is private implementation details of dependencies, and
they are completely irrelevant for IDE tasks, unless a user invokes "go
to definition" on a symbol from library and actively studies these
details.

这种方法的根本问题是它首先解决了IDE没有的问题。从该符号数据结构中，IDE在任何给定时刻都只有一小部分是有趣的。大部分代码是依赖项的私有实现细节，它们与IDE任务完全无关，除非用户对库中的符号调用“转到定义”并主动研究这些细节。

On the other hand, building and updating such data structure takes time.
Specifically, because the data is intricate and depends on the language
semantics, small changes to the source code (change of a module name,
for example) might necessitate big rearrangement of computed result.

另一方面，构建和更新这样的数据结构需要时间。具体地说，因为数据错综复杂，并且依赖于语言语义，所以对源代码的微小更改(例如，模块名称的更改)可能需要对计算结果进行大的重新排列。

In general, laziness (ability to ignore most of the code) and
incrementality (ability to quickly update derived data based on source
changes) are orthogonal features. First and foremost, an IDE requires
laziness, although incrementality can be used as well to speed some
things up.

通常，惰性(忽略大部分代码的能力)和增量(根据源代码更改快速更新派生数据的能力)是正交特性。首先也是最重要的，IDE需要懒惰，尽管增量也可以用来加速某些事情。

In particular, it is possible to make the text-based phase of reference
search incremental. An IDE can maintain a trigram index: for each
three-byte sequence, a list of files and positions where this sequence
occurs. Unlike symbol tables, such index is easy to maintain, as any
change in a file can only affect trigrams from this file. The index can
then be used to speedup text search. The result is the following **find
usages** funnel:

特别地，可以使引用搜索的基于文本的阶段递增。IDE可以维护一个三元组索引：对于每个三字节序列，该序列出现的文件和位置的列表。与符号表不同，这样的索引易于维护，因为文件中的任何更改都只会影响该文件中的三元组。然后可以使用该索引来加速文本搜索。结果是以下查找使用情况漏斗：

1. First, an IDE finds all positions where identifier’s trigrams match,
   
   首先，IDE查找标识符的三元组匹配的所有位置，

1. Then, the IDE checks if a trigram match is in fact a full identifier
   match,
   
   然后，IDE检查三元组匹配是否实际上是完全标识符匹配，

1. Finally, IDE uses semantic analysis to prune away remaining
   false-positives.
   
   最后，IDE使用语义分析来删除剩余的误报。

This is optimization is not implemented in rust-analyzer yet. It
definitely is planned, but not for the immediate future.

这是目前在生锈分析仪上还没有实现的优化。这肯定是有计划的，但不是在不久的将来。

# Tricks

# 花招

Let’s look at a couple of additional tricks an IDE can employ.

让我们看看IDE可以使用的几个附加技巧。

First, the IDE can add yet another step to the funnel: pruning the set
of files worth searching. These restrictions can originate from the
language semantics: it doesn’t make sense to look for `pub(crate)`
declaration outside of the current crate or for `pub` declaration among
crate dependencies. They also can originate from the user: it’s often
convenient to exclude tests from search results, for example.

首先，IDE可以向漏斗中添加另一个步骤：修剪值得搜索的文件集。这些限制可能源于语言语义：在当前机箱外查找“pub(Crate)”声明或在机箱依赖项中查找“pub”声明是没有意义的。它们也可以来自用户：例如，从搜索结果中排除测试通常比较方便。

The second trick is about implementing warnings for unused declarations
effectively. This is a case where a top-down approach is generally
better, as an IDE needs to process every declaration, and that would be
slow with top-down approach. However, with a trigram index the IDE can
apply an interesting optimization: only check those declarations which
have few textual matches. This will miss an used declaration with a
popular name, like `new`, but will work ok for less-popular names, with
a relatively good performance.

第二个技巧是如何有效地实现对未使用声明的警告。在这种情况下，自上而下的方法通常更好，因为IDE需要处理每个声明，而使用自上而下的方法会很慢。然而，使用三元组索引，IDE可以应用一个有趣的优化：只检查那些文本匹配很少的声明。这将错过使用流行名称的声明，如`new`，但对于性能相对较好的不太流行的名称也可以。

# Real World

# 真实世界

Now it’s time to look at what actually happens in rust-analyzer. First
of all, I must confess, it doesn’t use the bottom-up approach :)

现在是时候来看看锈蚀分析仪到底发生了什么。首先，我必须承认，它没有使用自下而上的方法：)

Rust type-inference works at a function granularity: statements near the
end of a function can affect statements at the beginning. So, it doesn’t
make sense to do name resolution at the granularity of an expression,
and indeed rust-analyzer builds a per-function [symbol
table](https://github.com/rust-analyzer/rust-analyzer/blob/d523366299c8d4813e9845c9402b8dd7b779856a/crates/ra_hir/src/expr/scope.rs).
This is still done lazily though: we don’t look into the function body
unless the text search tells us to do so.

RUST类型-推理以函数粒度工作：函数末尾附近的语句可能会影响开头的语句。因此，在表达式粒度进行名称解析是没有意义的，事实上，锈检分析器会构建每个函数的符号表。不过，这仍然是懒惰的做法：我们不会查看函数体，除非文本搜索告诉我们这样做。

Name resolution on the module/item level in Rust is pretty complex as
well. The interaction between macros, which can bring new names into the
scope, and glob imports, which can tie together namespaces of two
modules, requires not only top-down processing, but a repeated top-down
processing (until a fixed point is reached). For this reason,
module-level name resolution in rust-analyzer is also implemented using
the top-down approach. We use [salsa](https://github.com/salsa-rs/salsa)
to make this phase of name resolution incremental, as a substitute for
laziness (see [this
module](https://github.com/rust-analyzer/rust-analyzer/blob/d523366299c8d4813e9845c9402b8dd7b779856a/crates/ra_hir_def/src/nameres.rs)
for details). The results look promising so far: by processing function
bodies lazy, we greatly reduce the amount of data the fixed-point
iteration algorithm has to look at. By adding salsa on-top, we avoid
re-running this algorithm most of the time.

Rust中模块/项级别的名称解析也相当复杂。宏(可以将新名称引入作用域)和GLOB导入(可以将两个模块的名称空间绑定在一起)之间的交互不仅需要自上而下的处理，还需要重复的自上而下的处理(直到达到固定点)。为此，锈检分析器中的模块级名称解析也是使用自顶向下的方法来实现的。我们使用SASA来增加这一阶段的名称解析，作为懒惰的替身(有关详细信息，请参阅此模块)。到目前为止，结果看起来很有希望：通过延迟处理函数体，我们大大减少了定点迭代算法需要查看的数据量。通过在顶部添加SASA，我们可以避免在大多数时间重新运行此算法。

However, the general search funnel is there!

然而，总的搜索漏斗就在那里！

1. Here’s the [entry
   point](https://github.com/rust-analyzer/rust-analyzer/blob/d523366299c8d4813e9845c9402b8dd7b779856a/crates/ra_ide_api/src/lib.rs#L383-L390)
   for find usages. Callee can restrict the `SearchScope`. For example,
   when the editor asks to highlight all usages of the identifier under
   the cursor, the scope is restricted to a single file.
   
   这里是查找用法的入口点。被调用方可以限制`SearchScope`。例如，当编辑器要求突出显示光标下标识符的所有用法时，范围仅限于单个文件。

1. The first step of find usages is figuring out what to find in the
   first place. This is handled by
   [`find_name`](https://github.com/rust-analyzer/rust-analyzer/blob/c486f8477aca4a42800e81b0b99fd56c14c6219f/crates/ra_ide_api/src/references.rs#L106-L120)
   functions. There are two cases to consider: the cursor can be either
   on the reference, or on the definition. We handle the first case by
   resolving the reference to the definition and converging to the
   second case.
   
   查找用法的第一步是首先找出要查找的内容。这是由`find_name`函数处理的。有两种情况需要考虑：游标可以位于引用上，也可以位于定义上。我们通过解析对定义的引用并收敛到第二种情况来处理第一种情况。

1. Once we’ve figured out the definition, we compute it’s search scope
   and intersect it with the provided scope:
   [source](https://github.com/rust-analyzer/rust-analyzer/blob/c486f8477aca4a42800e81b0b99fd56c14c6219f/crates/ra_ide_api/src/references.rs#L93-L99).
   
   一旦我们弄清楚了定义，我们就计算它的搜索范围并将其与提供的范围：source相交。

1. After that, we do a simple text search over all files in the scope:
   [source](https://github.com/rust-analyzer/rust-analyzer/blob/c486f8477aca4a42800e81b0b99fd56c14c6219f/crates/ra_ide_api/src/references.rs#L137).
   This is the place where trigram index should be added.
   
   之后，我们对Scope：Source中的所有文件执行简单的文本搜索。这是应该增加三元索引的地方。

1. If there’s a match, we parse the file, to make sure that it is
   indeed a reference, and not a comment or a string literal:
   [source](https://github.com/rust-analyzer/rust-analyzer/blob/c486f8477aca4a42800e81b0b99fd56c14c6219f/crates/ra_ide_api/src/references.rs#L135).
   Note how we use a local
   [Lazy](https://docs.rs/once_cell/1.2.0/once_cell/unsync/struct.Lazy.html)
   value to parse only those files, which have at least one match.
   
   如果存在匹配项，我们将解析该文件，以确保它确实是引用，而不是注释或字符串：source。请注意，我们如何使用本地Lazy值来仅解析那些至少有一个匹配的文件。

1. Finally, we check that the candidate reference indeed resolves to
   the definition we have started with:
   [source](https://github.com/rust-analyzer/rust-analyzer/blob/c486f8477aca4a42800e81b0b99fd56c14c6219f/crates/ra_ide_api/src/references.rs#L150).
   
   最后，我们检查候选引用是否确实解析为我们开始的定义：source。

That’s all for the find usages, thank you for reading!

查找用法到此为止，感谢您的阅读！