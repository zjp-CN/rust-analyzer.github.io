I’ve already written before about how precise code completion is
impossible to do inside Rust macros:
[https://github.com/matklad/proc-caesar](https://github.com/matklad/proc-caesar). Today I’d like to write a
short note about another impossibility result:

我以前已经写过，在Rust宏中不可能实现精确的代码完成：https://github.com/matklad/proc-caesar.今天，我想就另一个不可能的结果写一个简短的便条：

<div class="informalexample">

Correct automatic rename is not possible in a language with rust-style
macros.

在具有锈色样式宏的语言中，无法正确自动重命名。

</div>

Consider the following example:

请考虑以下示例：

```rust
macro_rules! call_foo {
    () => { foo() };
}

mod a {
    fn foo() {}

    fn main() {
        call_foo!();
    }
}

mod b {
    fn foo() {}

    fn main() {
        call_foo!();
    }
}
```

What is the expected result for renaming `a::foo` to `bar`? There isn’t
one, as the same macro refers to different `foo` at different
call-sites!

将`a：：foo`重命名为`bar`的预期结果是什么？没有，因为同一个宏在不同的调用点引用不同的“foo”！

But the problem is even deeper than ambiguity. Consider this (silly)
crate:

但问题比模棱两可更深。考虑一下这个(愚蠢的)板条箱：

```rust
#[doc(hidden)]
pub const HELLO: &str = "hello";

#[macro_export]
macro_rules! say_hello {
    () => { println!("{}", $crate::HELLO) }
}
```

In this case, it is pretty clear what we want to get after renaming
`HELLO` to `GREETING`:

在这种情况下，将`HELLO`重命名为`GREETING`后，我们想要得到什么就很清楚了：

```rust
#[doc(hidden)]
pub const GREETING: &str = "hello";

#[macro_export]
macro_rules! say_hello {
    () => { println!("{}", $crate::GREETING) }
}
```

Unfortunately, it is impossible to formalize this transformation. To the
human reader, it is *obvious* that the right hand side of a macro should
be parsed as an expression. But this intuition is flawed — the right
hand side is just a sequence of tokens, and it receives a meaning only
when we call the macro. And there’s no guarantee, in general case, that
it would be interpreted as an expression:

不幸的是，这种转变是不可能正规化的。对于人类读者来说，很明显宏的右侧应该被解析为表达式。但是这种直觉是有缺陷的， - ，右边只是一个记号序列，只有当我们调用宏时，它才有意义。在一般情况下，不能保证它会被解释为一个表达式：

```rust
#[doc(hidden)]
pub const HELLO: &str = "hello";

macro_rules! m {
    ($($tt:tt)*) => { $($tt)*($crate::HELLO) };
}

fn main() {
    let expr = m!(std::convert::identity);
    let tt = m!(stringify!);
    println!("expr = {},tt = {}", expr, tt)
}
```

Together this means that the theoretically best definition of **correct
automated rename** we can get in Rust is limited. We can handle code
outside the macros and code inside macro calls. For macro definitions,
at best we can give a list of locations that require manual
intervention.

总而言之，这意味着我们在Rust中所能得到的正确自动重命名在理论上的最佳定义是有限的。我们可以处理宏外部的代码和宏调用内部的代码。对于宏定义，我们最多只能给出需要手动干预的位置列表。

It also seems plausible that, with some heuristic, we can infer renames
in macro definitions as well. For example, we can look at all call sites
of the macro, and see if they all agree that a certain token in the
macro definition needs change.

通过一些启发式方法，我们也可以在宏定义中推断重命名，这似乎也是合理的。例如，我们可以查看宏的所有调用点，看看它们是否都同意宏定义中的某个标记需要更改。