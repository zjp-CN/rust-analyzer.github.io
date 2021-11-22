This post is a direct response to [Which Parsing
Approach?](https://tratt.net/laurie/blog/entries/which_parsing_approach.html).
If you haven’t read that article, do it now — it is the best short
survey of the lay of the land of modern parsing techniques. I agree with
conclusion — LR parsing is the way to go if you want to do parsing
“properly”. I reasoned the same a couple of years ago: [Modern Parser
Generator](https://matklad.github.io/2018/06/06/modern-parser-generator.html#parsing-techniques).

这篇文章是对哪种解析方法的直接回应？如果您还没有读过那篇文章，那么现在就去做吧， - 这是对现代解析技术领域最好的简短概述。我同意这样的结论，如果您想要“正确”地进行解析， - LR解析是可行的。几年前我也有过同样的想法：现代解析器生成器。

However, and here’s the catch, rust-analyzer uses a hand-written
recursive descent / [Pratt
parser](https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html).
One of the reasons for that is that I find existing LR parser generators
inadequate for production grade compiler/IDE. In this article, I want to
list specific challenges for the authors of LR parser generators.

但是，这里需要注意的是，锈蚀分析器使用的是手工编写的递归下降/普拉特解析器。其中一个原因是我发现现有的LR解析器生成器不适合生产级编译器/IDE。在本文中，我想列出LR解析器生成器创建者面临的具体挑战。

# Error Resilience

# 容错能力

Consider this incomplete snippet of Rust code:

请考虑下面这段不完整的铁锈代码：

```rust
fn foo(

struct S {
   f: u32
}
```

I want to see an LR parser which produces the following syntax tree
(from [**Show Syntax
Tree**](https://rust-analyzer.github.io/manual.html#show-syntax-tree)
rust-analyzer command, with whitespace nodes elided for clarity):

我希望看到一个LR解析器，它生成以下语法树(来自Show SynTax Tree rust-Analyzer命令，为清晰起见省略了空格节点)：

```
SOURCE_FILE@0..32
  FN@0..7
    FN_KW@0..2 "fn"
    NAME@3..6
      IDENT@3..6 "foo"
    PARAM_LIST@6..7
      L_PAREN@6..7 "("
  STRUCT@9..31
    STRUCT_KW@9..15 "struct"
    NAME@16..17
      IDENT@16..17 "S"
    RECORD_FIELD_LIST@18..31
      L_CURLY@18..19 "{"
      RECORD_FIELD@23..29
        NAME@23..24
          IDENT@23..24 "f"
        COLON@24..25 ":"
        PATH_TYPE@26..29
          PATH@26..29
            PATH_SEGMENT@26..29
              NAME_REF@26..29
                IDENT@26..29 "u32"
      R_CURLY@30..31 "}"
```

The most error-resilient LR-style parser I know, [tree
sitter](https://github.com/tree-sitter/tree-sitter), produces this
instead (tree sitter is GLR, this is **not** the style of parsing
advocated by the article):

我知道的错误恢复能力最强的LR风格的解析器，tree sitter会生成这样的代码(tree sitter是GLR，这不是本文提倡的解析风格)：

```
source_file [0, 0] - [5, 0])
  ERROR [0, 0] - [4, 1])
    identifier [0, 3] - [0, 6])
    struct_pattern [2, 0] - [4, 1])
      type: type_identifier [2, 0] - [2, 6])
      ERROR [2, 7] - [2, 8])
        identifier [2, 7] - [2, 8])
      field_pattern [3, 3] - [3, 9])
        name: field_identifier [3, 3] - [3, 4])
        pattern: identifier [3, 6] - [3, 9])
```

Note two things about the rust-analyzer’s tree:

关于防锈分析仪的采油树，请注意两件事：

* There’s an (incomplete) “function” node for `fn foo(`. Unclosed
  parenthesis doesn’t preclude the parser from recognizing parameter
  list.
  
  \`fn foo(`.未右括号并不妨碍解析器识别参数列表。

* Incomplete function does not prevent struct definition from being
  recognized.
  
  函数不完整不会阻止识别结构定义。

These are important for IDE support.

这些对于IDE支持非常重要。

For example, suppose that the cursor is just after `(`. If we have
rust-analyzer’s syntax tree, than we can figure out that we are
completing a function parameter. If we are to get fancy we might find
the calls to the (not yet fully written) `foo`, run type inference to
figure out the type of the first argument, and than suggest parameter
name & type based on that (not currently implemented — there’s soooooo
much yet to be done in rust-analyzer). And correctly recognizing
`struct S` is important to not break type-inference in the code which
uses `S`.

例如，假设光标正好在`(`.如果我们有锈蚀分析器的语法树，那么我们就可以计算出我们正在完成一个函数参数。如果我们想要更有想象力，我们可能会找到对(尚未完全编写的)`foo`的调用，运行类型推断来计算出第一个参数的类型，然后基于此建议参数名称和类型(目前还没有实现 - ，在锈蚀分析器中还有很多工作要做)。正确识别`struct S`对于不破坏使用`S`的代码中的类型推理是很重要的。

There’s a lot of literature about error recovery for LR parsers, how
come academics haven’t figured this out already? I have a bold claim to
make: error-recovery research in academia is focusing on a problem
irrelevant for IDEs. Specifically, the research is focused on finding
“minimal cost repair sequence”:

关于LR解析器的错误恢复的文献很多，为什么学者们还没有弄清楚这一点呢？我有一个大胆的声明：学术界的错误恢复研究集中在一个与IDE无关的问题上。具体地说，研究的重点是寻找“最小成本维修序列”：

* a set of edit operations is defined (skip, change or insert token),
  
  定义一组编辑操作(跳过、改变或插入令牌)，

* a “cost” metric is defined to distinguish big and small edits,
  
  定义“成本”度量来区分大编辑和小编辑，

* an algorithm is devised to find the smallest edit which makes the
  current text parse.
  
  设计了一种算法，找出使当前文本解析的最小编辑。

This is a very academia-friendly problem — there’s a precise
mathematical formulation, there’s an obvious brute force solution (try
all edits), and there’s ample space for finding polynomial algorithm.

这是一个非常适合学术界的问题， - 有一个精确的数学公式，有一个明显的强力解决方案(尝试所有的编辑)，并且有足够的空间来寻找多项式算法。

But IDEs don’t care about actually guessing & repairing the text! They
just need to see as much of (possibly incomplete) syntax nodes in the
existing text as possible. When rust-analyzer’s parser produces

但是IDE并不关心实际猜测和修复文本！他们只需要在现有文本中看到尽可能多的(可能不完整的)语法节点。当铁锈分析仪的解析器生成

```
  PARAM_LIST@6..7
    L_PAREN@6..7 "("
STRUCT@9..31
```

it doesn’t think “Oh, I need to insert `)` here to complete the list of
parameters”. Rather, it sees `struct` and thinks “Oh wow, didn’t expect
that! I guess I’ll just stop parsing parameter list right here”.

它不会认为“哦，我需要在这里插入`)`来完成参数列表”。相反，它看到‘struct’就会想：“哦，哇，没想到会这样！我想我就在这里停止解析参数列表“。

So, here’s

所以，这里是

<div class="important">
<div class="title">

First Challenge

第一次挑战

</div>

Design error *resilient* (and not just error *recovering*) LR parsing
algorithm.

设计容错(而不仅仅是错误恢复)LR解析算法。

</div>

Note that error resilience is a topic orthogonal to error reporting. I
haven’t payed much attention to error reporting (in my experience,
synchronous reporting of syntax errors in the editor compensates for bad
syntax error messages), but it might be the case that MCRS are a good
approach to there.

请注意，错误恢复能力是与错误报告正交的主题。我没有对错误报告给予太多关注(根据我的经验，在编辑器中同步报告语法错误可以补偿糟糕的语法错误消息)，但MCR可能是一种很好的方法。

# Expressions Grammar

# 表达式语法

Next challenge concerns expressing operator precedence and
associativity. Today, the standard solution is to write the grammar like
this:

下一个挑战涉及表示运算符优先级和结合性。今天，标准的解决方案是这样编写语法：

```
%start Expr
%%
Expr: Expr "-" Term
    | Term
    ;
Term: Term "*" Factor
    | Factor
    ;
Factor: "INT"
    ;
```

I argue that this is a nice solution for the machine, but is a terrible
UX for a human. Rust has 13 levels of precedence — no way I can come up
with 13 different names like `Term` and `Factor`. A much more readable
formulation here is [precedence
table](https://doc.rust-lang.org/reference/expressions.html#expression-precedence).
Interestingly, this is the case where hand-written [Pratt
parser](https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html)
is more declarative:

我认为这对机器来说是一个很好的解决方案，但对人类来说却是一个糟糕的用户体验。Rust有13个优先级别，我不可能想出13个不同的名字，比如 - 和Factor`。这里一个可读性更强的公式是优先表。有趣的是，在这种情况下，手工编写的Pratt解析器更具声明性：

```rust
fn infix_binding_power(op: char) -> Option<(u8, u8)> {
    let res = match op {
        '=' => (2, 1),
        '?' => (4, 3),
        '+' | '-' => (5, 6),
        '*' | '/' => (7, 8),
        '.' => (14, 13),
        _ => return None,
    };
    Some(res)
}
```

<div class="important">
<div class="title">

Second Challenge

第二次挑战

</div>

Incorporate precedence and associativity tables into the surface syntax
of the grammar.

将优先表和结合表合并到语法的表层语法中。

</div>

# IDE Support

# IDE支持

Finally, please provide decent IDE support ^^ Here are the features I’d
consider simple and essential:

最后，请提供像样的IDE支持^^以下是我认为简单而重要的功能：

* precise [syntax
  highlighting](https://github.com/microsoft/vscode-languageserver-node/blob/60a5a7825e6f54f57917091f394fd8db7d1724bc/protocol/src/common/protocol.semanticTokens.ts)
  (references colored to the same color as the corresponding
  declaration),
  
  精确的语法突出显示(引用着色为与相应声明相同的颜色)，

* [outline](https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#textDocument_documentSymbol)
  (fuzzy search by production names),
  
  大纲(按产品名称进行模糊搜索)，

* [go to
  definition](https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#textDocument_definition),
  
  转到定义，

* [completion](https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#textDocument_completion).
  
  完工了。

A somewhat more complex, but also crucial feature is live preview. It
should be possible to edit the grammar or the sample text, and
*immediately* see the resulting parse tree. Like this:
[https://www.youtube.com/watch?v=gb1MJnTcvds&feature=youtu.be](https://www.youtube.com/watch?v=gb1MJnTcvds&feature=youtu.be) (but, of
course, the update should be instant). For UX, I suggest using doctest
syntax:

一个稍微复杂，但也很关键的功能是实时预览。应该可以编辑语法或示例文本，并立即看到结果解析树。如下所示：https://www.youtube.com/watch?v=gb1MJnTcvds&feature=youtu.be(当然，更新应该是即时的)。对于UX，我建议使用doctest语法：

```
/// fn foo() { }
Fn = 'fn' Name ParamList Block
```

Today, it takes only a day to implement a basic LSP server and get all
the basic features working in most popular editors. Implementing
live-preview would be more involved as there’s no existing LSP request
for this. But writing a custom extension isn’t hard either, so add
another day for live preview.

今天，实现一个基本的LSP服务器并让所有基本功能在最流行的编辑器中运行只需要一天的时间。实现实时预览将涉及更多内容，因为没有针对此的现有LSP请求。但是编写自定义扩展也不难，所以再添加一天进行实时预览。

<div class="important">
<div class="title">

Third Challenge

第三个挑战

</div>

Implement LSP server which provides basic IDE features, as well as live
preview.

实现LSP服务器，它提供基本的IDE功能，以及实时预览。

</div>

# Challenge Responses

# 质询响应

Folks fom [Galois](https://galois.com/) develop a classy-named
[DaeDaLus](https://github.com/GaloisInc/daedalus) — a flexible data
description language for generating parsers with data dependencies.
DaeDaLus makes an impressive attempt at solving the second challenge.
The language is powerful enough to just [directly
encode](https://github.com/GaloisInc/daedalus/blob/fe088fefc553e37974b47345a1da4b49a10da7f7/bin-exp/pratt-bin-expr.ddl#L53-L69)
Pratt-style precedence table. Even a [more
declarative](https://github.com/GaloisInc/daedalus/blob/fe088fefc553e37974b47345a1da4b49a10da7f7/bin-exp/left-rec-bin-expr.ddl#L62-L73)
encoding might be possible, although it doesn’t fully work at the time
of writing.

来自Galois的人们开发了一种名为Daedalus的 - ，这是一种灵活的数据描述语言，用于生成具有数据依赖关系的解析器。代达罗斯在解决第二个挑战方面做出了令人印象深刻的尝试。该语言功能强大，只需直接编码Pratt样式的优先级表即可。即使是更具声明性的编码也是可能的，尽管在编写本文时它还不能完全工作。