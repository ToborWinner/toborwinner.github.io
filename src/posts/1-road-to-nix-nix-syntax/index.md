Before you can begin properly configuring NixOS, you must learn various things,
the most basic of which is the syntax of Nix.

Nix is a programming language (aside from being a package manager), but it
differs a lot from traditional programming languages. One of the most important
differences is that a Nix file is not executed from top to bottom. Actually,
it's not "executed" at all, but rather **evaluated**.

A Nix file must evaluate to a value. In other words, a Nix file contains an
expression that can be "simplified" to a single value. The following snippets
are all valid examples of Nix files:

```nix
5 # This file evaluates to the value 5
```

```nix
1 + 1 # This file evaluates to 2
```

```nix
"Hello, " + "World!" # This file evaluates to the string "Hello, World!"
```

If you have Nix installed, you can check what these files evaluate to using the
following command:

```bash
nix-instantiate --eval --strict file-name.nix
```

The important concept to understand from these examples is that Nix is not
evaluated sequentially, but rather evaluated by "simplifying" the expression
contained in the file. Note that all values in Nix are constant! There is no
modifying a value, there is only "simplifying" the expression further.

I will now explain most (but not all) of the syntax of Nix. While the next
sections might be boring, they are required to fully understand the next
chapters, so I recommend reading them.

Looking at the previous examples, we can learn a few more basics about the Nix
language:

- The `#` symbol can be used to begin a comment which won't end until the next
  line.
- The `+` symbol is an operation that can add two numbers or concatenate two
  strings. Other basic math symbols, such as `*` for multiplication won't be
  explained as they are intuitive.
- Strings can be defined by surrounding text with double quotation marks.

Just like in other programming languages, parentheses can be used to indicate
priority:

```nix
(5 + 4) * 3 # Evaluates to 27
```

In addition, the `/* comment */`{.nix} syntax can be used for a multi-line
comment:

```nix
/*
  Multi-line
  comment
*/
5
```

# `let` bindings

While evaluating basic expressions using Nix is certainly cool, it can sometimes
be useful to temporarily save an intermediate result. For example, take a look
at the following expression:

```nix
5 * (1 + 1) * (1 + 1)
```

It seems we have to repeat `(1 + 1)`{.nix} twice. It would instead be more
appropriate to assign the value to a name, which we can later reference twice.
That is where `let` bindings come into play:

```nix
let
  mySum = 1 + 1;
in 5 * mySum * mySum
```

The whole file evaluates to `20`{.nix}.

The `let ... in ...`{.nix} syntax allows you to assign (_bind_) values to names
after the `let` keyword and use them after the `in` keyword. The result of the
expression is **only** what comes after the `in` keyword:

```nix
let
  mySum = 1 + 2;
in 70
```

The whole file in this case evaluates to `70`{.nix}, meaning that what you write
between the `let` and `in` keywords is only useful if you reference it after the
`in` keyword.

In addition, the bindings defined in a `let` binding are only available in the
`let ... in ...`{.nix} expression, as can be seen in the following example,
which does **not** evaluate successfully:

```nix
(let
  mySum = 1 + 2;
in 5 * mySum) * mySum
```

Here is the error we receive when attempting the evaluation of the above:

```bash
❯ nix-instantiate --eval --strict let-in-not-working.nix
error: undefined variable 'mySum'
       at /home/tobor/let-in-not-working.nix:7:3:
            6| )
            7| * mySum
             |   ^
            8|
```

Nix indeed complains about `mySum` not being defined, as it's only valid in the
let binding.

Assignments in `let` bindings can also refer to themselves or other assignments:

```nix
let
  a = 1;
  b = a + 2;
in b + 3 # This evaluates to 6
```

# Conditionals

We can use the `if <cond> then <value-true> else <value-false>`{.nix} syntax to
define conditionals. If the condition is true, then the first value will be
returned, otherwise the second will. Unlike traditional languages, there must
always be an `else` case. This is because pretty much everything in Nix is an
expression, meaning that it must evaluate to something. If there was no `else`
case, then Nix wouldn't know what to put as the output of the evaluated
expression if the condition was false.

The condition must evaluate to a boolean, meaning either `true`{.nix} or
`false`{.nix}. Here is an example:

```nix
if 5 == 2 + 3 then "yes" else "no" # This evaluates to "yes"
```

# Data Types

We've now learned a few Nix keywords, but we still only manipulated numbers and
basic strings. There are other data types in Nix and they are listed below
together with some of their quirks.

## Number (integer or float)

We've already seen numbers in the previous examples. Integers are restricted
between `-9223372036854775808`{.nix} and `9223372036854775807`{.nix} (`i64`),
while floats (rational numbers that are not integers) are `f64`. Numbers can
also be written in the following form: `1.2e5`{.nix}, which is the same as
`120000`{.nix}.

The 4 basic operations `+`, `-`, `*` and `/` can be used with numbers. More
advanced operations are available through `builtins`{.nix}, which we will look
at later.

## String

Strings can be defined by surrounding text with double quotation marks. Those
types of strings can use escape characters, such as `\n`, but they can only span
across one line:

```nix
"Hello\nthere on a new line"
```

For multi-line strings, the following syntax can be used:

```nix
''
  In computer science, functional programming is a
  programming paradigm where programs are constructed
  by applying and composing functions.
  - Wikipedia
''
```

Notice how there are extra spaces preceding each line in the string. These
spaces will be ignored by Nix: the smallest number of spaces preceding a line
will be taken and subtracted from all lines. Escape characters such as `\n`
cannot be used in this type of string.

### String interpolation

If we want to interpolate a string inside of another, we can use the `${}`{.nix}
syntax:

```nix
let
  inside = "string";
in "My first ${inside} interpolation" # Evaluates to "My first string interpolation"
```

> Note: The `${}` string can be escaped in a multi-line string by writing
> `''${}`.

## Boolean

As previously mentioned, a boolean can either be `true` or `false`. Booleans can
be negated with the `!` operator:

```nix
!false # This evaluates to true
```

Other boolean operators are `&&` (logical conjunction, meaning "and"), `||`
(logical disjunction, meaning "or") and `->` (logical implication).

## Path

Due to its native purpose of composing derivations and configuring systems, Nix
has first-class support for paths. Paths in Nix can begin with `/` (absolute
path), `.` (relative path) or `..` (relative path from the previous folder), for
example:

```nix
./my-relative/path/to/my-file.nix
```

## Null

The type of the value `null`{.nix}.

## List

Lists in Nix are ordered groups of values. Lists can be created using the
`[ item1 item2 item3 ]`{.nix} syntax, where items are separated by spaces. Items
in lists can be of any type:

```nix
[ 1 2 3 "Nix" ]
```

### Concatenating lists

There is an operator to concatenate lists: `++`. It can be used like this:

```nix
[ 1 2 ] ++ [ 3 4 ] # This evaluates to [ 1 2 3 4 ]
```

## Attribute set

An attribute set is a set of key-value pairs defined with the following syntax:

```nix
{
  name = "Tobor";
  github = "ToborWinner";
  madeNixGuide = true;
}
```

The keys are called attributes. The values of these attributes can be accessed
by using a `.`:

```nix
{ a = "hey"; }.a # This evaluates to "hey"
```

A default value if the attribute doesn't exist can be specified with `or`:

```nix
{ }.a or 5 # Evaluates to 5
```

Nested attribute sets can be set through a shortcut using `.`:

```nix
{
  a.b.c = 5;
}
```

is the same as

```nix
{
  a = {
    b = {
      c = 5;
    };
  };
}
```

I can check if an attribute set has an attribute by using `?`:

```nix
{ a = 4; } ? a # Evaluates to true
```

> Note: The name "attribute set" is often shortened to "attrs".

### `rec` keyword

The `rec` keyword can be used to make an attribute set "recursive", meaning it
can define its attributes based on other attributes it defines:

```nix
rec {
  a = 5;
  b = a + 6;
}
```

This example evaluates to the following attribute set:

```nix
{
  a = 5;
  b = 11;
}
```

### `inherit` keyword

The `inherit` keyword, when used in attribute sets, is syntactic sugar for
`a = a`:

```nix
let
  a = 5;
in {
  inherit a; # This is the same as writing a = a;
}
```

Attributes can be added in parentheses to specify the path:

```nix
let
  a = {
    b = 5;
  };
in {
  inherit (a) b; # This is the same as writing b = a.b;
}
```

### Update operator

`//` is the update operator for attribute sets. It will overwrite the attributes
of the attribute set on the left with the attributes of the attribute set on the
right:

```nix
{ a = 5; b = 1; } // { a = 2; c = 6; } # This evaluates to { a = 2; b = 1; c = 6; }
```

## Function

With Nix being a _functional_ programming language, functions are one of the
core constructs of the Nix language.

Functions take a single argument as input and produce an output. It's important
to understand that a function itself is also a value! They can be defined with
the following syntax:

```nix
argument: argument + 5
```

This file now contains a function as its value. It's a valid Nix file because it
evaluates to a value. In fact, if we run the command, we get the following
output:

```bash
❯ nix-instantiate --eval --strict simple-function.nix
<LAMBDA>
```

`<LAMBDA>` here
[means function](https://en.wikipedia.org/wiki/Anonymous_function#Names){target="\_blank"}!

In this case, the argument to this function is called `argument` and it produces
the output `argument + 5`{.nix}. To call a function, we can add a space after it
and pass it an argument:

```nix
(argument: argument + 5) 6 # This evaluates to 11
```

As a function is just like any other value, we could assign it to a name using a
`let` binding for example:

```nix
let
  myFunc = x: x + 5;
in myFunc 6 # This evaluates to 11
```

It's very important to understand that functions in Nix **always take one
argument**. If we need a function to take two arguments, we can "chain" two
single-argument functions together, which is also called
[currying](https://en.wikipedia.org/wiki/Currying){target="\_blank"}:

```nix
(arg1: arg2: arg1 + arg2) 1 2 # This evaluates to 3
```

Note that we did not create a function that takes two arguments, but rather
combined two single-argument functions. The first function takes `arg1` as
argument and outputs another function. This other function takes `arg2` as
argument and outputs `arg1 + arg2`{.nix}. We then call the first function with
the number `1`{.nix}, which gives us a function in return. We then call this
returned function with the number `2`{.nix}, which gives us `3`{.nix} back.

We could separate the two function calls:

```nix
let
  myFunc = arg1: arg2: arg1 + arg2;
  firstOut = myFunc 1; # firstOut is now a function
in firstOut 2 # We call the function with the number 2, obtaining 3
```

### Argument destructuring

Another way to somehow pass multiple arguments to a function that takes a single
argument is by passing it a compound type such as an attribute set. For example:

```nix
(x: x.a + x.b) {
  a = 1;
  b = 2;
} # This evaluates to 3
```

Since this is a pattern that is very commonly used in Nix (as we'll see in
future chapters about nixpkgs and NixOS configurations), there is a language
feature that makes it easier:

```nix
({ a, b }: a + b) {
  a = 1;
  b = 2;
} # This evaluates to 3
```

You can destructure the attribute set passed as argument into its attributes!
This is **almost** the same as the previous example, but Nix is _strict_ when
checking the arguments, meaning that the attribute set must have exactly and
only the attributes `a` and `b`. You can allow for other attributes in the
attribute set by writing `{ a, b, ... }:`{.nix} instead.

Default values can also be provided:

```nix
({ a ? 1, b }: a + b) { b = 2; } # Evaluates to 3
```

In addition, a name can be assigned to the attribute set using the `@-pattern`:

```nix
(args@{ a, b, ... }: a + b + args.c) {
  a = 1;
  b = 2;
  c = 3;
} # This evaluates to 6
```

which can come on either side (meaning `{ a, b, ...}@args:`{.nix} can also be
used).

> Note: Default values specified in the argument destructuring are not applied
> to `args` in this case.

# `with` expressions

A `with` expression can be used to make the attributes of an attribute set
available for use in an expression. For example:

```nix
with {
  a = 4;
}; 5 + a # Here I can use a, because it's available from the with expression
# This file evaluates to 9
```

The general format for a `with` expression is the following:

```nix
with <attribute-set>; <expression>
```

# Builtins

Often the normal operators provided by the Nix language are not enough to
achieve your goals easily. That's where `builtins`{.nix} comes in.
`builtins`{.nix} is an attribute set where most of the attributes contain
functions. These functions are not coded in Nix, but are instead a part of Nix.

An example is `builtins.attrNames`{.nix} (`attrNames` stands for attribute
names):

```nix
builtins.attrNames {
  a = 4;
  b = 6;
} # Evaluates to [ "a" "b" ]
```

`builtins.attrNames`{.nix}, when passed an attribute set as argument, returns a
list of strings containing the names of the attributes.

There are many `builtins`{.nix} functions, but some are used so often that they
can be called without adding `builtins`{.nix}. An example is the
`toString`{.nix} builtin:

```nix
toString 5 # Evaluates to "5". Useful for string interpolation for example
```

Another example is the `map`{.nix} builtin:

```nix
map (x: x + 5) [ 1 2 3 ] # Evaluates to [ 6 7 8 ]
```

The `map`{.nix} builtin takes a function as argument and returns a function that
takes a list as argument. That function then returns the "mapped" list when
called. This is currying, as previously explained, which also works with
functions in `builtins`{.nix}!

For example I can make a _partially applied priomp_ function like this:

```nix
let
  # This is now a function that takes a list as input and returns a mapped list as output
  # Because `map` comes from `builtins`, it is called a partially applied priomp
  add5ToEachElement = map (x: x + 5);
in add5ToEachElement [ 1 2 ] # Evaluates to [ 5 6 ]
```

To find other `builtins`{.nix}, you can use the unofficial website
[noogle.dev](https://noogle.dev){target="\_blank"}. Note that for now you should
ignore all functions that don't begin with `builtins`{.nix}.

# Errors

The `assert` keyword and the `throw`{.nix} builtin can be used to cause errors
during the evaluation of an expression. The syntax for `assert` is the
following:

```nix
assert <condition>; <expression>
```

If the condition is false, then Nix will throw an error. If the condition is
true, then the expression will be returned.

The `throw`{.nix} builtin (one of the builtins that you don't need to write
`builtins`{.nix} for) can be used to throw an error with an error message:

```nix
throw "This is an error!"
```

# Importing other Nix files

If you want to split your Nix expression across multiple files, you can use the
`import`{.nix} builtin (which is also a builtin for which you don't need to
write `builtins`{.nix} for). The `import`{.nix} builtin takes a path as argument
and returns the expression contained in the imported Nix file. For example this
could be the content of `number.nix`:

```nix
1
```

And this could be the content of `sum.nix`:

```nix
import ./number.nix + 3
```

We can run the following command to ensure it all works as expected:

```bash
❯ nix-instantiate --eval --strict sum.nix
4
```

# Summary

- A Nix file is not "executed" from top to bottom, but rather _evaluated_ to a
  single value.
- A `let` binding can be used to assign values to names.
- Conditionals can be achieved with the `if` keyword, which always requires an
  `else` case.
- Nix has the following types: integer, float, boolean, string, path, null,
  attribute set, list, function.
- A Nix function always takes one argument and currying can be used to simulate
  taking multiple arguments.
- `builtins`{.nix} is an attribute set that contains various native functions
  that you can use.

What was discussed in this chapter was most of the Nix syntax commonly used, but
not all of it. In the next chapter we are going to discuss the evaluation of Nix
code, how it's lazy and how that allows you to do incredible things.
