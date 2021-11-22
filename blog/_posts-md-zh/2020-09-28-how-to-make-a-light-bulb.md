rust-analyzer is a new "IDE backend" for the
[Rust](https://www.rust-lang.org/) programming language. Support
rust-analyzer on [Open
Collective](https://opencollective.com/rust-analyzer/) or [GitHub
Sponsors](https://github.com/sponsors/rust-analyzer).

铁锈分析器是铁锈编程语言的一个新的“IDE后端”。支持Open Collective或GitHub赞助商的防锈分析仪。

My favorite IDE feature is a light bulb — a little 💡 icon that appears
next to a cursor which you can click on to apply a local refactoring. In
the first part of this post, I’ll talk about why this little bulb is so
dear to my heart, and in the second part I’ll go into some
implementation tips and tricks. First part should be interesting for
everyone, while the second part is targeting folks implementing their
own IDEs / language serves.

我最喜欢的集成开发环境功能是一个灯泡 - ，一个出现在光标旁边的小💡图标，您可以点击它来应用本地重构。在这篇文章的第一部分，我将讨论为什么这个小灯泡对我如此重要，在第二部分，我将介绍一些实现技巧和诀窍。第一部分应该是每个人都感兴趣的，而第二部分是针对实现他们自己的IDE/语言服务的人。

# The Mighty 💡

# 强大的💡

[Post-IntelliJ](https://martinfowler.com/bliki/PostIntelliJ.html) IDEs,
with their full access to syntax and semantics of the program, can
provide almost an infinite amount of smart features. The biggest problem
is not implementing the features, the biggest problem is teaching the
users that a certain feature exists.

后IntelliJ IDE完全可以访问程序的语法和语义，可以提供几乎无限多的智能功能。最大的问题是没有实现功能，最大的问题是告诉用户某个功能是存在的。

One possible UI here is a fuzzy-searchable command palette:

这里的一个可能的UI是模糊可搜索的命令调色板：

![emacs helm](/assets/blog/how-to-make-a-light-bulb/emacs-helm.png)

Emacs头盔

This helps if the user (a) knows that some command might exist, and (b)
can guess its name. Which is to say: not that often.

如果用户(A)知道可能存在某个命令，并且(B)可以猜测其名称，这会很有帮助。这就是说：不是那么频繁。

Contrast it with the light bulb UI:

将其与灯泡UI进行对比：

First, by noticing a 💡 you see that *some* feature is available in this
particular context:

首先，通过注意💡，您可以看到在此特定上下文中提供了一些功能：

![bulb1](/assets/blog/how-to-make-a-light-bulb/bulb1.png)

鳞茎1

Then, by clicking the 💡 (<span class="keycombo">ctrl+.</span> in VS
Code / <span class="keycombo">Alt+Enter</span> in IntelliJ) you can see
a *short* list of actions applicable in the current context:

然后，通过单击💡(Ctrl+.在VS Code/Alt+Enter in IntelliJ)中，您可以看到适用于当前上下文的操作的简短列表：

![bulb2](/assets/blog/how-to-make-a-light-bulb/bulb2.png)

鳞茎2

This is a rare case where UX is both:

这是一种罕见的情况，其中UX既是：

* Discoverable, which makes novices happy.
  
  可发现性，这让新手很开心。

* Efficient, to make expert users delighted as well.
  
  高效，也能让专业用户感到高兴。

I am somewhat surprised that older editors, like Emacs or Vim, still
don’t have the 💡 concept built-in. I don’t know which editor/IDE
pioneered the light bulb UX; if you know, please let me know the
comments!

令我有点惊讶的是，像Emacs或Vim这样的老编辑器仍然没有内置💡概念。我不知道哪个编辑器/IDE开创了灯泡UX；如果你知道，请告诉我评论！

# How to Implement a 💡?

# 如何实现💡？

If we squint hard enough, an IDE/LSP server works a bit like a web
server. It accepts requests like “what is the definition of symbol on
line 23?”, processes them according to the language semantics and
responds back. Some requests also modify the data model itself ("here’s
the new text of foo.rs file: '…​'"). Generally, the state of the world
might change between any two requests.

如果我们仔细观察，IDE/LSP服务器的工作原理有点像Web服务器。它接受诸如“第23行符号的定义是什么？”之类的请求，根据语言语义处理这些请求并做出响应。一些请求还修改了数据模型本身(“这里是foo.rs文件的新文本：‘…​’”)。通常，世界状态可能会在任何两个请求之间发生变化。

In single-process IDEs (IntelliJ) requests like code completion
generally modify the data directly, as the IDE itself is the source of
truth.

在单进程IDE(IntelliJ)中，像代码完成这样的请求通常会直接修改数据，因为IDE本身就是真相的来源。

In client-server architecture (LSP), the server usually responds with a
diff and receives an updated state in a separate request — client holds
the true state.

在客户端-服务器体系结构中，服务器通常使用DIFF进行响应，并在单独的请求中接收更新后的状态 - 客户端保持真实状态。

This is relevant for 💡 feature, as it usually needs two requests. The
first request takes the current position of the cursor and returns the
list of available assists. If the list is not empty, the 💡 icon is
shown in the editor.

这与💡功能相关，因为它通常需要两个请求。第一个请求获取光标的当前位置，并返回可用辅助的列表。如果列表不为空，则编辑器中会显示💡图标。

The second request is made when/if a user clicks a specific assist; this
request calculates the corresponding diff.

第二个请求是当/如果用户单击特定的帮助时发出的；该请求计算相应的差异。

Both request are initiated by user’s actions, and arbitrary events might
happen between the two. Hence, assists can’t assume that the state of
the world is intact between `list` and `apply` actions.

这两个请求都是由用户的操作发起的，两者之间可能会发生任意事件。因此，助手不能假设在`list`和`apply`操作之间世界状态是完好无损的。

This leads to the following interface for assists (lightly adapted
[`IntentionAction`](https://github.com/JetBrains/intellij-community/blob/680dbb522465d3fd3b599c2c582a7dec9c5ad02b/platform/analysis-api/src/com/intellij/codeInsight/intention/IntentionAction.java)
from IntelliJ )

这将导致以下助攻界面(稍微改编自IntelliJ的`IntentionAction`)

```kotlin
interface IntentionAction {
  val name: String
  fun isAvailable(position: CursorPosition): Boolean
  fun invoke(position: CursorPosition): Diff
}
```

That is, to implement a new assist, you provide a class implementing
`IntentionAction` interface. The IDE platform then uses `isAvailable`
and `getName` to populate the 💡 menu, and calls `invoke` to apply the
assist if the user asks for it.

也就是说，要实现新的辅助，需要提供一个实现`IntentionAction`接口的类。然后，集成开发环境平台使用`isAvailable`和`getName`填充💡菜单，并在用户请求时调用`invoke`来应用帮助。

This interface has exactly the right shape for the IDE platform, but is
awkward to implement.

该接口的形状完全适合IDE平台，但实现起来很笨拙。

This is a specific instance of a more general phenomenon. Each
abstraction has [two
faces](https://en.wikipedia.org/wiki/The_Disk) — one for the
implementer, one for the user. Two sides often have slightly different
requirements, but tend to get implemented in a single language construct
by default.

这是一个更普遍的现象的具体例子。每个抽象都有两个面 - ，一个面向实现者，一个面向用户。两端的需求通常略有不同，但默认情况下倾向于在单一语言结构中实现。

Almost always, the code at the start of `isAvailable` and `invoke` would
be similar. Here’s a bigger example from PyCharm:
[`isAvailable`](https://github.com/JetBrains/intellij-community/blob/680dbb522465d3fd3b599c2c582a7dec9c5ad02b/python/python-psi-impl/src/com/jetbrains/python/codeInsight/intentions/PySplitIfIntention.java#L34-L48)
and
[`invoke`](https://github.com/JetBrains/intellij-community/blob/680dbb522465d3fd3b599c2c582a7dec9c5ad02b/python/python-psi-impl/src/com/jetbrains/python/codeInsight/intentions/PySplitIfIntention.java#L72-L82).

几乎所有情况下，`isAvailable`和`invoke`开头的代码都是相似的。这里有一个来自PyCharm的更大的示例：`isAvailable`和`invoke`。

To reduce this duplication in Intellij Rust, I introduced a convenience
base class
[`RsElementBaseIntentionAction`](https://github.com/intellij-rust/intellij-rust/blob/3527d29f7c42412e33125dabb2f86acf3a46bc86/src/main/kotlin/org/rust/ide/intentions/RsElementBaseIntentionAction.kt):

为了减少IntelliJ Rust中的这种重复，我引入了一个方便的基类`RsElementBaseIntentionAction`：

```kotlin
class RsIntentionAction<Ctx>: IntentionAction {
  fun getContext(position: CursorPosition): Ctx?
  fun invoke(position: CursorPosition, ctx: Ctx): Diff

  override fun isAvailable(position: CursorPosition) =
    getContext(position) != null

  override fun invoke(position: CursorPosition) =
    invoke(position, getContext(position)!!)
}
```

The duplication is removed in a rather brute-force way — common code
between `isAvailable` and `invoke` is reified into (assist-specific)
`Ctx` data structure. This gets the job done, but defining a `Context`
type (which is just a bag of stuff) is tedious, as seen in, for example,
[InvertIfIntention.kt](https://github.com/intellij-rust/intellij-rust/blob/3527d29f7c42412e33125dabb2f86acf3a46bc86/src/main/kotlin/org/rust/ide/intentions/InvertIfIntention.kt#L16-L21).

以相当暴力的方式去除重复项，将`isAvailable`和`Invoke`之间的 - 公共代码具体化为(辅助特定的)`Ctx`数据结构。这就完成了工作，但是定义一个“Context`”类型(它只是一袋东西)是单调乏味的，例如，在InvertIfIntention.kt中可以看到。

rust-analyzer uses what I feel is a slightly better pattern. Recall our
original analogy between an IDE and a web server. If we stretch it even
further, we may say that assists are similar to an HTML form. The `list`
operation is analogous to the `GET` part of working with forms, and
`apply` looks like a `POST`. In an HTTP server, the state of the world
also changes between `GET /my-form` and `POST /my-form`, so an HTTP
server also queries the database twice.

生锈分析仪使用的是我觉得稍微好一点的式样。回想一下我们最初在IDE和Web服务器之间的类比。如果我们进一步扩展，我们可以说助手类似于HTML表单。`list`操作类似于表单的`GET`操作，`apply`类似于`POST`。在HTTP服务器中，世界状态也在`Get/my-form`和`post/my-form`之间变化，所以HTTP服务器也会查询数据库两次。

Django web framework has a nice pattern to implement this — function
based views.

Django web框架有一个很好的模式来实现这个基于视图的 - 函数。

```python
def my_form(request):
  ctx = fetch_stuff_from_postgress()
  if request.method == 'POST':
    # apply changes ...
  else:
    # render template ...
```

A single function handles both `GET` and `POST`. Common part is handled
once, differences are handled in two branches of the `if`, a runtime
parameter selects the branch of `if`.

一个函数可以同时处理`GET`和`POST`。公共部分处理一次，差异处理在`if`的两个分支中，运行时参数选择`if`的分支。

See [Django Views — The Right
Way](https://spookylukey.github.io/django-views-the-right-way/) for the
most recent discussion why function based views are preferable to class
based views.

参见Django视图-了解为什么基于函数的视图比基于类的视图更可取的最新讨论的正确方式。

This pattern, translated from a Python web framework to a Rust IDE,
looks like this:

此模式从Python Web框架转换为Rust IDE，如下所示：

```rust
enum MaybeDiff {
  Delayed,
  Diff(Diff),
}


fn assist(position: CursorPosition, delay: bool)
    -> Option<MaybeDiff>
{
  let ctx = compute_common_context(position)?;
  if delay {
    return Some(MaybeDiff::Delayed);
  }

  let diff = compute_diff(position, ctx);
  Some(MaybeDiff::Diff(diff))
}
```

The `Context` type got dissolved into a set of local variables. Or,
equivalently, `Context` is a reification of control flow — it is a set
of local variables which are live before the `if`. One might even want
to implement this pattern with coroutines/generators/async, but there’s
no real need to, as there’s only one fixed suspension point.

\`Context`类型分解为一组局部变量。或者，等价地，`Context`是控制流 - 的具体化。它是在`if`之前活动的一组局部变量。您甚至可能希望使用协同例程/生成器/异步来实现此模式，但实际上并不需要这样做，因为只有一个固定的挂起点。

For a non-simplified example, take a look at
[invert_if.rs](https://github.com/rust-analyzer/rust-analyzer/blob/550709175071a865a7e5101a910eee9e0f8761a2/crates/assists/src/handlers/invert_if.rs#L31-L63).

对于非简化的示例，请查看invert_if.rs。