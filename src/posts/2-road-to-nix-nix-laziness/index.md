In the previous chapter we learned about the syntax of Nix and how every Nix
file evaluates to a single value. In this chapter we will learn how this
evaluation happens, some of its quirks and why they allow us to do incredible
things. Note that understanding this topic is **crucial** to understanding many
of the other chapters. Let's jump right in!

# Lazy evaluation in Nix

Nix uses something called "Lazy evaluation": only what is requested is
evaluated. Let's make a simple example using a `let` binding:

```nix
let
  a = throw "If this is ever evaluated, Nix will throw an error";
  b = 1;
in b + 1
```

This example evaluates to `2`{.nix} without throwing any errors. Why? `a` is never requested, so it's never evaluated.

To better understand this behaviour, it helps to understand the order in which
Nix evaluates Nix expressions. While it is true that Nix doesn't execute
instructions sequentially, like other traditional programming languages do, you
can think of Nix as going backwards through your code. It's important to note
that I don't mean backwards as in bottom to top here, but rather logically
backwards.

Let's make an example:

```nix
let
  a = throw "If this is ever evaluated, Nix will throw an error";
  b = 1;
  c = b + 1;
in c + 2
```

Let's go through the code "logically backwards".

1. We start at the result, which is `c + 2`{.nix}. We notice that in order to
   evaluate it, we need to evaluate the value of `c`.

2. We notice that the value of `c` is `b + 1`{.nix}. In order to evaluate
   `b + 1`{.nix}, we must evaluate the value of `b`.

3. We notice that the value of `b` is `1`{.nix}, which is already fully
   evaluated!

4. Since we know `b`, we can now go backwards through our process and finally
   evaluate the value `c`, which is `b + 1`{.nix}. We figure out it evaluates to
   `2`{.nix}.

5. Now that we know the value of `c`, we can go back to evaluating
   `c + 2`{.nix}. We calculate that it is equal to `4`{.nix}.

6. We know `c + 2`{.nix} was the result of the full evaluation, so we're done!
   The result is indeed `4`{.nix}.

As you can see, nowhere in this lazy evaluation process did we evaluate the
problematic `a`.

This also implies that the order in which we define our assignments in a `let`
binding does not matter! This works perfectly well:

```nix
let
  c = b + 1;
  b = 1;
  a = throw "If this is ever evaluated, Nix will throw an error";
in c + 2
```

# Laziness of compound types

Attribute sets are also lazily evaluated. This means the following will work
just fine and won't throw an error:

```nix
{
  a = throw "an error";
  b = 3;
}.b # We only access b, therefore only b is evaluated
```

The same applies to lists! Let's look at an example. We can use the
`builtins.elemAt xs n`{.nix} function to get the element at index `n` from the
list `xs`. Note that usually in Nix lists are zero-indexed, which means the
index starts at 0. Here we use the `builtins.elemAt`{.nix} function to get the
2nd element of the list:

```nix
builtins.elemAt [ (throw "an error") "It's working!" ] 1
# This file successfully evaluates to "It's working!"
```

This doesn't throw an error because the error is never evaluated thanks to lazy
evaluation.

> Note: We had to use parentheses because the space that separates list items
> has a higher priority than the space used to call functions. In other words,
> the following evaluates to `"an error"`{.nix}:
>
> ```nix
> builtins.elemAt [ throw "an error" "It's working!" ] 1
> ```
>
> The list in this case contains a partially applied priomp and two strings.

# Laziness of conditionals

Conditionals are also evaluated lazily! The following evaluates to
`"It's working!"`{.nix}:

```nix
if false then throw "an error" else "It's working!"
```

# Self-referencing

Thanks to laziness and recursion, when defining a value in an assignment we can
refer to its own "future" value:

```nix
let
  attrs = {
    a = attrs.b + 1;
    b = 1;
  };
in attrs.a
```

You might think that this would be a problem because in order to define `attrs`
we need to know the value of `attrs`, but it actually works and correctly
evaluates to `2`{.nix}. This is thanks to the lazy evaluation of attribute sets:
when we ask for `attrs.b`{.nix}, we are not asking for the full value of
`attrs`, but rather only for the value of `attrs.b`{.nix}.

Let's go through this example using our previously developed mental model:

1. The result we want is `attrs.a`{.nix}. This requires the evaluation of
   `attrs.a`{.nix}.

2. We notice `attrs.a`{.nix} is `attrs.b + 1`{.nix}. In order to evaluate that,
   we require the evaluation of `attrs.b`{.nix}.

3. `attrs.b`{.nix} is already fully evaluated and is simply `1`{.nix}!

4. We start going backwards through our process and evaluate `attrs.a`{.nix},
   which is `attrs.b + 1`{.nix}. We can calculate that it's `2`{.nix} because we
   now know `attrs.b`{.nix}.

5. We now have `attrs.a`{.nix}, which is what we wanted. We are done and the
   result is `2`{.nix}.

Notice how in our process, I did not say we needed to evaluate `attrs`{.nix},
but rather `attrs.b`{.nix}. This is because attribute sets are evaluated lazily!

# Self-referencing through functions

We can take this a step further by passing it through functions:

```nix
let
  myFunc = arg: {
    a = 1;
    b = arg.a + 1;
  };
  res = myFunc res;
in res.b
```

We are passing `myFunc`'s "future output" to itself, yet it works and
successfully evaluates to `2`{.nix}! Let's use our mental model once again:

1. The result is `res.b`{.nix}, for which we need to evaluate `res.b`{.nix}.

2. Because `res = myFunc res`{.nix}, `res.b = <output-of-myFunc>.b`{.nix} when
   `myFunc` is called with `res`.

3. We notice that `<output-of-myFunc>.b`{.nix} is `res.a + 1`{.nix}, which, to
   be evaluated, requires the evaluation of `res.a`{.nix}.

4. Because `res = myFunc res`{.nix}, `res.a = <output-of-myFunc>.a`{.nix} when
   `myFunc` is called with `res`.

5. We notice that `<output-of-myFunc>.a` is `1`{.nix}, which is already fully
   evaluated!

6. We can go backwards through our process and evaluate `res.a`{.nix}, which we
   already said is just `<output-of-myFunc>.a`{.nix}, which is `1`{.nix}.

7. We continue going backwards and now calculate `<output-of-myFunc>.b` which is
   `res.a + 1`{.nix}: `2`{.nix}.

8. We calculate `res.b`{.nix}, which is just `<output-of-myFunc>.b`:
   `2`{.nix} again.

9. We now have `res.b`{.nix}, which is the result we wanted. The final output is
   `2`{.nix}.

# Laziness through imports

As we saw in the previous chapter, the `import`{.nix} builtin can be used to
import the expression defined in another Nix file into the current one. This
importing is also lazy, meaning that the expression in the imported file is not
fully evaluated, but rather only the parts that are requested are evaluated.

# Infinite recursion

After seeing these examples, you might be curious about what would happen if you
did something like this:

```nix
let
  attrs = {
    a = 1;
    b = attrs.a + attrs.b;
  };
in attrs.b
```

Wouldn't this be a paradox? After all, it simplifies to `b = 1 + b`{.nix}, which
is clearly a paradox, right? It is indeed! Even Nix's laziness and recursion
mechanics cannot save us from this issue. This is the error we get when trying
to evaluate the above:

```bash
❯ nix-instantiate --eval --strict infinite-recursion.nix
error:
       … while evaluating the attribute 'b'
         at /home/tobor/infinite-recursion.nix:4:5:
            3|     a = 1;
            4|     b = attrs.a + attrs.b;
             |     ^
            5|   };

       … while evaluating the attribute 'b'
         at /home/tobor/infinite-recursion.nix:4:5:
            3|     a = 1;
            4|     b = attrs.a + attrs.b;
             |     ^
            5|   };

       error: infinite recursion encountered
       at /home/tobor/infinite-recursion.nix:4:5:
            3|     a = 1;
            4|     b = attrs.a + attrs.b;
             |     ^
            5|   };
```

Nix throws an _infinite recursion_ error! We can find out why this happens by
using our mental model. If we tried to do that, we would always be repeating the
same steps over and over and never finish. That's exactly what Nix notices!
Indeed, you can even see in its
[stack trace](https://en.wikipedia.org/wiki/Stack_trace){target="\_blank"}
(information about what Nix was doing when the error happened) that it's using
exactly our mental model and notices that it did the same step twice. If a step
is dependent on doing the same exact step over and over again, and if you keep
executing those steps, you will never stop. An _infinite_ list of steps to
execute!

So, from this, not only do we learn that Nix doesn't allow us to break the laws
of logic, but we also learn that our mental model is not just a mental model,
but rather pretty much exactly what Nix does when evaluating your file.

Note that this infinite recursion is only encountered if we ask for the
attribute `b`. This does not cause infinite recursion and evaluates to
`1`{.nix}:

```nix
let
  attrs = {
    a = 1;
    b = attrs.a + attrs.b;
  };
in attrs.a # We only require knowing the attribute a
```

# Repetition

And neither does this, which evaluates to `1`{.nix}:

```nix
let
  attrs = {
    a = 1;
    b = attrs;
  };
in attrs.b.b.a
```

You might be wondering why having `attrs` contain itself is not a problem. The
reason is simple: we are not asking to evaluate `attrs`, but rather
`attrs.b.b.a`{.nix}!

Let's try to evaluate the full value of `attrs`:

```nix
let
  attrs = {
    a = 1;
    b = attrs;
  };
in attrs
```

Here is what Nix has to say:

```bash
❯ nix-instantiate --eval --strict repeated.nix
{ a = 1; b = «repeated»; }
```

Even this is not a problem! Nix recognizes that the value is _repeated_ by using
our mental model. Still, Nix is kind of cheating and not actually evaluating the
full value of `attrs`. We can get it to evaluate the full value if we try to
convert the result to
[JSON](https://www.json.org/json-en.html){target="\_blank"}.

We can use the `--json` flag to get Nix to write the result in JSON. Let's try
that:

```bash
❯ nix-instantiate --eval --strict --json repeated.nix
zsh: segmentation fault (core dumped)  nix-instantiate --eval --strict --json repeated.nix
```

Looks like Nix crashed! It failed to recognize the repetition and this is
probably a bug, but as you can see it cannot fully evaluate the value. That's of
course because the full value would be infinitely large!

While we're talking about flags, it's a good time to explain what the
`--strict` flag is doing here. It is telling Nix to fully evaluate the value
rather than to be lazy about its evaluation. Let's try to evaluate the following
file without the `--strict` flag:

```nix
{
  a = {
    b = 1;
  }; # Note that I could've just written a.b = 1;, but didn't for simplicity
  c = 2;
}
```

Here is the output:

```bash
❯ nix-instantiate --eval non-strict.nix
{ a = <CODE>; c = 2; }
```

Nix doesn't bother fully evaluating the value, but only shows us a part of it!
This is Nix using lazy evaluation and deciding to be lazy when showing us the
result.

# Self-referencing through conditionals

While conditionals are indeed lazy in their evaluation, their condition cannot
depend on their output. Let's look at an example:

```nix
let
  a = {
    cond = true;
    msg = "It's A!";
  };
  b = {
    cond = true;
    msg = "It's B!";
  };
  res = if res.cond then a else b;
in res.msg
```

While in the eyes of a human this would clearly evaluate to `"It's A!"`{.nix},
Nix does **not** allow this behaviour:

```bash
❯ nix-instantiate --eval --strict not-working.nix
error:
       … while evaluating a branch condition
         at /home/tobor/not-working.nix:10:9:
            9|   };
           10|   res = if res.cond then a else b;
             |         ^
           11| in

       error: infinite recursion encountered
       at /home/tobor/not-working.nix:10:12:
            9|   };
           10|   res = if res.cond then a else b;
             |            ^
           11| in
```

# Summary

- Nix uses lazy evaluation, meaning values are only evaluated if they are
  requested.
- Nix evaluates your code from end to start, meaning it tries to evaluate the
  final result first and evaluates its dependencies to do so.
- Nix allows recursion: Values can refer to themselves in their definition.
- Nix allows repetition: Values can contain themselves.

Nix's lazy evaluation and recursion is at the very core of how nixpkgs and NixOS
work! We'll see this in future chapters. In the next chapter, you're going to
learn about [nixpkgs](https://github.com/NixOS/nixpkgs){target="\_blank"} and
its library.
