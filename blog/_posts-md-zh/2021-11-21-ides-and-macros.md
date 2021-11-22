In this article, we’ll discuss challenges that language servers face
when supporting macros. This is interesting, because for rust-analyzer,
macros are the hardest nut to crack.

在本文中，我们将讨论语言服务器在支持宏时面临的挑战。这很有趣，因为对于锈蚀分析器来说，宏是最难破解的。

While we use Rust as an example, the primary motivation here is to
inform future language design. As this is a case study rather than a
thorough analysis, conclusions should be taken with a grain of salt. In
particular, I know that Scala 3 has a revamped macro system which
*might* contain all the answers, but I haven’t looked at it deeply.
Finally, note that the text is unfairly biased *against* macros:

虽然我们以Rust为例，但这里的主要动机是为未来的语言设计提供信息。由於这是个案研究，而不是透彻的分析，所以对此结论应持保留态度。特别值得一提的是，我知道Scala3有一个改进的宏观系统，它可能包含所有的答案，但我还没有深入研究过它。最后，请注意，文本对宏有不公平的偏见：

* I write IDEs, so macros for me are a problem to solve, rather than a
  tool to use.
  
  我编写IDE，所以宏对我来说是要解决的问题，而不是要使用的工具。

* My personal code style tends towards preferring textual verbosity
  over using advanced language features, so I don’t use macros that
  often.
  
  与使用高级语言功能相比，我个人的代码风格倾向于更喜欢文本的冗长，所以我不经常使用宏。

# Meta Challenges

# 元挑战

The most important contributing factor to complexity is non-technical.
Macros are *disproportionally* hard to support in an IDE. That is, if
adding macros to a batch compiler takes `X` amount of work, making them
play nicely with all IDE features takes `X²`. This crates a pull for
languages to naturally evolve more complex macro systems than can be
reasonably supported by dev tooling. The specific issues are as follows:

造成复杂性的最重要因素是非技术因素。在IDE中很难支持宏。也就是说，如果将宏添加到批处理编译器需要`X‘工作量，那么让它们很好地使用所有IDE功能需要`X²’。这促使语言自然地发展出比开发工具合理支持的更复杂的宏系统。具体问题如下：

# Mapping Back

# 映射回

*First*, macros can compromise the end-user experience, because some IDE
features are just not well-defined in the presence of macros. Consider
this code, for example:

首先，宏可能会影响最终用户体验，因为有些IDE功能在存在宏的情况下定义不是很好。请考虑以下代码，例如：

```rust
struct S { x: u32, y: u32 }

fn make_S() -> S {
  S { x: 92 } 💡
}
```

Here, a reasonable IDE feature (known as intention, code action, assist
or just 💡) is to suggest adding the rest of the fields to the struct
literal:

在这里，一个合理的集成开发环境特性(称为意图、代码操作、协助或简称为💡)是建议将字段的睡觉添加到结构文字：

```rust
struct S { x: u32, y: u32 }

fn make_S() -> S {
  S { x: 92, y: todo!() }
}
```

Now, let’s add a simple compile-time reflection macro:

现在，让我们添加一个简单的编译时反射宏：

```rust
struct S { x: u32, y: u32 }

reflect![
  {
    { 29 :x } S 😂
  } S <- ()S_ekam nf
];
```

What the macro does here is just to mirror every token. The IDE has no
troubles expanding this macro. It also understands that, in the
expansion, the `y` field is missing, and that `y: todo!()` can be added
to the *expansion* as a fix. What the IDE can’t do, though, is to figure
out what should be changed in the code that the user wrote to achieve
that effect. Another interesting case to think about is: What if the
macro just encrypts all identifiers?

宏在这里所做的只是镜像每个令牌。IDE可以毫不费力地展开此宏。它还理解在扩展中缺少`y‘字段，并且可以将`y：todo！()`作为修复添加到扩展中。不过，IDE不能做的是找出应该对用户编写的代码进行哪些更改才能达到该效果。另一个需要考虑的有趣情况是：如果宏只加密所有标识符怎么办？

This is where “*disproportionally* hard” bit lies. In a batch compiler,
code generally moves only forward through compilation phases. The single
exception is error reporting (which should say which *source* code is
erroneous), but that is solved adequately by just tracking source
positions in intermediate representations. An IDE, in contrast, wants to
modify the source code, and to do that precisely just knowing positions
is not enough.

这就是“不成比例的艰难”之处。在批处理编译器中，代码通常只在编译阶段向前移动。唯一的例外是错误报告(应该指出哪个源代码是错误的)，但是只需跟踪中间表示中的源代码位置就足以解决这个问题。相反，IDE想要修改源代码，要做到这一点，仅仅知道位置是不够的。

What makes the problem especially hard in Rust is that, for the user, it
might not be obvious which IDE features are expected to work. Let’s look
at a variation of the above example:

使Rust中的问题特别困难的是，对于用户来说，预期哪些IDE功能可以工作可能并不明显。让我们看一下上述示例的变体：

```rust
#[tokio::main]
async fn main() {
  S { x: 92 }; 💡
}
```

What a user sees here is just a usual Rust function with some annotation
attached. Clearly, everything should just work, right? But from an IDE
point of view, this example isn’t that different from the `reflect!`
one. `tokio::main` is just an opaque bit of code which takes the tokens
of the source function as an input, and produces some tokens as an
output, which then replace the original function. It just *happens* that
the semantics of the original code is mostly preserved. Again,
`tokio::main` *could* have encrypted every identifier!

用户在这里看到的只是一个普通的Rust函数，并附加了一些注释。很明显，一切都应该正常进行，对吧？但从IDE的角度来看，这个示例与‘反射！’示例没有太大不同。`tokio：：main`只是一段不透明的代码，它将源函数的Token作为输入，生成一些Token作为输出，然后替换原来的函数。碰巧原始代码的语义大部分都被保留下来了。同样，`tokio：：main`可以加密每个标识符！

So, to make thing appear to work, an IDE necessarily involves heuristics
in such cases. Some possible options are:

因此，为了使事情看起来像是工作，IDE在这种情况下必然涉及启发式。一些可能的选项包括：

* Just completely ignore the macro. This makes boring things like
  completion mostly work, but leads to semantic errors elsewhere.
  
  完全忽略宏即可。这使得像补全这样乏味的事情大部分都在工作，但会在其他地方导致语义错误。

* Expand the macro, apply IDE features to the expansion, and try to
  heuristically lift them to the original source code (this is the bit
  where “and now we just guess the private key used to encrypt an
  identifier” conceptually lives). This is the pedantically correct
  approach, but it breaks most IDE features in minor and major ways.
  What’s worse, the breakage is unexplainable to users: “I just added
  an annotation to the function, why I don’t get any completions?”
  
  展开宏，将IDE特性应用于展开，并尝试试探性地将它们提升到原始源代码(这是“现在我们只是猜测用于加密标识符的私钥”在概念上存在的位置)。这是一种循规蹈矩的正确方法，但它在一些小方面和主要方面破坏了大多数IDE特性。更糟糕的是，这种破坏对用户来说是无法解释的：“我刚刚给函数添加了一个注释，为什么我没有得到任何补全呢？”

* In the semantic model, maintain both the precisely analyzed expanded
  code and the heuristically analyzed source code. When writing IDE
  features, try to intelligently use precise analysis from the
  expansion to augment knowledge about the source. This still doesn’t
  solve all the problems, but solves most of them good enough such
  that the users are now completely befuddled by those rare cases
  where the heuristics break down.
  
  在语义模型中，维护精确分析的扩展代码和启发式分析的源代码。在编写IDE特性时，试着智能地使用扩展中的精确分析来增加关于源代码的知识。这仍然不能解决所有问题，但解决了大多数问题，以至于用户现在完全被那些启发式失败的罕见情况所迷惑。

<div class="note">
<div class="title">

First Lesson

第一课

</div>

Design meta programming facilities to be “append only”. Macros should
not change the meaning of existing code.

将元编程工具设计为“仅附加”。宏不应更改现有代码的含义。

Avoid situations where what looks like normal syntax is instead an
arbitrary language interpreted by a macro in a custom way.

避免出现这样的情况，即看似正常语法的内容实际上是宏以自定义方式解释的任意语言。

</div>

# Parallel Name Resolution

# 并行名称解析

*The second* challenge is performance and phasing. Batch compilers
typically compile all the code, so the natural solution of just
expanding all the macros works. Or rather, there isn’t a problem at all
here, you just write the simplest code to do the expansion and things
just work. The situation for an IDE is quite different — the main reason
why the IDE is capable of working with keystroke latency is that it
cheats. It just doesn’t look at the majority of the code during code
editing, and analyses the absolute minimum to provide a completion
widget. To be able to do so, an IDE needs help from the language to
understand which parts of code can be safely ignored.

第二个挑战是性能和阶段性。批处理编译器通常编译所有代码，因此只需展开所有宏的自然解决方案有效。或者更确切地说，这里根本没有问题，您只需编写最简单的代码来进行扩展，事情就可以正常工作了。集成开发环境的情况非常不同， - ，集成开发环境能够与击键延迟一起工作的主要原因是它作弊。它只是在代码编辑期间不查看大部分代码，而是分析绝对最少的代码以提供完成小部件。要做到这一点，IDE需要语言的帮助来理解哪些代码部分可以安全地忽略。

Read [this other
article](https://rust-analyzer.github.io/blog/2020/07/20/three-architectures-for-responsive-ide.html)
to understand specific tricks IDEs can employ here. The most powerful
idea there is that, generally, an IDE needs to know only about top-level
names, and it doesn’t need to look inside e.g. function bodies most of
the time. Ideally, an IDE processes all files in parallel, noting, for
each file, which top-level names it contributes.

阅读另一篇文章，了解IDE可以在此处使用的具体技巧。最强大的想法是，通常情况下，IDE只需要知道顶级名称，而不需要在大多数情况下查看内部，例如函数体。理想情况下，IDE并行处理所有文件，并为每个文件注明其贡献的顶级名称。

The problem with macros, of course, is that they can contribute new
top-level names. What’s worse, to understand *which* macro is invoked,
an IDE needs to resolve its name, which depends on the set of top-level
names already available.

当然，宏的问题在于它们可以提供新的顶级名称。更糟糕的是，要了解调用了哪个宏，IDE需要解析其名称，这取决于已有的顶级名称集。

Here’s a rather convoluted example which shows that in Rust name
resolution and macro expansion are interdependent:

下面是一个相当复杂的示例，它表明在Rust中，名称解析和宏扩展是相互依赖的：

<div class="formalpara-title">

**main.rs**

main.rs

</div>


```rust
mod foo;
foo::declare_mod!(bar, "foo.rs");
```

<div class="formalpara-title">

**foo.rs**

foo.rs

</div>


```rust
pub struct S;
use super::bar::S as S2;

macro_rules! _declare_mod {
  ($name:ident, $path:literal) => {
    #[path = $path]
    pub mod $name;
  }
}
pub(crate) use _declare_mod as declare_mod;
```

Semantics like this are what prevents rust-analyzer to just process
every file in isolation. Instead, there are bits in rust-analyzer that
are hard to parallelize and hard to make incremental, where we just
accept high implementation complexity and poor runtime performance.

这样的语义可以防止防锈分析器孤立地处理每个文件。取而代之的是，锈蚀分析器中的一些位很难并行化，很难进行增量处理，我们只能接受实现复杂度高、运行时性能差的情况。

There is an alternative — design meta programming such that it can work
“file at a time”, and can be plugged into an embarrassingly parallel
indexing phase. This is the design that Sorbet, a (very) fast type
checker for Ruby chooses: [https://youtu.be/Gdx6by6tcvw?t=804](https://youtu.be/Gdx6by6tcvw?t=804). I
*really* like the motivation there. It is a given that people would love
to extend the language in some way. It is also given that extensions
wouldn’t be as carefully optimized as the core compiler. So let’s make
sure that the overall thing is still crazy fast, even if a particular
extension is slow, by just removing extensions from the hot path.
(Compare this with VS Code architecture with out-of-process extensions,
which just *can’t* block the editor’s UI).

还有一种替代的 - 设计元编程，它可以“一次处理文件”，并且可以插入到令人尴尬的并行索引阶段。这就是(非常)快的Ruby类型检查器Sorbet选择的设计：https://youtu.be/Gdx6by6tcvw?t=804.我真的很喜欢那里的动力。人们喜欢以某种方式扩展这种语言，这是理所当然的。还考虑到扩展不会像核心编译器那样被仔细优化。因此，让我们通过从热路径中删除扩展来确保整个事情仍然非常快，即使特定的扩展很慢。(这与带有进程外扩展的VS代码体系结构形成对比，后者不能挡路编辑器的UI)。

To flesh out this design bit:

要充实此设计，请执行以下操作：

* All macros used in a compilation unit must be known up-front. In
  particular, it’s not possible to define a macro in one file of a CU
  and use it in another.
  
  编译单元中使用的所有宏必须预先知道。特别是，不可能在CU的一个文件中定义宏，然后在另一个文件中使用它。

* Macros follow simplified name resolution rules, which are
  intentionally different from the usual ones to allow recognizing and
  expanding macros *before* name resolution. For example, macro
  invocations could have a unique syntax, like `name!`, where `name`
  identifies a macro definition in the flat namespace of
  known-up-front macros.
  
  宏遵循简化的名称解析规则，这些规则故意与通常的规则不同，以允许在名称解析之前识别和扩展宏。例如，宏调用可以具有唯一的语法，如`name！`，其中`name`标识已知的前置宏的平面命名空间中的宏定义。

* Macros don’t get to access anything outside of the file with the
  macro invocation. They *can* simulate name resolution for
  identifiers within the file, but can’t reach across files.
  
  宏不能通过宏调用来访问文件之外的任何内容。它们可以模拟文件内标识符的名称解析，但不能跨文件访问。

Here, limiting macros to local-only information is a conscious design
choice. By limiting the power available to macros, we gain the
properties we can use to make the tooling better. For example, a macro
can’t know a type of the variable, but because it can’t do that, we know
we can re-use macro expansion results when unrelated files change.

在这里，将宏限制为仅限本地信息是一种有意识的设计选择。通过限制宏的可用功能，我们获得了可以用来改进工具的属性。例如，宏不能知道变量的类型，但是因为它不能知道变量的类型，所以我们知道当不相关的文件更改时，我们可以重用宏扩展结果。

An interesting hack to regain the full power of type-inspecting macros
is to move the problem from the language to the tooling. It is possible
to run a code generation step before the build, which can use the
compiler as a library to do a global semantic analysis of the code
written by the user. Based on the analysis results, the tool can write
some generated code, which would then be processed by IDEs as if it was
written by a human.

重新获得类型检查宏的全部功能的一个有趣的技巧是将问题从语言转移到工具。可以在构建之前运行代码生成步骤，该步骤可以使用编译器作为库来对用户编写的代码进行全局语义分析。根据分析结果，该工具可以编写一些生成的代码，然后这些代码将被IDE处理，就像它是由人编写的一样。

<div class="note">
<div class="title">

Second Lesson

第二课

</div>

Pay close attention to the interactions between name resolution and
macro expansions. Besides well-known hygiene issues, another problem to
look out for is accidentally turning name resolution from an
embarrassingly parallel problem into an essentially sequential one.

密切关注名称解析和宏扩展之间的交互作用。除了众所周知的卫生问题外，另一个需要注意的问题是意外地将名称解析从一个令人尴尬的并行问题变成了一个本质上顺序的问题。

</div>

# Controllable Execution

# 可控执行

The *third* problem is that, if macros are sufficiently powerful, the
can do sufficiently bad things. To give a simple example, here’s a macro
which expands to an infinite number of “no”:

第三个问题是，如果宏足够强大，就可以做足够坏的事情。举个简单的例子，下面是一个扩展为无限个“no”的宏：

```rust
macro_rules! m {
    ($($tt:tt)*) => { m!($($tt)* $($tt)*); }
}
m!(no);
```

The behavior of the command-line compiler here is to just die with an
out-of-memory error, and that’s an OK behavior for this context. Of
course it’s better when the compiler gives a nice error message, but if
it misbehaves and panics or loops infinitely on erroneous code, that is
also OK — the user can just `^C` the process.

这里的命令行编译器的行为就是死于内存不足错误，这对于这个上下文来说是正常的行为。当然，当编译器给出一个很好的错误消息时会更好，但是如果它行为不正常、死机或者在错误代码上无限循环，那也是可以的，用户只需`^C‘ - 进程即可。

For a long-running IDE process though, looping or eating all the memory
is not an option — all resources need to be strictly limited. This is
especially important given that an IDE looks at incomplete and erroneous
code most of the time, so it hits far more weird edge cases than a batch
compiler.

但是，对于长时间运行的集成开发环境进程，循环或吃掉所有内存并不是一种选择( - )，所有资源都需要受到严格限制。这一点尤其重要，因为IDE大部分时间都会查看不完整和错误的代码，因此它比批处理编译器遇到更多奇怪的边缘情况。

Rust procedural macros are all-powerful, so rust-analyzer and IntelliJ
Rust have to implement extra tricks to contain them. While `rustc` just
loads proc-macros as shared libraries into the process, IDEs load macros
into a dedicated external process which can be killed without bringing
the whole IDE down. Adding IPC to an otherwise purely functional
compiler code is technically challenging.

Rust过程宏是全能的，所以Ruust-Analyzer和IntelliJ Rust必须实现额外的技巧来包含它们。虽然`rustc`只是将proc-宏作为共享库加载到进程中，而IDE将宏加载到一个专用的外部进程中，该进程可以在不影响整个IDE的情况下被终止。将IPC添加到纯函数编译器代码在技术上具有挑战性。

A related problem is determinism. rust-analyzer assumes that all
computations are deterministic, and it uses this fact to smartly forget
about subsets of derived data, to save memory. For example, once a file
is analyzed and a set of declarations is extracted out of it,
rust-analyzer destroys its syntax tree. If the user than goes to a
definition, rust-analyzer re-parses the file from source to compute
precise ranges, highlights, etc. At this point, it is important the tree
is exactly the same. If that’s not the case, rust-analyzer might panic
because various indices from previously extracted declarations get out
of sync. But in the presence of non-deterministic procedural macros,
rust-analyzer actually *can* get a different syntax tree. So we have to
specifically disable the logic for forgetting syntax trees for macros.

一个相关的问题是决定论。锈蚀分析器假设所有计算都是确定性的，并利用这一事实巧妙地忘记派生数据的子集，以节省内存。例如，一旦分析了一个文件并从中提取了一组声明，锈蚀分析器就会销毁它的语法树。如果用户转到某个定义，则防锈分析仪会从源重新解析文件，以计算精确的范围、高亮显示等。在这一点上，树是完全相同的，这一点很重要。如果不是这样，铁锈分析器可能会恐慌，因为以前提取的声明中的各种索引不同步。但是在存在不确定的过程宏的情况下，锈检分析器实际上可以得到不同的语法树。因此，我们必须专门禁用忘记宏的语法树的逻辑。

<div class="note">
<div class="title">

Third Lessons

第三课

</div>

Make sure that macros are deterministic, and can be easily limited in
the amount of resources they consume. For a batch compiler, it’s OK to
go with optimistic best-effort guarantees: “we assume that macros are
deterministic and can crash otherwise”. IDEs have stricter availability
requirements, so they have to be pessimistic: “we cannot crash, so we
assume that any macro is potentially non-deterministic”.

确保宏是确定性的，并且可以很容易地限制它们消耗的资源量。对于批处理编译器，可以采用乐观的尽力而为保证：“我们假设宏是确定性的，否则可能会崩溃”。IDE有更严格的可用性要求，因此它们必须悲观：“我们不能崩溃，所以我们假设任何宏都可能是不确定的”。

</div>

Curiously, similar to the previous point, moving metaprogramming to a
code generation build system step sidesteps the problem, as you again
can optimistically assume determinism.

奇怪的是，与前面的观点类似，将元编程转移到代码生成构建系统步骤可以回避问题，因为您同样可以乐观地假设确定性。

# Recap

# 概述

When it comes to metaprogramming, IDEs have a harder time than the batch
compilers. To paraphrase Kernighan, if you design metaprogramming in
your compiler as cleverly as possible, you are not smart enough to write
an IDE for it.

说到元编程，IDE比批处理编译器更难。套用Kernighan的话说，如果您在编译器中尽可能巧妙地设计元编程，那么您就不够聪明，无法为其编写IDE。

Some specific hard macro bits:

一些特定的硬宏比特：

* In a compiler, code flows forward through the compilation pipeline.
  IDE features generally flow *back*, from desugared code into the
  original source. Macros can easily make for an irreversible
  transformation.
  
  在编译器中，代码通过编译管道向前流动。IDE特性通常会从经过去糖化的代码回流到原始源代码中。宏很容易实现不可逆转的转换。

* IDEs are fast because they know what to *not* look at. Macros can
  hide what is there, and increase the minimum amount of work
  necessary to understand an isolated bit of code.
  
  IDE速度很快，因为它们知道什么不应该看。宏可以隐藏那里的内容，并增加理解一小段独立代码所需的最低工作量。

* User-written macros can crash. IDEs must not crash. Running macros
  from an IDE is therefore fun :-)
  
  用户编写的宏可能会崩溃。IDE不能崩溃。因此，从IDE运行宏非常有趣：-)