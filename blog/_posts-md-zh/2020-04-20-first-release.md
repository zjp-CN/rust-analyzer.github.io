I am pleased to announce the first alpha release of rust-analyzer — a
new "IDE backend" for the [Rust](https://www.rust-lang.org/) programming
language. Support rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/).

我很高兴宣布锈蚀分析器 - 的第一个Alpha版本，它是一个用于锈蚀编程语言的新的“集成开发环境后端”。支持Open Collective上的防锈分析仪。

Wait a second…​ Haven’t people been using rust-analyzer for a long time
now? Well, yes, but we’ve never actually made a release announcement, so
here’s one! Better late than never :-)

等待第二个…​现在人们不是已经用了很长时间了吗？嗯，是的，但是我们实际上从来没有发布过公告，所以这里有一个！迟到总比不到好：-)

# What exactly is rust-analyzer?

# 什么是防锈分析仪？

Broadly speaking, rust-analyzer is a new compiler front-end for the Rust
programming language, aimed at drastically improving IDE integration. If
you are familiar with C# ecosystem, rust-analyzer is to rustc what
[Roslyn](https://github.com/dotnet/roslyn) is to the original C#
compiler.

一般而言，RUST分析器是RUST编程语言的一个新的编译器前端，旨在极大地改进IDE集成。如果您熟悉C#生态系统，那么Ruust-Analyzer之于Rustc就像Roslyn之于原始C#编译器一样。

More specifically the goal of rust-analyzer project is improving Rust
IDE support to the standard expected of a modern language. Under this
umbrella project the following activities take place:

更具体地说，Rust-Analyzer项目的目标是将Rust IDE支持提高到现代语言所期望的标准。在这一总括项目下，开展了以下活动：

* We build the `rust-analyzer` binary, an implementation of the
  [language server
  protocol](https://microsoft.github.io/language-server-protocol/),
  which can provide a basic IDE experience for Rust today.
  
  我们构建了‘rust-analyzer’二进制文件，这是语言服务器协议的一个实现，它可以为今天的Rust提供基本的IDE体验。

* We use `rust-analyzer` as a workbench and a laboratory for
  investigating approaches to lazy and incremental compilation.
  
  我们使用“rust-analyzer”作为研究懒惰和增量编译方法的工作台和实验室。

* We try to modularize the existing `rustc` compiler and extract
  **production ready** components for sharing with `rust-analyzer`.
  
  我们尝试将已有的`rustc`编译器模块化，提取可投入生产的组件与`rustanalyzer`共享。

For the users, the most immediately relevant facet is the first one — a
language server you can install to get smart code completion in <span
class="line-through">Emacs</span> your favorite editor. This is what
this post focuses on.

对于用户来说，最直接相关的方面是第一个 - 语言服务器，您可以安装它来在Emacs中获得您最喜欢的编辑器中的智能代码完成。这就是这篇文章关注的重点。

# What is its relationship with RLS?

# 它与RLS有什么关系？

Rust had a language server for quite some time now — the
[RLS](https://github.com/rust-lang/rls). RLS and rust-analyzer use
fundamentally different architectures for understanding Rust. RLS works
by running a compiler on the whole project and dumping a huge JSON file
with facts derived during the compilation process. rust-analyzer works
by maintaining a persistent compiler process, which is able to analyze
code on-demand as it changes. Concretely, after every keystroke RLS
looks at every function body and re-typechecks it; rust-analyzer
generally processes only the code in the currently opened file(s),
reusing name resolution results if possible.

Rust有语言服务器已经有很长一段时间了，现在 - RLS。RLS和铁锈分析仪使用完全不同的体系结构来理解铁锈。RLS的工作方式是在整个项目上运行编译器，并转储一个巨大的JSON文件，其中包含在编译过程中派生的事实。Ruust-Analyzer的工作方式是维护一个持久的编译器进程，该进程能够在代码更改时按需分析代码。具体地说，在每次击键之后，RLS都会查看每个函数体并对其进行重新类型检查；锈蚀分析器通常只处理当前打开的文件中的代码，如果可能的话，会重用名称解析结果。

rust-analyzer started as an experiment and a proof-of-concept, but today
it is becoming increasingly clear that:

铁锈分析仪最初只是一项实验和概念验证，但今天越来越清楚的是：

* rust-analyzer already provides a better experience than RLS for many
  users.
  
  铁锈分析仪已经为许多用户提供了比RLS更好的体验。

* rust-analyzer is further ahead on the road towards the envisioned
  end-state of a fully on-demand, fully incremental Rust compiler.
  
  铁锈分析器在通往完全按需、完全增量的铁锈编译器的设想最终状态的道路上走得更远。

So we’ve opened [RFC 2912](https://github.com/rust-lang/rfcs/pull/2912).
That RFC proposes a process of replacing RLS with rust-analyzer as the
official LSP implementation for Rust.

所以我们开通了RFC2912。RFC提出了一种用锈蚀分析器取代RLS的过程，作为RUST的官方LSP实现。

# What is its relationship with IntelliJ Rust?

# 它与IntelliJ Rust有什么关系？

[IntelliJ Rust](https://intellij-rust.github.io/) is a plugin providing
Rust support for IDEs build on top of [IntelliJ
Platform](https://www.jetbrains.com/opensource/idea/). The rust-analyzer
project is indebted to IntelliJ Rust: it builds on the same
architectural ideas and patterns, and is directly inspired by the
experience of developing IntelliJ Rust.

IntelliJ Rust是一个插件，为构建在IntelliJ平台之上的IDE提供Rust支持。铁锈分析器项目得益于IntelliJ Rust：它建立在相同的架构思想和模式之上，并且直接受到IntelliJ Rust开发经验的启发。

IntelliJ Rust contains its own implementation of an IDE-ready compiler
frontend, implemented in Kotlin. This engine is very advanced, but, by
design, does not use LSP. IntelliJ Rust is a production ready Rust IDE
and is wholly recommended for users of JetBrains' products.

IntelliJ Rust包含它自己的IDE就绪编译器前端的实现，用Kotlin实现。这款引擎非常先进，但在设计上不使用LSP。IntelliJ Rust是一款可投入生产的Rust IDE，完全推荐给JetBrains产品的用户。

# Quick Start

# 快速入门

[The manual](https://rust-analyzer.github.io/manual.html) contains
detailed documentation, so in this blog post I want to just quickly run
through the most exciting features.

该手册包含详细的文档，因此在这篇博客文章中，我只想快速浏览一下最激动人心的功能。

rust-analyzer is compatible with any editor that supports LSP, and has
dedicated plugins for
[Vim](https://github.com/fannheyward/coc-rust-analyzer),
[Emacs](https://github.com/emacs-lsp/lsp-mode/blob/3d6283f936dff2098e36b149fc414ea7acd332c8/lsp-rust.el)
and [VS
Code](https://github.com/rust-analyzer/rust-analyzer/tree/4a250021b1a1def483f7faf2b534ec4dd7defd02/editors/code).
Support for VS Code is maintained in-tree and in general is expected to
be the most complete. For this reason, the following info takes a VS
Code-centric point of view, but should be translatable to equivalent
concepts in other editors.

锈蚀分析器与任何支持LSP的编辑器兼容，并且有专门的Vim、Emacs和VS代码插件。对VS代码的支持是在树中维护的，通常预计是最完整的。出于这个原因，下面的信息采用了以代码为中心的观点，但是应该可以翻译成其他编辑器中的等效概念。

To add rust-analyzer to VS Code:

要将防锈分析仪添加到VS代码中，请执行以下操作：

* Remove existing rls extension, if you have one.
  
  删除现有的RLS扩展(如果有)。

* Install the [rust-analyzer
  extension](https://marketplace.visualstudio.com/items?itemName=matklad.rust-analyzer)
  from the marketplace.
  
  从市场上安装防锈分析仪扩展件。

To check that everything is working open a "Hello World" Rust
application. You should see the `Run | Debug` code lens, and editor
symbols should show the main function:

要检查一切是否正常，请打开“Hello World”Rust应用程序。您应该会看到`Run|Debug`代码镜头，编辑器符号应该显示主函数：

![80090876 7b49a500 8560 11ea 8abc
b4b5f786c026](https://user-images.githubusercontent.com/1711539/80090876-7b49a500-8560-11ea-8abc-b4b5f786c026.png)

80090876 7b49a500 8560 11ea 8abc b4b5f786c026

# Features

# 功能

Now that rust-analyzer is successfully installed, what are some of the
most important features?

既然已经成功安装了防锈分析仪，那么最重要的功能有哪些呢？

I suggest, first and foremost, to familiarize oneself with many
**navigation** capabilities, as we spend more time reading code than
writing it. Here’s an inexhaustive list of features.

我建议，首先也是最重要的，熟悉许多导航功能，因为我们花在阅读代码上的时间比编写代码的时间要多。下面是一个无穷无尽的功能列表。

Definition F12  
The most famous navigation shortcut. One rust-analyzer specific trick is
that F12 on an `mod submodule;` brings you to the `submodule.rs` file.
This is useful in combination with:

定义F12，最著名的导航快捷方式。锈蚀分析器特有的一个诀窍是，在`mod子模块；`上按F12键会将您带到`submodule e.rs`文件。这在与以下各项结合使用时非常有用：

Parent module (no default keybinding)  
This action brings to the `mod` declaration which declared the current
module. It doesn’t have a shortcut assigned by default, as there’s no
corresponding built-in action, but it is highly recommended to assign
one.

父模块(无缺省键绑定)此操作将带到声明当前模块的`mod`声明。默认情况下，它没有分配快捷键，因为没有对应的内置操作，但强烈建议您分配一个快捷键。

Workspace Symbol <span class="keycombo">Ctrl+T</span>
  
This is probably the shortcut I use most often. It is a fuzzy-search
interface for all "symbols" (structs, enums, functions, field) in the
project, its dependencies and the standard library. The search tries to
be smart, in that, by default, it looks only for types in your project,
and, failing that, for functions. It is possible to force search in
dependencies by adding `#` to the query string, and search for all
symbols by adding `*`. Unfortunately, this doesn’t work in VS Code at
the moment, as it stopped passing these symbols to the language server
since the last update.

工作空间符号Ctrl+T这可能是我最常用的快捷键。它是一个模糊搜索接口，用于项目中的所有“符号”(结构、枚举、函数、字段)、其依赖项和标准库。搜索尽量做到智能，因为默认情况下，它只查找项目中的类型，如果做不到这一点，则只查找函数。可以通过在查询字符串中添加`#`来强制搜索依赖项，也可以通过添加`*`来搜索所有符号。不幸的是，这目前在VS代码中不起作用，因为自从上次更新以来，它停止将这些符号传递给语言服务器。

<!-- -->

Document Symbol <span class="keycombo">Ctrl+Shift+O</span>
  
Like workspace symbol, but for things in the current file. The same
underlying LSP request powers file outline and breadcrumbs.

文档元件Ctrl+Shift+O类似于工作区元件，但适用于当前文件中的内容。相同的底层LSP请求支持文件大纲和面包屑。

![80090645 1e4def00 8560 11ea 901d
d1cdc0ab8f50](https://user-images.githubusercontent.com/1711539/80090645-1e4def00-8560-11ea-901d-d1cdc0ab8f50.png)

80090645 1e4def008560 11ea 901d d1cdc0ab8f50

Implementation <span class="keycombo">Ctrl+F12</span>
  
This shortcut works on structs, enums and traits, and will show you the
list of corresponding impls.

实现Ctrl+F12此快捷方式适用于结构、枚举和特征，并将向您显示相应的隐式列表。

Syntax Highlighting  
While not exactly about navigation, semantic syntax highlighting helps
with reading code. Rust analyzer underlines mutable variables,
distinguishes between modules, traits and types and provides helpful
type and parameter hints.

语法突出显示虽然不完全与导航有关，但语义语法突出显示有助于阅读代码。锈蚀分析仪在可变变量下划线，区分模块、特征和类型，并提供有用的类型和参数提示。

![80091615 b5677680 8561 11ea 82de
e1517e4fef18](https://user-images.githubusercontent.com/1711539/80091615-b5677680-8561-11ea-82de-e1517e4fef18.png)

80091615 b5677680 8561 11ea 82de e1517e4fef18

Run (no default keybinding)  
After navigation, the feature I use most is probably the **Run** button.
This action runs the test function, test module or main function at the
given cursor position. It is also available as a code-lens, but I
personally exclusively use <span class="keycombo">ctrl+r</span> for it,
as I need this action all the time. What’s more, with a short cut you
can re-run the last command, which is hugely useful when you are
debugging a failing test. This action is pretty smart in that it does
the following things for you:

Run(无缺省键绑定)导航后，我最常用的功能可能是Run按钮。此操作在给定光标位置运行测试函数、测试模块或主函数。它也可以作为代码镜头使用，但我个人只使用ctrl+r，因为我一直需要这个动作。更重要的是，您可以通过快捷方式重新运行最后一个命令，这在调试失败的测试时非常有用。此操作非常聪明，因为它为您做了以下事情：

* determines the appropriate `--package` argument for `Cargo`,
  
  为`Cargo`确定适当的`_Package`自变量，

* uses the full path to the test, including the module,
  
  使用测试的完整路径，包括模块，

* sets the `--no-capture` argument, so that debug prints are visible,
  
  设置`--no-capture`参数，以便调试打印可见。

* sets the `RUST_BACKTRACE` environmental variable, so that you don’t
  have to re-run on panic.
  
  设置`RUST_BACKTRACE`环境变量，这样您就不必在死机时重新运行。

Sadly, such context-dependent run configurations are not a part of the
LSP protocol yet, so this feature is implemented using a custom protocol
extension.

遗憾的是，这种上下文相关的运行配置还不是LSP协议的一部分，因此此功能是使用自定义协议扩展实现的。

Punctuation-aware code completion  
Naturally, rust-analyzer helps with writing code as well. When
completing `return`, it checks if the return type is `()`. When
completing function and method calls, `rust-analyzer` places the cursor
between parentheses, unless the function has zero arguments. When typing
`let`, rust-analyzer tries to helpfully add the semicolon.

支持标点符号的代码自动补全自然，锈蚀分析器也有助于编写代码。在完成`rereturn`时，检查返回类型是否为`()`。完成函数和方法调用时，除非函数没有参数，否则`rust-analyzer‘会将光标放在圆括号中。当键入`let`时，铁锈分析器会尝试有用地添加分号。

<!-- -->

Extend selection <span class="keycombo">Shift+Alt+→</span>
  
This is again a feature which is relatively simple to implement, but a
huge helper. It progressively selects larger and larger expressions,
statements and items. It works exceptionally well in combination with
multiple cursors. One hidden capability of this feature is a navigation
help: if you are in a middle of a function, you can get to the beginning
of it by extending seleciton several times, and then pressing ←.

扩展选择范围Shift+Alt+→这也是一个相对容易实现的功能，但却是一个巨大的帮助器。它逐步选择越来越大的表达式、语句和项。它与多个游标配合使用时效果非常好。此功能的一个隐藏功能是导航帮助：如果您正处于某个功能的中间，您可以通过几次扩展Seleciton，然后按←键进入该功能的开头。

<!-- -->

Fixit for missing module  
Another disproportionally nice feature — to create a new file, type
`mod file_name;` and use <span class="keycombo">ctrl+.</span> to add the
file itself.

修复丢失的模块另一个极好的功能 - 要创建新文件，请键入`mod file_name；`，然后使用ctrl+。若要添加文件本身，请执行以下操作。

<!-- -->

Assists  
More generally, there are a lot of cases where the light bulb can write
some boring code for you. Some of my favorites are impl generation:

一般来说，有很多情况下，灯泡可以为您编写一些无聊的代码。我最喜欢的几个是Iml Generation：

And filling match arms:

填充火柴臂：

# Drawbacks

# 缺点

rust-analyzer is a young tool and comes with a lot of limitations. The
most significant one is that we are not at the moment using `rustc`
directly, so our capabilities for detecting errors are limited.

生锈分析仪是一种年轻的工具，有很多局限性。最重要的一点是，我们目前没有直接使用`rustc‘，所以我们检测错误的能力是有限的。

In particular, to show inline errors we are doing what Emacs has been
doing for ages — running `cargo check` after the file is saved. If
auto-save is enabled in the editor, the result is actually quite nice
for small projects.

特别地，为了显示内联错误，我们正在执行Emacs在保存文件后运行` - check`的AGES货物检查所做的事情。如果在编辑器中启用了自动保存，那么对于小项目来说，结果实际上是相当不错的。

For bigger projects though, I feel like `cargo check` in background gets
in the way. So for `rust-analyzer` I have
`rust-analyzer.checkOnSave.enabled = false;` in the settings. Instead, I
use the **Run** functionality to run `check` / `test` and keyboard
shortcuts to navigate between errors.

不过，对于更大的项目，我觉得后台的“货物检查”会妨碍我的工作。因此，对于`rust-analyzer`，我在设置中设置了`rust-analyzer.checkOnSave.enable=false；`。相反，我使用Run功能来运行`check`/`test`，并使用键盘快捷键在错误之间导航。

Another big issue is that at the moment we, for simplicity, don’t
persist caches to disk. That means that every time you open a project
with rust-analyzer, it needs to analyze, from source:

另一个大问题是，为了简单起见，目前我们不将缓存持久化到磁盘。也就是说，每次您使用铁锈分析器打开一个项目时，它都需要从源头进行分析：

* all sysroot crates (std, core, alloc, etc)
  
  所有sysroot机箱(标准、核心、分配等)

* all crates.io dependencies
  
  所有crates.io依赖项

* all crates in your workspace
  
  工作区中的所有板条箱

This takes time, tens of seconds for medium sized projects.

这需要时间，中型项目需要数十秒。

Similarly, because we never save anything to disk, we need to keep
analysis results for all crates in memory. At the moment, rust-analyzer
process might requires gigabytes of ram for larger projects.

类似地，因为我们从不将任何内容保存到磁盘，所以我们需要将所有箱子的分析结果保存在内存中。目前，对于较大的项目，锈蚀分析仪过程可能需要几十亿字节的随机存取存储器(Ram)。

Finally, because analysis is not complete, features are not working
correctly every time. Sometimes there are missing completions, sometimes
goto definition is wrong, we may even show false-positive errors on
occasion.

最后，由于分析不完整，功能并非每次都能正确工作。有时会有遗漏的补全，有时GOTO定义是错误的，有时甚至会出现误报错误。

This is an alpha release. We have a long road ahead of us towards solid
and reliable IDE support. Luckily (and this is the instance where a life
of an IDE writer is simpler than that of a compiler writer) an IDE
doesn’t have to be 100% correct to be useful.

这是阿尔法版本。在实现坚实可靠的IDE支持方面，我们还有很长的路要走。幸运的是(这是IDE编写者的生活比编译器编写者更简单的实例)IDE不一定要100%正确才有用。

# How can I help?

# 我怎么可以帮上你呢？

If you find rust-analyzer useful and use it professionally, please
consider asking your company to sponsor rust-analyzer via our [Open
Collective](https://opencollective.com/rust-analyzer/). Sponsorships
from individuals are also accepted (and greatly appreciated!).

如果您觉得铁锈分析仪很有用，并且是专业使用的，请考虑通过我们的Open Collective向贵公司申请赞助铁锈分析仪。来自个人的赞助也被接受(并非常感谢！)

For other financial support options, customization requests, or extended
support, please write an email to [rust-analyzer@ferrous-systems.com](rust-analyzer@ferrous-systems.com).

有关其他财务支持选项、定制请求或扩展支持，请发送电子邮件至rust-analyzer@ferous-systems.com。

Many people like starting contributing to the project with docs, and we
certainly can use some help as well. For user-visible documentation, we
have [a
manual](https://github.com/rust-analyzer/rust-analyzer/blob/7a9ba1657daa9fd90c639dcd937da11b4f526675/docs/user/readme.adoc)
which is pretty bare bones at the moment. In particular, it doesn’t talk
about **features** of rust-analyzer yet. The primary document for
developers is
[architecture.md](https://github.com/rust-analyzer/rust-analyzer/blob/7a9ba1657daa9fd90c639dcd937da11b4f526675/docs/dev/architecture.md).

很多人喜欢从文档开始为项目做贡献，我们当然也需要一些帮助。对于用户可见的文档，目前我们有一本非常简单的手册。特别是，它还没有谈到防锈分析仪的功能。面向开发人员的主要文档是architect ture.md。

If you want to contribute code, the best way to start is the
aforementioned architecture document. In general, rust-analyzer code
base is comparatively easy to contribute to: it is a standard Rust
crate, which builds with stable compiler. The best first issue to fix is
something that you personally find lacking. If you are already perfectly
happy with rust-analyzer, we have a [bunch of
issues](https://github.com/rust-analyzer/rust-analyzer/issues) others
have reported :-)

如果您想要贡献代码，最好的开始方式是前面提到的体系结构文档。一般来说，锈分析器代码库相对容易贡献：它是一个标准的锈箱，使用稳定的编译器构建。首先要解决的最好问题是你个人觉得缺少的东西。如果您对防锈分析仪已经非常满意，我们有很多其他人报告的问题：-)