rust-analyzer is a new "IDE backend" for the
[Rust](https://www.rust-lang.org/) programming language. Support
rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/).

铁锈分析器是铁锈编程语言的一个新的“IDE后端”。支持Open Collective上的防锈分析仪。

In this post, we’ll learn how to make a snappy IDE, in three different
ways :-) It was inspired by this excellent article about using datalog
for semantic analysis:
[https://petevilter.me/post/datalog-typechecking/](https://petevilter.me/post/datalog-typechecking/) The post describes
only the highest-level architecture. There’s **much** more to
implementing a full-blown IDE.

在这篇文章中，我们将通过三种不同的方式学习如何制作一个快速的集成开发环境：-)它的灵感来自于这篇关于使用数据日志进行语义分析的优秀文章：https://petevilter.me/post/datalog-typechecking/这篇文章只描述了最高级别的架构。要实现一个全面的IDE，还有更多的事情要做。

Specifically, we’ll look at the backbone infrastructure of an IDE which
serves two goals:

具体地说，我们将查看IDE的主干基础结构，它服务于两个目标：

* Quickly accepting new edits to source files.
  
  快速接受对源文件的新编辑。

* Providing type information about currently opened files for
  highlighting, completion, etc.
  
  提供有关当前打开的文件的类型信息，以便突出显示、完成等。

# Map Reduce

# 贴图减少

The first architecture is reminiscent of the map-reduce paradigm. The
idea is to split analysis into relatively simple indexing phase, and a
separate full analysis phase.

第一种架构让人联想到Map-Reduce范例。其思想是将分析划分为相对简单的索引阶段和单独的完整分析阶段。

The core constraint of indexing is that it runs on a per-file basis. The
indexer takes the text of a single file, parses it, and spits out some
data about the file. The indexer can’t touch other files.

索引的核心约束是它在每个文件的基础上运行。索引器获取单个文件的文本，对其进行解析，并输出有关该文件的一些数据。索引器不能接触其他文件。

Full analysis can read other files, and it leverages information from
the index to save work.

完全分析可以读取其他文件，并且它利用索引中的信息来保存工作。

This all sounds way too abstract, so let’s look at a specific
example — Java. In Java, each file starts with a package declaration.
The indexer concatenates the name of the package with a class name to
get a fully-qualified name (FQN). It also collects the set of methods
declared in the class, the list of superclasses and interfaces, etc.

这听起来太抽象了，所以让我们看一个具体的示例 - JAVA。在Java中，每个文件都以包声明开始。索引器将包的名称与类名连接起来，以获得完全限定的名称(FQN)。它还收集类中声明的方法集、超类和接口列表等。

Per-file data is merged into an index which maps FQNs to classes. Note
that constructing this mapping is an embarrassingly parallel task — all
files are parsed independently. Moreover, this map is cheap to update.
When a file change arrives, this file’s contribution from the index is
removed, the text of the file is changed and the indexer runs on the new
text and adds the new contributions. The amount of work to do is
proportional to the number of changed files, and is independent from the
total number of files.

将每个文件的数据合并到将FQN映射到类的索引中。请注意，构建此映射是一项令人尴尬的并行任务， - 所有文件都是独立解析的。此外，这张地图更新成本很低。当文件更改到达时，从索引中删除此文件的贡献，更改文件的文本，索引器在新文本上运行并添加新贡献。要做的工作量与更改的文件数成正比，并且与文件总数无关。

Let’s see how FQN index can be used to quickly provide completion.

让我们看看如何使用FQN索引来快速提供完成。

```java
// File ./mypackage/Foo.java
package mypackage;

import java.util.*;

public class Foo {
    public static Bar f() {
        return new Bar();
    }
}

// File ./mypackage/Bar.java
package mypackage;

public class Bar {
    public void g() {}
}

// File ./Main.java
import mypackage.Foo;

public class Main {
    public static void main(String[] args) {
        Foo.f().
    }
}
```

The user has just typed `Foo.f().`, and we need to figure out that the
type of receiver expression is `Bar`, and suggest `g` as a completion.

用户刚刚输入了`Foo.f().`，我们需要弄清楚接收方表达式的类型是`bar`，并建议`g`作为补全。

First, as the file `Main.java` is modified, we run the indexer on this
single file. Nothing has changed (the file still contains the class
`Main` with a static `main` method), so we don’t need to update the FQN
index.

首先，随着`Main.java`文件的修改，我们对这个文件运行索引器。没有什么变化(文件中仍然包含带有静电`main`方法的`Main`类)，所以我们不需要更新fqn索引。

Next, we need to resolve the name `Foo`. We parse the file, notice an
`import` and look up `mypackage.Foo` in the FQN index. In the index, we
also find that `Foo` has a static method `f`, so we resolve the call as
well. The index also stores the return type of `f`, but, and this is
crucial, it stores it as a string `"Bar"`, and not as a direct reference
to the class `Bar`.

接下来，我们需要解析名称`foo`。我们解析文件，注意到一个`import`，并在FQN索引中查找`mypackage.Foo`。在索引中，我们还发现`Foo`有一个静电方法`f`，所以我们也解析了这个调用。该索引还存储了`f`的返回类型，但是，这一点很重要，它将其存储为字符串`“Bar”`，而不是直接引用类`Bar`。

The reason for that is `import java.util.*` in `Foo.java`. `Bar` can
refer either to `java.util.Bar` or to `mypackage.Bar`. The indexer
doesn’t know which one, because it can look **only** at the text of
`Foo.java`. In other words, while the index does store the return types
of methods, it stores them in an unresolved form.

原因是`Foo.java`中的`import java.util.*`。`Bar`可以指`java.util.Bar`，也可以指`mypackage.Bar`。索引器不知道是哪一个，因为它只能查看`Foo.java`的文本。换句话说，虽然索引确实存储了方法的返回类型，但它以未解析的形式存储它们。

The next step is to resolve the identifier `Bar` in the context of
`Foo.java`. This uses the FQN index, and lands in the class
`mypackage.Bar`. There the desired method `g` is found.

下一步是解析`Foo.java`上下文中的`Bar`标识符。它使用FQN索引，并位于类`mypackage.Bar`中。在那里可以找到所需的方法`g`。

Altogether, only three files were touched during completion. The FQN
index allowed us to completely ignore all the other files in the
project.

总共只有三个文件在完成过程中被触及。FQN索引允许我们完全忽略项目中的所有其他文件。

One problem with the approach described thus far is that resolving types
from the index requires a non-trivial amount of work. This work might be
duplicated if, for example, `Foo.f` is called several times. The fix is
to add a cache. Name resolution results are memoized, so that the cost
is paid only once. The cache is blown away completely on any
change — with an index, reconstructing the cache is not that costly.

到目前为止所描述的方法的一个问题是，从索引解析类型需要大量的工作。例如，如果多次调用`Foo.f`，则此工作可能会重复。修复方法是添加一个缓存。名称解析结果会被记录下来，因此只需支付一次费用。使用索引对 - 进行任何更改时，缓存都会被完全清除，重新构建缓存的成本并不高。

To sum up, the first approach works like this:

总而言之，第一种方法的工作原理如下：

1. Each file is being indexed, independently and in parallel, producing
   a "stub" — a set of visible top-level declarations, with unresolved
   types.
   
   每个文件都被独立地、并行地索引，生成一个“存根” - (带有未解析类型的一组可见的顶级声明)。

1. All stubs are merged into a single index data structure.
   
   所有存根都合并到单个索引数据结构中。

1. Name resolution and type inference work primarily off the stubs.
   
   名称解析和类型推断主要在存根上工作。

1. Name resolution is lazy (we only resolve a type from the stub when
   we need it) and memoized (each type is resolved only once).
   
   名称解析是惰性的(我们只在需要的时候解析存根中的类型)，并且是有记忆的(每个类型只解析一次)。

1. The caches are completely invalidated on every change
   
   每次更改时，缓存都会完全失效

1. The index is updated incrementally:
   
   索引以增量方式更新：
   
   * if the edit doesn’t change the file’s stub, no change to the
     index is required.
     
     如果编辑没有更改文件的存根，则不需要更改索引。
   
   * otherwise, old keys are removed and new keys are added
     
     否则，将删除旧密钥并添加新密钥

Note an interesting interplay between "dumb" indexes which can be
updated incrementally, and "smart" caches, which are re-computed from
scratch.

请注意，可以增量更新的“哑”索引和从头开始重新计算的“智能”缓存之间有一个有趣的相互作用。

This approach combines simplicity and stellar performance. The bulk of
work is the indexing phase, and you can parallelize and even distribute
it across several machine. Two examples of this architecture are
[IntelliJ](https://www.jetbrains.com/idea/) and
[Sorbet](https://sorbet.org/).

这种方法结合了简单性和卓越的性能。大量工作是索引阶段，您可以将其并行化，甚至将其分布在多台机器上。此架构的两个示例是IntelliJ和Sorbet。

The main drawback of this approach is that it works only when it
works — not every language has a well-defined FQN concept. I think
overall it’s a good idea to design name resolution and module systems
(mostly boring parts of a language) such that they work well with the
map-reduce paradigm.

这种方法的主要缺点是，它只有在工作时才起作用，并不是每种语言都有定义良好的 - 概念。总体而言，我认为设计名称解析和模块系统(主要是语言中令人厌烦的部分)以便它们能够很好地与map-duce范例协同工作是一个好主意。

* Require `package` declarations or infer them from the file-system
  layout
  
  需要`Package`声明或从文件系统布局推断它们

* Forbid meta-programming facilities which add new top-level
  declarations, or restrict them in such way that they can be used by
  the indexer. For example, preprocessor-like compiler plugins that
  access a single file at a time might be fine.
  
  禁止添加新的顶级声明的元编程工具，或者限制它们以便索引器可以使用它们。例如，一次访问一个文件的类似预处理器的编译器插件可能会很好。

* Make sure that each source element corresponds to a single semantic
  element. For example, if the language supports conditional
  compilation, make sure that it works during name resolution (like
  Kotlin’s
  [expect/actual](https://kotlinlang.org/docs/reference/platform-specific-declarations.html))
  and not during parsing (like conditional compilation in most other
  languages). Otherwise, you’d have to index the same file with
  different conditional compilation settings, and that is messy.
  
  确保每个源元素对应于单个语义元素。例如，如果该语言支持条件编译，请确保它在名称解析期间(如Kotlin的Expect/Actual)工作，而不是在解析期间(如大多数其他语言中的条件编译)。否则，您将不得不用不同的条件编译设置来索引同一文件，这是很混乱的。

* Make sure that FQNs are enough for most of the name resolution.
  
  确保FQN足以完成大部分名称解析。

The last point is worth elaborating. Let’s look at the following Rust
example:

最后一点值得详细说明。让我们看看下面的铁锈示例：

```rust
// File: ./foo.rs
trait T {
    fn f(&self) {}
}
// File: ./bar.rs
struct S;

// File: ./somewhere/else.rs
impl T for S {}

// File: ./main.s
use foo::T;
use bar::S

fn main() {
    let s = S;
    s.f();
}
```

Here, we can easily find the `S` struct and the `T` trait (as they are
imported directly). However, to make sure that `s.f` indeed refers to
`f` from `T`, we also need to find the corresponding `impl`, and that
can be roughly anywhere!

在这里，我们可以很容易地找到`S‘结构和`T’特征(因为它们是直接导入的)。但是，为了确保`s.f`确实引用了`T`中的`f`，我们还需要找到对应的`impl`，它可以大致在任何地方！

# Leveraging Headers

# 利用标题

The second approach places even more restrictions on the language. It
requires:

第二种方法对语言施加了更多的限制。它需要：

* a "declaration before use" rule,
  
  “使用前申报”规则，

* headers or equivalent interface files.
  
  头文件或等效的接口文件。

Two such languages are C++ and OCaml.

两种这样的语言是C++和OCaml。

The idea of the approach is simple — just use a traditional compiler and
snapshot its state immediately after imports for each compilation unit.
An example:

该方法的思想很简单， - 只需使用传统编译器，并在导入每个编译单元后立即快照其状态。例如：

```c++
#include <iostream>

void main() {
    std::cout << "Hello, World!" << std::
}
```

Here, the compiler fully processes `iostream` (and any further headers
included), snapshots its state and proceeds with parsing the program
itself. When the user types more characters, the compiler restarts from
the point just after the include. As the size of each compilation unit
itself is usually reasonable, the analysis is fast.

在这里，编译器完全处理`iostream‘(以及任何其他头部)，对其状态进行快照，然后继续解析程序本身。当用户键入更多字符时，编译器将从恰好位于include之后的位置重新启动。由于每个编译单元本身的大小通常是合理的，因此分析速度很快。

If the user types something into the header file, then the caches need
to be invalidated. However, changes to headers are comparatively rare,
most of the code lives in `.cpp` files.

如果用户在头文件中键入内容，则需要使缓存无效。但是，标头的更改相对较少，大多数代码都位于`.cpp`文件中。

In a sense, headers correspond to the stubs of the first approach, with
two notable differences:

在某种意义上，标头对应于第一种方法的存根，有两个显著的区别：

* It’s the user who is tasked with producing a stub, not the tool.
  
  是用户负责生成存根，而不是工具。

* Unlike stubs, headers can’t be mutually recursive. Stubs store
  unresolved types, but includes can be snapshotted after complete
  analysis.
  
  与存根不同，标头不能相互递归。存根存储未解析的类型，但Include可以在完成分析后创建快照。

The two examples of this approach are
[Merlin](https://github.com/ocaml/merlin) of OCaml and
[clangd](https://clangd.llvm.org/).

这种方法的两个例子是OCaml的Merlin和clangd。

The huge benefit of this approach is that it allows re-use of an
existing batch compiler. The two other approaches described in this
article typically result in compiler re-writes. The drawback is that
almost nobody likes headers and forward declarations.

这种方法的巨大好处是它允许重用现有的批处理编译器。本文描述的另外两种方法通常会导致编译器重写。缺点是几乎没有人喜欢头部和转发声明。

# Intermission: Laziness vs Incrementality

# 中场休息：懒惰VS增量

Note how neither of the two approaches is incremental in any interesting
way. It is mostly "if something has changed, let’s clear the caches
completely". There’s a tiny bit of incrementality in the index update in
the first approach, but it is almost trivial — remove old keys, add new
keys.

请注意，这两种方法都不是以任何有趣的方式递增的。它主要是“如果有什么变化，让我们完全清除缓存”。在第一种方法中，索引更新中有一点增量，但是 - 删除旧键，添加新键几乎是微不足道的。

This is because it’s not the incrementality that makes and IDE fast.
Rather, it’s laziness — the ability to skip huge swaths of code
altogether.

这是因为让和IDE变得更快的不是增量。相反，它是懒惰(lastness - )，即完全跳过大量代码的能力。

With map-reduce, the index tells us exactly which small set of files is
used from the current file and is worth looking at. Headers shield us
from most of the implementation code.

使用map-duce，索引准确地告诉我们使用了当前文件中的哪一小部分文件，并且值得查看。标头使我们免受大部分实现代码的影响。

# Query-based Compiler

# 基于查询的编译器

Welcome to my world…​

欢迎来到我的世界…​

Rust fits the described approaches like a square peg into a round hole.

铁锈适合描述的方法，就像方形的钉子插进圆孔一样。

Here’s a small example:

下面是一个小示例：

```rust
#[macro_use]
extern crate bitflags;

bitflags! {
    struct Flags: u32 {
        const A = 0b00000001;
        const B = 0b00000010;
        const C = 0b00000100;
        const ABC = Self::A.bits | Self::B.bits | Self::C.bits;
    }
}
```

`bitflags` is macro which comes from another crate and defines a
top-level declaration. We can’t put the results of macro expansion into
the index, because it depends on a macro definition in another file. We
can put the macro call itself into an index, but that is mostly useless,
as the items, declared by the macro, would miss the index.

\`位标志`是宏，它来自另一个板条箱，定义了一个顶级声明。我们不能将宏展开的结果放入索引中，因为它依赖于另一个文件中的宏定义。我们可以将宏调用本身放入索引中，但这大多是无用的，因为宏声明的项将错过索引。

Here’s another one:

这里还有一条：

```rust
mod foo;

#[path = "foo.rs"]
mod bar;
```

Modules `foo` and `bar` refer to the same file, `foo.rs`, which
effectively means that items from `foo.rs` are duplicated. If `foo.rs`
contains the declaration `struct S;`, then `foo::S` and `bar::S` are
different types. You also can’t fit that into an index, because those
`mod` declarations are in a different file.

模块`foo`和`bar`指的是同一个文件`foo.rs`，实际上表示`foo.rs`中的项目重复。如果`foo.rs`包含声明`struct S；`，则`foo：：S`和`bar：：S`是不同的类型。您也不能将其放入索引中，因为那些‘mod`声明位于不同的文件中。

The second approach doesn’t work either. In C++, the compilation unit is
a single file. In Rust, the compilation unit is a whole crate, which
consists of many files and is typically much bigger. And Rust has
procedural macros, which means that even surface analysis of code can
take an unbounded amount of time. And there are no header files, so the
IDE has to process the whole crate. Additionally, intra-crate name
resolution is much more complicated (declaration before use vs. fixed
point iteration intertwined with macro expansion).

第二种方法也不起作用。在C++中，编译单元是单个文件。在Rust中，编译单元是一个完整的箱子，它由许多文件组成，通常要大得多。而且Rust有过程性宏，这意味着即使是代码的表面分析也会花费无限的时间。而且没有头文件，所以IDE必须处理整个机箱。此外，机箱内名称解析要复杂得多(使用前声明与与宏扩展交织在一起的定点迭代)。

It seems that purely laziness based models do not work for Rust. The
minimal feasible unit of laziness, a crate, is still too big.

似乎纯粹基于懒惰的模型不适用于Rust。懒惰的最小可行单位，一个板条箱，仍然太大了。

For this reason, in rust-analyzer we resort to a smart solution. We
compensate for the deficit of laziness with incrementality.
Specifically, we use a generic framework for incremental
computation — [salsa](https://github.com/salsa-rs/salsa).

为此，在防锈分析仪中，我们采用了一种聪明的解决方案。我们用增量来弥补懒惰的不足。具体地说，我们使用一个用于增量计算的通用框架 - SALSA。

The idea behind salsa is rather simple — all function calls inside the
compiler are instrumented to record which other functions were called
during their execution. The recorded traces are used to implement
fine-grained incrementality. If after modification the results of all of
the dependencies are the same, the old result is reused.

SALSA背后的思想相当简单， - 编译器内的所有函数调用都会被检测，以记录哪些其他函数在执行期间被调用。记录的轨迹用于实现细粒度增量。如果修改后所有依赖项的结果都相同，则重用旧结果。

There’s also an additional, crucial, twist — if a function is
re-executed due to a change in dependency, the new result is compared
with the old one. If despite a different input they are the same, the
propagation of invalidation stops.

还有一个额外的、至关重要的扭曲函数(twist - )，如果一个函数由于依赖关系的改变而重新执行，新的结果将与旧的结果进行比较。如果尽管有不同的输入，但它们是相同的，则无效的传播将停止。

Using this engine, we were able to implement a rather fancy update
strategy. Unlike the map reduce approach, our indices can store resolved
types, which are invalidated only when a top-level change occurs. Even
after a top-level change, we are able to re-use results of most macro
expansions. And typing inside of a top-level macro also doesn’t
invalidate caches unless the expansion of the macro introduces a
different set of items.

使用这个引擎，我们能够实现一个相当奇特的更新策略。与map Reduce方法不同，我们的索引可以存储解析类型，只有在顶级更改发生时，这些类型才会失效。即使在顶层变更之后，我们也能够重用大多数宏观扩张的结果。并且，在顶级宏中键入也不会使缓存无效，除非宏的展开引入了一组不同的项。

The main benefit of this approach is generality and correctness. If you
have an incremental computation engine at your disposal, it becomes
relatively easy to experiment with the way you structure the
computation. The code looks mostly like a boring imperative compiler,
and you are immune to cache invalidation bugs (we had one, due to
procedural macros being non-deterministic).

这种方法的主要优点是通用性和正确性。如果您可以使用增量计算引擎，那么尝试构建计算的方式就会变得相对容易。代码看起来很像一个乏味的命令式编译器，您不会受到缓存无效错误的影响(我们有一个错误，因为过程性宏是不确定的)。

The main drawback is extra complexity, slower performance (fine-grained
tracking of dependencies takes time and memory) and a feeling that this
is a somewhat uncharted territory yet :-)

主要缺点是额外的复杂性、较慢的性能(细粒度跟踪依赖项需要时间和内存)，并且给人的感觉是这在某种程度上还是一个未知的领域：-)

# Links

# 链接

How IntelliJ works  
[https://jetbrains.org/intellij/sdk/docs/basics/indexing_and_psi_stubs.html](https://jetbrains.org/intellij/sdk/docs/basics/indexing_and_psi_stubs.html)

IntelliJ如何工作https://jetbrains.org/intellij/sdk/docs/basics/indexing_and_psi_stubs.html

How Sorbet works  
[https://www.youtube.com/watch?v=Gdx6by6tcvw](https://www.youtube.com/watch?v=Gdx6by6tcvw)

冰糕是如何工作的https://www.youtube.com/watch?v=Gdx6by6tcvw

How clangd works  
[https://clangd.llvm.org/design/](https://clangd.llvm.org/design/)

CLANGD如何工作https://clangd.llvm.org/design/

How Merlin works  
[https://arxiv.org/abs/1807.06702](https://arxiv.org/abs/1807.06702)

梅林如何工作https://arxiv.org/abs/1807.06702

How rust-analyzer works  
[https://github.com/rust-analyzer/rust-analyzer/tree/master/docs/dev](https://github.com/rust-analyzer/rust-analyzer/tree/master/docs/dev)

https://github.com/rust-analyzer/rust-analyzer/tree/master/docs/dev防锈分析仪的工作原理