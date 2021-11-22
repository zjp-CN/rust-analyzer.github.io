rust-analyzer is a new "IDE backend" for the
[Rust](https://www.rust-lang.org/) programming language. Support
rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/).

铁锈分析器是铁锈编程语言的一个新的“IDE后端”。支持Open Collective上的防锈分析仪。

During the past several months, I’ve been swamped with in-the-trenches
rust-analyzer work. Today, I spontaneously decided to take a step back
and think about longer-term "road map" for rust-analyzer.

在过去的几个月里，我一直忙于战壕内的铁锈分析器工作。今天，我不由自主地决定退一步，想一想生锈分析仪更长远的“路线图”。

What follows is my ([@matklad](https://github.com/matklad/)) personal
thoughts on the matter, they not necessary reflect the consensus view of
ide or compiler teams :-)

以下是我(@matklad)对此事的个人想法，它们不一定反映ide或编译团队的共识观点：-)

# Unexpected Success

# 意想不到的成功

One of the most surprising aspects of rust-analyzer for me is how useful
it already is. Today, I write Rust code enjoying fast code-completion,
mostly correct go to definition and plethora of assists. Even syntax
highlighting inside macros works!

对我来说，铁锈分析仪最令我惊讶的一个方面是它的用处如此之大。今天，我编写了Rust代码，享受着快速的代码完成、大部分正确的Go to Definition和过多的帮助。即使宏内的语法突出显示也有效！

My original plan for rust-analyzer was to write a quick one-to-two-year
hack to demonstrate a proof-of-concept IDE support, something to strive
for rather than a finished product. Obviously, we have massively
overshot this goal: people depend on rust-analyzer for productive Rust
programming today. This creates its own opportunities and dangers, which
inform this planning document.

我对锈蚀分析器的最初计划是快速编写一到两年的技巧，以演示概念验证IDE支持，这是一个值得努力的东西，而不是一个成品。显然，我们在很大程度上超越了这个目标：今天，人们依赖锈蚀分析器进行生产性的锈蚀编程。这就创造了它自己的机会和危险，这就是这份规划文件的内容。

# Official LSP Server

# 官方LSP服务器

People write a ton of Rust today, and they deserve at least a baseline
level of IDE support. I think our immediate goal is to make
rust-analyzer easier to use in its current state, effectively
implementing [RFC2912](https://github.com/rust-lang/rfcs/pull/2912).

今天，人们编写了大量的铁锈代码，他们至少应该得到基线级别的IDE支持。我认为我们当前的目标是使锈检分析仪在目前的状态下更容易使用，有效地实施RFC2912。

The amount of programming work on rust-analyzer side is relatively small
here: we need to fix various protocol conformance issues, clean up
various defaults to be less experimental, write documentation which
doesn’t require a lot of enthusiasm to understand, etc. The amount of
org stuff is much bigger — we need to package rust-analyzer with rustup,
merge the RLS and rust-analyzer VS Code extensions, figure out
repository structure, etc.

在锈蚀分析器方面的编程工作量在这里相对较小：我们需要修复各种协议一致性问题，清理各种缺省值以减少实验性，编写不需要太多热情来理解的文档，等等。组织人员的数量要大得多，我们需要将Ruust-Analyzer与Rustup打包在一起，合并 - 和Ruust-Analyzer VS代码扩展，找出存储库结构，等等。

Separately, I want to make sure that rust-analyzer is usable inside
large non-Cargo based monorepos. We have some initial support for this
already, but there’s a bunch of details we need to iron out.

另外，我想确保防锈分析仪可以在大型非货运型单货站内使用。我们对此已经有了一些初步的支持，但还有一堆细节需要我们敲定。

# Dangers of Accidental Architecture

# 意外建筑的危险

The main danger I see is that rust-analyzer can ossify in its present
state. This would be bad, because, although current rust-analyzer
architecture is right in broad strokes, a lot of important and
hard-to-change details are wrong. After we push rust-analyzer to the
general public, we should focus on boring implementation & design work,
with relatively few shiny gifs and a lot of foundational work for the
next decade.

我看到的主要危险是，在目前的状态下，铁锈分析仪可能会僵化。这将是不好的，因为尽管目前的锈蚀分析仪架构大体上是正确的，但许多重要的和难以更改的细节是错误的。在我们将锈蚀分析仪推向大众之后，我们应该把重点放在枯燥的实现和设计工作上，相对较少的闪亮的GIF和大量的基础工作是下一个十年的工作。

# Bringing Chalk to Rustc

# 让粉笔生锈

rust-analyzer has been using chalk as its trait solver for a long time
now. It would be good to finish the work, and integrate it into rustc as
well, <span class="line-through">and give people their GATs</span>.

生锈分析仪长期以来一直使用粉笔作为其特性解算器。如果完成这项工作，并将其集成到Rustc中，并给人们他们的Gats，那将是一件很好的事情。

# Single Parser and Syntax Tree

# 单个解析器和语法树

We should share the parser between rustc and rust-analyzer already.
Parsing is one of the most interesting bits of the compiler, from the
IDE point of view. By transitioning rustc to a lossless syntax we’ll
cross the most important barrier, and it will be a downhill road from
that point on. The design space here I think is well-understood, but the
amount of work to do is large. At some point, I should take a break from
actively hacking on rust-analyzer and focus on sharing the parser.

我们应该已经在rustc和ruust分析器之间共享解析器了。从IDE的角度来看，解析是编译器最有趣的部分之一。通过将Rustc转换为无损语法，我们将跨越最重要的屏障，从那时起这将是一条下坡路。我认为这里的设计空间是众所周知的，但要做的工作量很大。在某种程度上，我应该暂时不再积极破解锈蚀分析器，而是专注于共享解析器。

# Virtual File System

# 虚拟文件系统

The most fundamental data structure in rust-analyzer, even more
fundamental than a syntax tree, is the VFS, or Virtual File System. It
serves two dual goals:

锈蚀分析器中最基本的数据结构，甚至比语法树更基本的数据结构是VFS，即虚拟文件系统。它有两个双重目标：

* providing consistent immutable snapshots of the file system,
  
  提供文件系统的一致的、不变的快照，

* applying transactional changes to the state of the file system.
  
  将事务性更改应用于文件系统的状态。

This abstraction is the boundary between the pure-functional universe of
rust-analyzer, and the messiness of the external world. It needs to
bridge case-insensitive file systems, symlinks and cycles to a simpler
model of "tree with utf8 paths" we want inside. Additionally it should
work with non-path files: there are use-cases where we want to do
analysis of Rust code, which doesn’t really reside on the file system.

这种抽象是锈检仪器的纯功能宇宙与外部世界的杂乱之间的分界线。它需要将不区分大小写的文件系统、符号链接和循环连接到我们想要的更简单的“带有UTF8路径的树”模型。此外，它应该与非路径文件一起工作：在某些用例中，我们想要分析Rust代码，而这些代码并不真正驻留在文件系统中。

One specific aspect I am struggling with is dynamism. On the one hand,
it seems that a good design is to require to specify the set of files in
VFS upfront, as a set of globs. This is important because, to properly
register file watchers without losing updates, you need to crawl the
file-system eagerly. However, specifying a set of globs up-front makes
changing this set later messy.

我正在努力解决的一个具体方面是活力。一方面，似乎一个好的设计是要求预先将VFS中的文件集指定为一组GLOB。这一点很重要，因为要在不丢失更新的情况下正确注册文件监视器，您需要急切地爬行文件系统。但是，预先指定一组GLOB会使稍后更改该组变得混乱。

I would be curious to hear about existing solutions in this area. One
specific question I have is: "How does watchman handle dynamic
addition/removal of projects?". If you have any experience to share,
please comment on the VFS issue in rust-analyzer. Ideally, we turn VFS
into just a crates.io crate, as it seems generally useful, and can
encapsulate quite a bit of complexity.

我很想听听这一领域现有的解决方案。我有一个具体的问题：“看守人如何处理项目的动态添加/删除？”如果您有什么经验可以分享，请您对防锈分析仪中的VFS问题发表意见。理想情况下，我们将VFS转换为crates.io机箱，因为它似乎通常很有用，并且可以封装相当多的复杂性。

The current VFS is …​ not great, I don’t feel comfortable building
rust-analyzer on top of it.

当前vfs为…​不太好，我不喜欢在上面建生锈分析仪。

# WASM proc macros

# WASM过程宏

At the moment, proc-macros are implemented as dynamic libraries,
loadable into the compiler process. This works ok-enough for the
compiler, but is a pretty bad fit for an IDE:

目前，proc-宏是作为动态库实现的，可以加载到编译器进程中。这可以很好地工作-对于编译器来说已经足够了，但是对于IDE来说就相当不合适了：

* if a proc-macro crashes, it brings down the whole process,
  
  如果前置宏崩溃，整个过程就会中断，

* it’s hard to limit execution time of proc-macro,
  
  很难限制proc-宏执行时间，

* proc-macros can be non-deterministic, which breaks internal IDE
  invariants.
  
  proc-宏可以是非确定性的，这会破坏内部IDE不变量。

At the moment, we paper over this by running proc-macros in a separate
process and never invalidating proc-macro caches, but this feels like a
hack and has high implementation complexity. it would be much better if
proc-macros were deterministic and controllable by definition, and WASM
can give us that.

目前，我们通过在单独的进程中运行proc-宏来掩盖这一点，并且永远不会使proc-宏缓存无效，但这感觉像是一次黑客攻击，并且具有很高的实现复杂性。如果proc-宏按照定义是确定性和可控性的，那就更好了，而WASM可以为我们提供这一点。

I am slightly worried that this will get push-back from folks who want
to connect to databases over TCP at compile time :) Long term, I believe
that guaranteeing deterministic compilation is hugely important,
irrespective of IDE story.

我有点担心这会受到那些希望在编译时通过TCP连接到数据库的人的反对：)从长远来看，我认为保证确定性编译是非常重要的，不管IDE的情况如何。

# Language Design for Locality

# 面向地方的语言设计

There’s a very important language property that an IDE can leverage to
massively improve performance:

IDE可以利用一个非常重要的语言属性来大幅提高性能：

*What happens inside a function, stays inside the function*

函数内部发生的事情停留在函数内部

If it is possible to type-check the body of a function without looking
at the bodies of other functions, you can speed up an IDE by drastically
reducing the amount of work it needs to do.

如果可以在不查看其他函数体的情况下对函数体进行类型检查，则可以通过大幅减少需要执行的工作量来加快IDE的运行速度。

Rust mostly conforms to this property, but there are a couple of
annoying violations:

铁锈基本上符合这一属性，但也有几个恼人的违规行为：

* local inherent impls with publicly visible methods.
  
  具有公开可见方法的本地固有隐式。

* local trait impls for non-local types.
  
  局部特征隐含于非局部类型。

* `#[macro_export]` local macros.
  
  \`#[MACRO_EXPORT]`本地宏。

* local out-of-line modules.
  
  本地离线模块。

If we want to have fast & correct IDE support, we should phase out those
from the language via edition mechanism.

如果我们想要快速而正确的IDE支持，我们应该通过版本机制逐步将其从语言中淘汰出来。

Note that auto-trait leakage of impl Trait is not nearly as problematic,
as you only need to inspect a function’s body if you call the function.
Of course, as an IDE author I’d love to require specifying auto-traits,
but, as a language user, I much prefer the current design.

请注意，Iml特征的自动特征泄漏问题不大，因为如果调用函数，您只需要检查函数的主体。当然，作为一名IDE作者，我希望要求指定自动特性，但作为一名语言用户，我更喜欢当前的设计。

# Compact Data Structures

# 紧凑的数据结构

rust-analyzer uses a novel and rather high-tech query-based architecture
for incremental computation. Today, it is clear that this general
approach fits an IDE use-case really well. However, I have a lot of
doubts about specific details. I feel that today rust-analyzer lacks
mechanical sympathy and leaves a ton of performance on the table. A lot
of internal data structures are heap-allocated `Arc`-droplets, we
overuse hashing and underuse indexing, we don’t even intern identifiers!

Ruust-Analyzer采用了一种新颖的、相当高科技的基于查询的体系结构来进行增量计算。今天，很明显，这种通用方法非常适合IDE用例。不过，我对具体细节有很多疑问。我觉得今天的铁锈分析仪缺乏机械上的同情心，留下了大量的性能。很多内部数据结构都是堆分配的‘Arc`-drops，我们过度使用散列而不充分使用索引，我们甚至没有内部标识符！

To get a feeling of how blazingly fast compiler front-ends can be, I
highly recommend checking out Sorbet, type checker for Ruby. You can
start with these two links:

要了解编译器前端的速度有多快，我强烈推荐使用Ruby的类型检查器Sorbet。您可以从以下两个链接开始：

* [https://blog.nelhage.com/post/why-sorbet-is-fast/](https://blog.nelhage.com/post/why-sorbet-is-fast/)
  
  https://blog.nelhage.com/post/why-sorbet-is-fast/

* [https://www.youtube.com/watch?v=Gdx6by6tcvw](https://www.youtube.com/watch?v=Gdx6by6tcvw)
  
  https://www.youtube.com/watch?v=Gdx6by6tcvw

I am very inspired by this work, but also embarrassed by how far
rust-analyzer is from that kind of raw performance and simplicity.

这项工作给了我很大的启发，但也让我感到尴尬的是，生锈分析仪与那种原始的性能和简单性相去甚远。

Part of that I think is essential complexity — Rust’s name resolution
and macro expansion are **hard**. But I also wonder if we can change
salsa to use `Vec`-based arenas, rather than `Arc`s in `HashMap`s.

我认为部分原因是本质上的复杂性， - Rust的名称解析和宏观扩展都很困难。但我也想知道，我们是否可以将Salsa改为使用基于“Vec`”的竞技场，而不是使用“HashMaps”中的“Arc”。

# Parallel and Fast \> Persistence

# 并行和快速>持久性

One of the current peculiarities of rust-analyzer is that it doesn’t
persist caches to disk. Opening project in rust-analyzer means waiting a
dozen seconds while we process standard library and dependencies.

防锈分析器目前的一个特点是它不会将缓存持久保存到磁盘上。在锈蚀分析器中打开项目意味着在我们处理标准库和依赖项时等待十几秒钟。

I think this "limitation" is actually a very valuable asset! It forces
us to keep the non-incremental code-path reasonably fast.

我觉得这个“极限”其实是很有价值的资产！它迫使我们保持非增量代码路径相当快。

I think it is plausible that we don’t actually need persistent caches at
all. rust-analyzer is basically text processing, and the size of input
is in tens of megabytes (*and* we ignore most of those megabytes
anyway). If we just don’t lose performance here and there, and throw the
work onto all the cores, we should be able to load projects from scratch
within a reasonable time budget.

我认为我们实际上根本不需要持久缓存，这似乎是合理的。锈蚀分析器基本上是文本处理，输入的大小是几十兆字节(无论如何，我们忽略了这些兆字节中的大部分)。如果我们不在这里和那里降低性能，并将工作放在所有核心上，我们应该能够在合理的时间预算内从头开始加载项目。

The first step here would be establishing the culture of continuous
benchmarking and performance tuning.

这里的第一步将是建立持续基准和性能调优的文化。

We’ve already successfully used rust-analyzer for forging an
architecture which works in IDE at all. Now it’s time to experiment with
architecture which works, *fast*, just as all Rust code should :-)

我们已经成功地使用锈蚀分析仪锻造了一个可以在IDE中工作的体系结构。现在是时候尝试快速工作的体系结构了，就像所有Rust代码应该做的那样：-)

# Optimizing Build Times

# 优化构建时间

In my opinion the two important characteristics that determine long-term
success of a project are:

在我看来，决定项目长期成功的两个重要特征是：

* How long does it take to execute most of the tests?
  
  执行大部分测试需要多长时间？

* How long does it take to build a release version of the project for
  testing?
  
  构建用于测试的项目的发布版本需要多长时间？

I am very happy with the testing speed of rust-analyzer. One of my
mistakes in IntelliJ was adding a lot of tests that use Rust’s standard
library and are slow for that reason. In rust-analyzer, there are only
three uber-integrated tests that need the real libstd, all others work
from in-memory fixtures which contain only the relevant bits of std.

我对测锈仪的检测速度很满意。我在IntelliJ中的一个错误是添加了许多使用Rust的标准库的测试，因此速度很慢。在锈蚀分析仪中，只有三个超级集成的测试需要真正的libstd，所有其他的测试都是从只包含相关STD位的内存装置中进行的。

But the build times leave a lot to be desired. And this is hugely
important — the faster you can build the code, the faster you can do
everything else. Heck, even for improving build times you need fast
build times! I was trying to do some compile-time optimizations in
rust-analyzer recently, and measuring “is it faster to compile now?”
takes a lot of time, so one has to try fewer different optimizations!

但构建时间还有很多不尽如人意之处。这一点非常重要， - 构建代码的速度越快，做其他事情的速度也就越快。见鬼，即使为了改善构建时间，您也需要快速的构建时间！最近，我试图在锈蚀分析器中进行一些编译时优化，并测量“现在编译速度更快吗？”需要很长时间，所以只需尝试较少的不同优化！

The biggest problem here is that Rust, as a language, is hard to compile
fast. One specific issue I hit constantly is that changing a deep
dependency recompiles the world. This is in contrast to C/C++ where, if
you don’t touch any `.h` files, changing a dependency requires only
re-linking. In theory, we can have something like this in Rust, by
automatically deriving public headers from crates. Though I fear that
without explicit, physical “this is ABI” boundary, it will be much less
effective at keeping compile times under control.

这里最大的问题是，Rust作为一种语言，很难快速编译。我经常遇到的一个具体问题是，更改深度依赖关系会重新编译世界。这与C/C++相反，在C/C++中，如果您不接触任何`.h`文件，更改依赖项只需要重新链接。理论上，通过自动从板条箱派生公共标题，我们可以在Rust中拥有类似的东西。虽然我担心如果没有明确的、物理的“这就是ABI”边界，它在控制编译时间方面的效率会低得多。

As an aside, if Rust stuck with `.crate` files, implementing IDE support
would have been much easier :-)

顺便说一句，如果Rust坚持使用`.crate`文件，实现IDE支持会容易得多：-)

# Optimizing rustc Build

# 优化Rustc构建

Nonetheless, rust-analyzer is much easier to build than rustc. I believe
there’s a lot we can do for rustc build as well.

尽管如此，生锈分析仪比生锈分析仪更容易制造。我相信我们也可以为Rustc Build做很多事情。

I’ve written at length about this on
[irlo](https://internals.rust-lang.org/t/experience-report-contributing-to-rust-lang-rust/12012/17?u=matklad).
The gist is that I think we can split rustc into a front-end
"text-processing" part, and backend "LLVM, linkers and real world" part.
The front bit then could, in theory, be a bog standard Rust project,
which doesn’t depend on IO, external tools or C++ code at all.

关于这一点，我在irlo上已经写了很长时间。要点是，我认为我们可以将rustc拆分成前端的“文本处理”部分和后端的“LLVM、链接器和现实世界”部分。从理论上讲，前面的部分可以是一个BOG标准的Rust项目，它完全不依赖IO、外部工具或C++代码。

One wrinkle here is that rustc test suite at the moment consists
predominantly of UI and run-pass tests integration, which work by
building the whole compiler. Such a test suite is ideal for testing
conformance and catching regressions, but is not really well suited for
rapid TDD. I think we should make an effort to build a unit test suite
a-la rust-analyzer, such that it’s easy, for example, to test name
resolution without building the type checker, and which doesn’t require
stdlib.

这里的一个问题是，rustc测试套件目前主要由UI和Run-pass测试集成组成，它们通过构建整个编译器来工作。这样的测试套件非常适合测试一致性和捕获回归，但不太适合快速TDD。我认为我们应该努力构建一个类似于锈蚀分析器的单元测试套件，这样就可以很容易地测试名称解析，而不需要构建类型检查器，而且不需要stdlib。

# Scaling Maintainance

# 扩展维护

Finally, all changes here represent deep cuts into an existing body of
software. Pushing such ambitious projects to completion require people,
who can dedicate significant amounts of their time and energy. To put it
bluntly, we need more dedicated folks working on the IDE tooling as a
full time, paid job. I am grateful to my colleagues at [Ferrous
Systems](https://ferrous-systems.com/) who put a lot of energy into
making this a reality.

最后，这里的所有更改都代表着对现有软件主体的深度削减。推动这些雄心勃勃的项目完成需要人们，他们可以投入大量的时间和精力。直截了当地说，我们需要更多专注于IDE工具的人作为一份全职的有偿工作。我很感谢我在铁业系统公司的同事们，他们为实现这一目标投入了大量精力。

If you find rust-analyzer useful and use it professionally, please
consider asking your company to sponsor rust-analyzer via our [Open
Collective](https://opencollective.com/rust-analyzer/). Sponsorships
from individuals are also accepted (and greatly appreciated!).

如果您觉得铁锈分析仪很有用，并且是专业使用的，请考虑通过我们的Open Collective向贵公司申请赞助铁锈分析仪。来自个人的赞助也被接受(并非常感谢！)