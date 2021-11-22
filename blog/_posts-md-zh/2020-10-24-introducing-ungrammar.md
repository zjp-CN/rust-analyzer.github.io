rust-analyzer is a new "IDE backend" for the
[Rust](https://www.rust-lang.org/) programming language. Support
rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/) or [GitHub
Sponsors](https://github.com/sponsors/rust-analyzer).

铁锈分析器是铁锈编程语言的一个新的“IDE后端”。支持Open Collective或GitHub赞助商的防锈分析仪。

This post introduces ungrammars: a new formalism for describing concrete
syntax trees. The ideas behind ungrammar are simple, and are more
valuable than a specific implementation. Nonetheless, an implementation
is available here:

这篇文章介绍了ungramars：一种描述具体语法树的新形式。非语法背后的想法很简单，而且比具体的实现更有价值。尽管如此，此处提供了一个实现：

[https://github.com/rust-analyzer/ungrammar](https://github.com/rust-analyzer/ungrammar)

https://github.com/rust-analyzer/ungrammar

At a glance, ungrammar looks a lot like
[EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form)
notation:

乍一看，非文法看起来很像EBNF表示法：

```
Module =
  Attr* Visibility?
  'mod' Name
  (ItemList | ';')
```

The two differ at a fundamental level though:

不过，这两者在根本上是不同的：

<div class="caution">

EBNF specifies a language — a set of strings.

eBNF指定一种语言 - 一组字符串。

Ungrammar describes concrete syntax tree — a set of data types (or a set
of trees, if you will).

非语法描述具体的语法树 - 一组数据类型(或者，如果您愿意，也可以是一组树)。

</div>

That’s why it is called *un*grammar!

这就是为什么它被称为“非语法”的原因！

# Motivation

# 动机

So, what exactly does “describing syntax trees” mean and why is it
useful? When writing an IDE, one of the core data structure is the
concrete syntax tree. It is a full-fidelity tree which represents the
original source code in detail, including parenthesis, comments, and
whitespace. CSTs are used for initial analysis of the language. They are
also a vocabulary type for refactors. Although the ultimate result of a
refactor is a text diff, tree modification is a more convenient internal
representation.

那么，“描述语法树”到底是什么意思，它为什么有用呢？编写IDE时，核心数据结构之一是具体的语法树。它是一个全保真树，详细表示原始源代码，包括括号、注释和空格。CST用于语言的初步分析。它们也是一种重构的词汇类型。虽然重构的最终结果是文本差异，但树修改是更方便的内部表示。

If you want to learn more about concrete syntax trees, check out this
guide, check out these two links:

如果您想了解有关具体语法树的更多信息，请查看本指南，查看以下两个链接：

* [CST in
  rust-analyzer](https://github.com/rust-analyzer/rust-analyzer/blob/master/docs/dev/syntax.md)
  
  CST在测锈仪中的应用

* [CST in Swift](https://github.com/apple/swift/tree/main/lib/Syntax)
  
  SWIFT中的CST

At the lowest level, the CST is typically unityped: there’s some `Node`
superclass, which has a collection of `Node` children and an optional
`Node` parent. On top of this raw layer, a more AST-like API is
provided: `Struct` has a `.name()` and a list of `.fields()`, etc. This
typed API is huge! For rust-analyzer, it is comprised of more than 130
*types*! And it is also more detailed than a typical AST: `Struct` also
has `.l_curly()` and `.r_curly()`.

在最低级别，cst通常是unittype的：有一些`Node`超类，它有一个由`Node`子类和一个可选的‘Node`父类组成的集合。在这个原始层之上，提供了一个更像AST的接口：`Struct`有一个`.name()`和一个`.field()`列表，等等。这个类型化的API非常大！对于测锈仪，它有130多种型号！而且比典型的AST更详细：`Struct`还有`.l_curly()`和`.r_curly()`。

What’s worse, this API changes a lot, especially at the beginning. You
may start with nesting `.fields()` directly under the `Struct`, but then
introduce a `StructFields` node for everything between the curly braces
to share the code with enum variants.

更糟糕的是，这个API改变了很多，特别是在开始的时候。您可以从直接嵌套在`Struct`下的`.field()`开始，然后为花括号之间的所有内容引入一个`StructFields`节点，以便与枚举变体共享代码。

In short, writing this by hand sucks :-) Ungrammar is a notation to
concisely describe the structure of the syntax tree, which can be used
by a code generator to build an API in the target language. If you’ve
heard about [ASDL](https://www.oilshell.org/blog/2016/12/11.html),
ungrammar is ASDL for concrete syntax trees. For rust-analyzer’s case,
that means taking the following input:

简而言之，手工编写这段代码很糟糕：-)非语法是一种简明描述语法树结构的符号，代码生成器可以使用它来用目标语言构建API。如果您听说过ASDL，UNGRMAX就是具体语法树的ASDL。对于铁锈分析仪的情况，这意味着采用以下输入：

```
Module =
  Attr* Visibility?
  'mod' Name
  (ItemList | ';')
```

And generating the following output:

并生成以下输出：

```rust
impl ast::AttrsOwner      for Module {}
impl ast::VisibilityOwner for Module {}
impl ast::NameOwner       for Module {}
impl Module {
    pub fn mod_token(&self)       -> Option<SyntaxToken> { ... }
    pub fn item_list(&self)       -> Option<ItemList>    { ... }
    pub fn semicolon_token(&self) -> Option<SyntaxToken> { ... }
}
```

In typical parser generators, something similar can be achieved by
generating *both* the parser and the syntax tree from the same grammar.
This works to some extent, but has an inherent problem that the shape of
the tree you want for the programmatic API, and the shape of the grammar
you need to implement the parser are often different. “Technical”
transformations like left-recursion elimination don’t affect the
language described by the grammar, but completely change the shape of
the parse tree. In contrast, ungrammar focuses solely on the second
task, which radically reduces the complexity of the grammar. In
rust-analyzer, it is paired with a hand-written parser.

在典型的解析器生成器中，可以通过从相同的语法生成解析器和语法树来实现类似的功能。这在某种程度上是可行的，但存在一个固有的问题，即编程API所需的树的形状和实现解析器所需的语法形状通常不同。像左递归消除这样的“技术”转换不会影响语法描述的语言，但会完全改变解析树的形状。相反，非语法只专注于第二个任务，这从根本上降低了语法的复杂性。在锈蚀分析器中，它与手写解析器配对。

Treated as an ordinary (context free) grammar, ungrammar describes a
superset of the language. For example, for programmatic API it might be
convenient to treat commas in comma-separate lists as a part of the list
element (rust-analyzer doesn’t do this yet, but it should). This leads
to the following ungrammar, which obviously doesn’t treat commas
precisely:

非语法被视为普通的(上下文无关)语法，它描述了语言的超集。例如，对于编程式API，将逗号分隔的列表中的逗号作为列表元素的一部分来处理可能会很方便(Ruust分析器还没有这样做，但它应该这样做)。这会导致以下不符合语法的情况，显然不能准确地处理逗号：

```
FieldList =
  '{' Field* '}'

Field:
  Name ':' Type ','?
```

Similarly, ungrammar defines binary and unary expressions, but doesn’t
specify their relative precedence and associativity.

同样，非语法定义了二元和一元表达式，但没有指定它们的相对优先级和结合性。

An interesting side-effect is that the resulting grammars turn out to be
pretty human readable. For example, a full production ready Rust grammar
takes about 600 short lines:

一个有趣的副作用是，最终得到的语法非常便于人类阅读。例如，一个完整的生产就绪Rust语法需要大约600行短行：

[https://github.com/rust-analyzer/ungrammar/blob/master/rust.ungram](https://github.com/rust-analyzer/ungrammar/blob/784f345e5e799e828650da1b1acbb947f1e49a52/rust.ungram)

https://github.com/rust-analyzer/ungrammar/blob/master/rust.ungram

This might be a good fit for reference documentation!

这可能非常适合参考文档！

# Nuts and Bolts

# 螺母和螺栓

Now that we’ve answered the “why” question, let’s look at how ungrammar
works.

现在我们已经回答了“为什么”这个问题，让我们来看看非语法是如何起作用的。

Like grammars, ungrammars operate with a set of terminals and
non-terminals. Terminals are atomic indivisible tokens, like keyword
`fn` or a semicolon `;`. Non-terminals are composite internal nodes
consisting of other nodes and tokens.

与语法一样，非语法使用一组终端和非终端进行操作。终端是原子不可分割的令牌，如关键字`fn`或分号`；`。非终端是由其他节点和令牌组成的复合内部节点。

Tokens (terminals) are spelled using single quotes: `'+'`, `'fn'`,
`'ident'`, `'int_number'`. Tokens are defined outside of an ungrammar,
and don’t need to be declared to use them. By convention, keywords and
punctuation are represented using themselves, other tokens use
lower_snake_case. Because ungrammar describes trees, it uses parser
tokens rather then lexer tokens. What this means is that
context-sensitive keywords like `default` are recognized as separate
tokens (`'default'`). The same goes for composite tokens like `'<<'`.

令牌(终端)使用单引号拼写：`‘+’`，`‘fn’`，`‘ident’`，`‘int_number’`。令牌是在非语法之外定义的，不需要声明就可以使用它们。按照惯例，关键字和标点符号使用自身表示，其他标记使用LOWER_VONSE_CASE。因为非语法描述树，所以它使用解析器标记，而不是词法分析器标记。这意味着像`default`这样的上下文敏感关键字被识别为单独的令牌(`‘默认’`)。类似于`‘<<’`这样的复合标记也是如此。

Nodes (non-terminals) are defined within the grammar by associating node
name and a rule. The ungrammar itself is a set of node definitions. By
convention, nodes are named using UpperCamelCase. Each node must be
defined exactly once. Rules are regular expressions over the set of
tokens and nodes.

通过将节点名和规则相关联，在语法中定义节点(非终端)。非语法本身是一组节点定义。按照惯例，节点使用UpperCamelCase命名。每个节点必须恰好定义一次。规则是一组令牌和节点上的正则表达式。

Here’s ungrammar which describes ungrammar syntax:

下面是描述非语法语法的非语法：

```
Grammar =
  Node*

Node =
  name:'ident' '=' Rule

Rule =
  'ident'                // Alphabetic identifier
| 'token_ident'          // Single quoted string
| Rule*                  // Concatenation
| Rule ('|' Rule)*       // Alternation
| Rule '?'               // Zero or one repetition
| Rule '*'               // Kleene star
| '(' Rule ')'           // Grouping
| label:'ident' ':' Rule // Labeled rule
```

The only unusual thing are optional labels. By default, the names in the
generated code are derived automatically from the type, but a label can
be used as an override, or if there’s an ambiguity:

唯一不寻常的是可选标签。默认情况下，生成的代码中的名称自动派生自类型，但标签可以用作覆盖，或者如果存在歧义：

```
Expr =
  literal
| lhs:Expr op:('+' | '-' | '*' | '/') rhs:Expr
```

By convention, ungrammar is indented with two spaces, leading `|` is not
indented.

按照惯例，非语法用两个空格缩进，前导`|`不缩进。

Ungrammar doesn’t specify any particular way to lower rules to syntax
node definitions. It’s up to the generator to pattern-match rules to
target language constructs: Java would use inheritance, Rust enums and
TypeScript — union types. The generator can accept only a subset of all
possible rules. An example of restriction might be: “Alternation (`|`)
is only allowed at the top level. Alternatives must be other nodes”.
With this restriction, an alternative can be lowered to an interface
definition with a number of subclasses.

非语法没有指定任何特定的方式来降低语法节点定义的规则。生成器负责将规则与目标语言构造进行模式匹配：JAVA将使用继承、RUST枚举和TypeScript - 联合类型。生成器只能接受所有可能规则的子集。限制的一个例子可以是：“仅在顶层允许替换(`|`)。备选方案必须是其他节点“。有了这个限制，可以将备选方案降低为具有许多子类的接口定义。

The [ungrammar](https://docs.rs/ungrammar/1.1.4/ungrammar/) crate
provides a Rust API for parsing ungrammars, use it if your code
generator is implemented in Rust. Alternatively,
[`ungrammar2json`](https://crates.io/crates/ungrammar2json) binary
converts ungrammar syntax into equivalent JSON. For an example of
generator, take a look at
[`gen_syntax`](https://github.com/rust-analyzer/rust-analyzer/blob/4105378dc7479a3dbd39a4afb3eba67d083bd7f8/xtask/src/codegen/gen_syntax.rs)
in rst-analyzer.

非文法框架提供了一个用于解析非文法的Rust API，如果您的代码生成器是用Rust实现的，请使用它。或者，“ungram mar2json”二进制将非语法语法转换为等价的JSON。有关生成器的示例，请查看rst-analyzer中的`GEN_SYNTAX`。

# Designing ungrammar

# 设计非文法

The concluding section briefly mentions some lessons learned.

结语部分简要提到了一些经验教训。

The `Node` and `Token` terminology is inherited from
[rowan](https://github.com/rust-analyzer/rowan), rust-analyzer’s syntax
library. A better choice would be `Tree` and `Token`, as nodes contain
other nodes and *are* trees.

\`Node`和`Token`术语继承自Rowan，锈检分析器的语法库。更好的选择是`Tree`和`Token`，因为节点包含其他节点，并且是树。

Always single-quoting terminals is a nice concrete syntax for grammars.
Some parser generators I’ve worked with required only some terminals to
be quoted, which, without knowing the rules by heart, reduced
readability. Similarly, spelling `PLUS` instead of `'+'` is not very
readable.

始终使用单引号结尾是语法的一种很好的具体语法。我使用过的一些解析器生成器只需要引用一些终端，这在没有记住规则的情况下降低了可读性。同样，拼写`PLUS`而不是`‘+’`的可读性也不是很好。

“Recursive regular expressions” feels like a convenient syntax for CFGs.
Not restricting right-hand-side to be a flat list of alternatives, using
`()` for grouping and allowing basic conveniences like `*` and `?`
subjectively makes the resulting grammars quiet readable. The catch is
that one needs union types and anonymous records to faithfully lower
arbitrary regex-represented rule. Placing restrictions into the specific
generator, rather then the base language, feels like a better division
of responsibility.

“递归正则表达式”感觉像是CFG的一种方便的语法。不将右侧限制为备选方案的平面列表，使用`()`进行分组，并允许像`*`和`？`这样的基本便利，主观上使生成的语法非常易读。问题是需要联合类型和匿名记录来忠实地降低任意正则表达式表示的规则。将限制放在特定的生成器中，而不是基础语言中，感觉更好地划分了责任。

By quoting terminals, using punctuation (`: = () | * ?`) for syntax and
completely avoiding keywords, ungrammar avoids clashes between names of
productions and the syntax of ungrammar itself.

通过引用终端，语法使用标点符号(`：=()|*？`)，并完全避开关键字，非语法避免了产品名称与非语法本身的语法冲突。