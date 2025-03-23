In the previous chapter we introduced the nixpkgs library and some of the simple
utilities it provides. One of the things it also provides is the module system.
Let's see what it's all about!

> Note: Sometimes in this chapter some features might seem useless. It will
> become clear why they are so useful when, in future chapters, we introduce
> NixOS and how it works.

# The module system

The module system is a group of utilities allowing us to merge various so-called
"modules" into a final configuration. These modules can declare configurable
options and define their values. It is used to allow users to use Nix as a
language to configure a tool, the most notable of which is NixOS.

Let's make an example and say we want to make a tool which sends a greeting
message whenever we reboot our computer. We could create the following modules:

- A module that declares an `enableGreeting` configuration option. This will
  toggle the greeting message being sent or not.
- A module that declares a `greetingMessage` configuration option. This will
  contain the message to be sent on reboot.
- A module that declares a `finalCommand` configuration option. This will
  contain a command to be run at every reboot. We define its value in such way
  that its value depends on the values of `enableGreeting` and
  `greetingMessage`. It should contain the right command to either not send the
  message or send the message specified in `greetingMessage`.

We then let the user create a module that sets the value of `enableGreeting` and
`greetingMessage`. Once they do that, we collect all of these modules together
and pass them through the appropriate nixpkgs library function to create the
final configuration. This final configuration will be an attribute set
containing `enableGreeting`, `greetingMessage` and `finalCommand` with their
values. We could then simply evaluate the value of `finalCommand` and run the
output at every reboot. Thanks to its value depending on the value of the other
two, it will already contain the correct command, all done in Nix!

# A practical example

Understanding all of this without having seen one bit of Nix code about the
module system is probably pretty hard. To better understand it, let's create the
example we just described above!

The module system is quite big, to the point where it's split across three
different sub-libraries: `modules`, `options` and `types`. The most important
function in the module system is `lib.modules.evalModules`{.nix}, or just
`lib.evalModules`{.nix}. It's the entry point of the module system: the function
to which we pass our modules and from which we get the final configuration.

It takes an attribute set as argument. This attribute set contains some
parameters to be used by `lib.evalModules`{.nix}. One of these, the most
important, is `modules`: a list of modules to be merged together into the final
configuration. Let's try it out with an empty list of modules!

> Note: In the following examples I will not include the code to import `lib`,
> you can find it in the previous chapter.

```nix
lib.evalModules {
  modules = [ ];
}
```

This is the output (not strictly evaluated):

```bash
❯ nix-instantiate --eval no-modules.nix
{ _module = <CODE>; _type = "configuration"; class = null; config = <CODE>; extendModules = <CODE>; options = <CODE>; type = <CODE>; }
```

It's an attribute set containing various attributes. Here are the two most
important for now:

- `config` - This is the final merged configuration.
- `options` - This contains all the options we declared and their information.

We can use the `-A config` flag in the `nix-instantiate` command to access the
`config` attribute:

```bash
❯ nix-instantiate --eval no-modules.nix -A config
{ }
```

As you might have expected, it's an empty attribute set. This makes sense
considering we passed an empty module list, meaning we didn't declare or define
any options.

## Anatomy of a module

Before we can actually make the `lib.evalModules`{.nix} function useful for us,
we have to learn about the structure of a module and how to create one.

A module in Nix can be one of three things:

- An attribute set.
- A function that returns an attribute set. We'll talk about what it receives as
  argument later.
- A path to a Nix file which evaluates to one of the two other options.

Notice how all three of these in the end produce an attribute set, which is the
actual content of the module. This attribute set can contain the so-called
"top-level" attributes, such as:

- `imports`: A list of other modules to include (meaning a list of paths,
  attribute sets or functions).
- `options`: An attribute set containing the configuration options to be
  declared.
- `config`: An attribute set containing the values to set the configuration
  options to.

These are the other top-level attributes, but they won't be discussed for now,
as they are not important at the moment:

- `_class`
- `_file`
- `key`
- `disabledModules`
- `meta`
- `freeformType`

Let's write a module and test it out! We'll declare an option under `options` by
using the `lib.options.mkOption` function and the `lib.types.str` type. We'll
then set its value in the `config` attribute.

```nix
let
  # In this case, we use an attribute set
  myModule = {
    # Declare `myFirstOption` in `options`.
    # Remember that a.b = x is the same as a = { b = x; };
    options.myFirstOption = lib.mkOption {
      type = lib.types.str;
    };

    # Define its value in `config`.
    config.myFirstOption = "Hello, World!";
  };
in
lib.evalModules {
  modules = [ myModule ];
}
```

If we now run the command to evaluate the `config` attribute strictly, this is
what we get:

```bash
❯ nix-instantiate --eval --strict first-call.nix -A config
{ myFirstOption = "Hello, World!"; }
```

Our option is in the final configuration! Let's dive a bit deeper in the library
attributes we used.

### `lib.options.mkOption`

This function is used to declare options in the `options` attribute set. It
takes an attribute set containing various attributes as argument. Some of the
most used attributes are:

- `type`: The type of the option. In this case we used `lib.types.str`, which is
  one of the types for a string.
- `description`: The description of the option. Nixpkgs provides code that can
  generate documentation directly from the output of `lib.evalModules`!
- `default`: The default value of the option.

If you're interested in the other options and what they do, you can read the
documentation for `lib.options.mkOption`
[here](https://nixos.org/manual/nixpkgs/unstable/#function-library-lib.options.mkOption){target="\_blank}.

`lib.options.mkOption` is actually a very simple function, so much that we can
just look at its
[source code](https://github.com/NixOS/nixpkgs/blob/2c8df39b2ab5f3ebad61ad36bb6538f5f101a0d6/lib/options.nix#L135){target="\_blank"}
to understand what its output is:

```nix
mkOption =
  {
    default ? null,
    defaultText ? null,
    example ? null,
    description ? null,
    relatedPackages ? null,
    type ? null,
    apply ? null,
    internal ? null,
    visible ? null,
    readOnly ? null,
  } @ attrs:
  attrs // { _type = "option"; };
```

It returns the attribute set we provided as input, but it updates it with the
`_type` attribute. It's important to note that it also checks we didn't
accidentally pass in additional attributes (as mentioned in the first chapter,
argument destructuring is strict in checking).

You might be confused by the fact that it does almost nothing. How are we
declaring the option then? Well, it's simple: the heavy work is actually done
inside of `lib.evalModules` and the functions it calls! It reads your modules,
parses them, and does what you expect it to.

### `lib.types.str`

We used `lib.types.str` as type when declaring the option. Let's look at its
[source code](https://github.com/NixOS/nixpkgs/blob/2c8df39b2ab5f3ebad61ad36bb6538f5f101a0d6/lib/types.nix#L458){target="\_blank"}
to understand what it is:

```nix
str = mkOptionType {
  name = "str";
  description = "string";
  descriptionClass = "noun";
  check = isString;
  merge = mergeEqualOption;
};
```

It seems to use another function: `lib.types.mkOptionType`. It gives it a name
and description for the type, along with check and merge functions. The check
will be used to ensure the value to which the option is set is indeed a string.
We won't learn about `lib.types.mkOptionType` for now, but we'll learn more
about types later.

> Note: This will be discussed in future chapters, but, as a spoiler, your NixOS
> `configuration.nix` is a module!

## Building our example

Now that we roughly learned what a module looks like, we can start to build our
example and learn even more about modules and what they can do. Let's start with
the simple task, which is to create a module that declares the `enableGreeting`
and `greetingMessage` options:

```nix
{
  options = {
    # Note that there is a shorter way to do exactly this:
    # `enableGreeting = lib.mkEnableOption "the greeting system";`
    # would achieve the same as what we do below.
    enableGreeting = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true; # For documentation
      description = "Whether to enable the greeting system."; # For documentation
    };

    greetingMessage = lib.mkOption {
      type = lib.types.str;
      example = "Greetings, fellow NixOS user!"; # For documentation
      description = "The greeting message to send."; # For documentation
    };
  };
};
```

Simple enough! Now, in order to make the module that declares and defines
`finalCommand` based on the other configuration options, we need to take a look
at modules that are functions. We can for example create a module like this:

```nix
{ ... }:

{
  /** My module's attributes */
}
```

That leaves the question: what attributes do we receive in the argument? Many
actually! For now, we'll just focus on one of them: `config`. It is one of the
arguments we receive and its value is the final configuration output. Yes! The
`config` we receive is exactly the attribute set that we evaluate when running
`nix-instantiate --eval --strict our-file.nix -A config`{.bash}: part of the
output of the `lib.evalModules` function call. This is possible thanks to Nix's
laziness and recursion mechanics, as explained in the second chapter.

If we use it carefully, we can avoid infinite recursion errors and achieve our
goal:

```nix
# Another useful argument we receive is `lib`! If this module was in another file
# and was included via path, we could use it to access `lib` anyways.
{ config, lib, ... }:

{
  # Declare the `finalCommand` option.
  options.finalCommand = lib.mkOption {
    type = lib.types.str;
    example = "echo \"Hello there!\""; # For documentation
    description = "The command to execute at every reboot."; # For documentation
  };

  # Define its value.
  config.finalCommand = if config.enableGreeting then
      # The `lib.escapeShellArg` function makes sure the greeting is escaped properly!
      "echo ${lib.escapeShellArg config.greetingMessage}"
    else
      # The `true` command does nothing and exits successfully
      "true";
}
```

Let's try to pass these modules to `lib.evalModules`{.nix}:

```nix
let
  firstModule = {
    options = {
      enableGreeting = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Whether to enable the greeting system.";
      };

      greetingMessage = lib.mkOption {
        type = lib.types.str;
        example = "Greetings, fellow NixOS user!";
        description = "The greeting message to send.";
      };
    };
  };

  secondModule =
    { config, ... }:
    {
      options.finalCommand = lib.mkOption {
        type = lib.types.str;
        example = "echo \"Hello there!\"";
        description = "The command to execute at every reboot.";
      };

      config.finalCommand =
        if config.enableGreeting then
          "echo ${lib.escapeShellArg config.greetingMessage}"
        else
          "true";
    };
in
lib.evalModules {
  modules = [
    firstModule
    secondModule
  ];
}
```

Let's try to evaluate the full value of `config`:

```bash
❯ nix-instantiate --eval --strict all-declarations.nix -A config
error:
       … while evaluating the attribute 'greetingMessage'

       … while evaluating the attribute 'value'
         at /nix/store/7g9h6nlrx5h1lwqy4ghxvbhb7imm3vcb-source/lib/modules.nix:927:9:
          926|     in warnDeprecation opt //
          927|       { value = addErrorContext "while evaluating the option `${showOption loc}':" value;
             |         ^
          928|         inherit (res.defsFinal') highestPrio;

       … while evaluating the option `greetingMessage':

       (stack trace truncated; use '--show-trace' to show the full, detailed trace)

       error: The option `greetingMessage' was accessed but has no value defined. Try setting the option.
```

Looks like we got an error. The reason for this error is that we tried to
evaluate `config` strictly, which asked for the value of `greetingMessage`. We
never set a default for `greetingMessage`, nor did we set a value for it.
Thankfully `lib.evalModules`{.nix} informs us of this problem with the following
part of the error message:

```
error: The option `greetingMessage' was accessed but has no value defined. Try setting the option.
```

This error doesn't happen if we just evaluate `enableGreeting` though!

```bash
❯ nix-instantiate --eval --strict all-declarations.nix -A config.enableGreeting
false
```

That's because the evaluation of `enableGreeting` does not depend on the
evaluation of the values of the other options and Nix uses lazy evaluation, as
seen in the previous chapters.

## Writing the user configuration

Let's now write the configuration file a user might write. We'll call it
configuration.nix:

```nix
{
  enableGreeting = true;
  greetingMessage = "Hey, don't forget how awesome this is!";
}
```

You might notice how we removed the `config` in `config.enableGreeting`{.nix}
and `config.greetingMessage`{.nix}. We can do this in the module system because
all modules that don't have the `options` and `config` top-level attributes are
considered to almost only contain attributes that go in `config`. This feature
is simply a shortcut to avoid always having to write `config`. Note that you can
still use `imports` and the other top-level attributes. For example, even though
almost everything else is going in `config`, we can still use `imports` in this
module:

```nix
{
  imports = [
    # This is another module that we include
    {
      enableGreeting = true;
    }
  ];
  greetingMessage = "Hey, don't forget how awesome this is!";
}
```

We can now edit our previous file to include the path
`./configuration.nix`{.nix} as a module:

```nix
/** --- snip --- */
lib.evalModules {
  modules = [
    firstModule
    secondModule
    ./configuration.nix
  ];
}
```

Let's try to evaluate the full value of `config`:

```bash
❯ nix-instantiate --eval --strict all-declarations.nix -A config
{ enableGreeting = true; finalCommand = "echo 'Hey, don'\\''t forget how awesome this is!'"; greetingMessage = "Hey, don't forget how awesome this is!"; }
```

It works! Our software could also just evaluate the `config.finalCommand`{.nix}
value to get the command to run at every reboot:

```bash
❯ nix-instantiate --eval --strict all-declarations.nix -A config.finalCommand
"echo 'Hey, don'\\''t forget how awesome this is!'"
```

# A few more details

Now that we've seen a practical example for the usage of
`lib.evalModules`{.nix}, let's take a deeper look at its features. One of those
is that options can be in nested attribute sets:

```nix
# This is a module
{
  options.a.b.c.d = lib.mkOption {
    type = lib.types.str;
  };

  config.a.b.c.d = "Deeply nested...";
}
```

The module system knows that `options.a`{.nix} is not an option because it
doesn't have the `_type` attribute set to `option`. It therefore assumes that
it's simply a "category" for more options or more "sub-categories".

In case it was not already clear, options and their definitions can be split
across multiple modules:

```nix
let
  module1 = {
    options.a.b.c.d = lib.mkOption {
      type = lib.types.str;
    };
  };

  module2 = {
    config.a.b.c.d = "Deeply nested...";
  };
in (lib.evalModules {
  modules = [
    module1
    module2
  ];
}).config # Evaluates to { a.b.c.d = "Deeply nested..."; }
```

In addition, by default, all option definitions must be for a valid option
(meaning an option that was properly declared). The following throws an error
for example:

```nix
(lib.evalModules {
  modules = [
    {
      config.notExisting = "Does this work?";
    }
  ];
}).config
```

Here it is:

```bash
❯ nix-instantiate --eval problematic.nix
error:
       … while evaluating the attribute 'config'
         at /nix/store/7g9h6nlrx5h1lwqy4ghxvbhb7imm3vcb-source/lib/modules.nix:336:9:
          335|         options = checked options;
          336|         config = checked (removeAttrs config [ "_module" ]);
             |         ^
          337|         _module = checked (config._module);

       … while calling the 'seq' builtin
         at /nix/store/7g9h6nlrx5h1lwqy4ghxvbhb7imm3vcb-source/lib/modules.nix:336:18:
          335|         options = checked options;
          336|         config = checked (removeAttrs config [ "_module" ]);
             |                  ^
          337|         _module = checked (config._module);

       (stack trace truncated; use '--show-trace' to show the full, detailed trace)

       error: The option `notExisting' does not exist. Definition values:
       - In `<unknown-file>': "Does this work?"

       It seems as if you're trying to declare an option by placing it into `config' rather than `options'!
```

This check ensures that the user creates their configuration in the way that was
intended.

# Types

Let's take a quick look at some (but far from all) of the types that the library
gives us. You can find the full list
[here](https://nixos.org/manual/nixos/unstable/#sec-option-types){target="\_blank"}.
Note that while previously we were looking at the nixpkgs manual, this time it's
the NixOS manual.

## Basic types

There are some basic types which are pretty much self-explanatory. Some examples
(but not all) are:

- `lib.types.bool`
- `lib.types.str`
- `lib.types.int`
- `lib.types.float`
- `lib.types.number`
- `lib.types.path`

# Union types

These types allow values that match at least one of the types specified. Their
`lib.types`{.nix} value is a function that can be used with other types. For
example, there is `lib.types.nullOr`{.nix}. This signifies that the value may
either be `null`{.nix} or the type passed as argument:

```nix
lib.types.nullOr lib.types.str # Value should be null or of type str
```

They include the following types:

- `lib.types.either t1 t2`{.nix}: The value is either of type `t1` or of type
  `t2`.
- `lib.types.oneOf [ t1 t2 t3 ... ]`{.nix}: The value must be of one of the
  types specified in the list.
- `lib.types.nullOr t`{.nix}: The value must either be null or of type `t`.

# Composed types

Composed types are similar to union types. Their `lib.types` attribute is a
function that takes another type as argument in some way. Good examples are
`lib.types.listOf t`{.nix} and `lib.types.attrsOf t`{.nix}. For the former, the
value must be a list of elements of type `t`. For the latter, the value must be
an attribute set where the values of the attributes are of type `t`.

# Merging definitions

Now that we've seen the basics of the module system and learned about some
types, we can finally talk about one of the main features of
`lib.evalModules`{.nix}: multiple definitions can be merged together. Remember
how in the definition of `lib.types.str`{.nix} we noticed that there was a
`merge` function? The same option can be defined multiple times and the
definitions merged using that function. In the case of `lib.types.str`{.nix},
the merge function was `lib.options.mergeEqualOption`{.nix}, which only allows
merging if the values are the same. While that may not be so useful, many types
allow merging in more interesting ways.

Let's for example take a look at `lib.types.attrsOf lib.types.int`{.nix}.
According to the `merge` function of `lib.types.attrsOf`, multiple definitions
that contain different attributes are merged together in an attribute set that
contains all of the defined attributes:

```nix
(lib.evalModules {
  modules = [
    {
      options.attrs = lib.mkOption {
        type = lib.types.attrsOf lib.types.int;
      };
    }
    {
      attrs.first = 1;
    }
    {
      attrs.second = 2;
    }
  ];
}).config
# Evaluates to { attrs = { first = 1; second = 2; }; }
```

Many types are merged in the way you would expect them to. For example
`lib.types.listOf t`{.nix} merges its definitions by concatenating the lists.

# Overriding values

Sometimes you might be in a situation where a module you cannot control (for
example one that is included by default) sets a value for an option. If you add
your own different value in your modules, the module system will try merging
them. If you simply want to override the other value, you can use the
`lib.mkOverride`{.nix} function. Its
[source code](https://github.com/NixOS/nixpkgs/blob/42fdc23519c00b2b8e7edb9231d86ce485815659/lib/modules.nix#L1188){target="\_blank"}
is very simple, so we can just look at it to understand how to use it:

```nix
mkOverride = priority: content:
  { _type = "override";
    inherit priority content;
  };
```

It takes a priority and your value as arguments (via currying). It then returns
an attribute set with a `_type`{.nix} attribute, the priority and your value.
Just like for `lib.mkOption`{.nix}, the function can be so simple because most
of the logic is handled by `lib.evalModules`{.nix} and the various functions it
uses.

The priority tells the module system whether your definition is more or less
important than other definitions. The values with the **lowest** priority are
used. If there are multiple, they will be merged. Option definitions that don't
use `lib.mkOverride`{.nix} have a default priority of `100`{.nix}.

There are functions such as `lib.mkForce`{.nix} which you can use to avoid
having to specify the priority yourself.
[Here](https://github.com/NixOS/nixpkgs/blob/42fdc23519c00b2b8e7edb9231d86ce485815659/lib/modules.nix#L1197){target="\_blank"}
is the definition of `lib.mkForce`{.nix}:

```nix
mkForce = mkOverride 50;
```

It can be used like this:

```nix
(lib.evalModules {
  modules = [
    {
      options.overriding = lib.mkOption {
        type = lib.types.int;
      };
    }
    {
      overriding = 1; # Uses default priority: 100
    }
    {
      overriding = lib.mkForce 2; # Uses priority 50
    }
  ];
}).config
# Evaluates to { overriding = 2; }
```

> Note: The `default` value of an option is simply an option definition with
> priority `1500`{.nix}.

# Summary

- The nixpkgs library provides the module system as an utility for configuring
  tools.
- `lib.evalModules`{.nix} is the main function of the module system and, among
  other attributes, takes the `modules` attribute as argument.
- Modules are attribute sets, functions or paths that point to a file containing
  one of the first two options.
- A module can contain option declarations or definitions, as well as import
  other modules.
- By default, all option definitions must have a corresponding option
  declaration.
- Multiple option definitions can be merged according to the type's `merge`
  function, which may also deny the merge.
- The `lib.mkOverride`{.nix} function can be used to override another definition
  without merging with it.

There is **much** more to learn about the module system, which is why its
explanation is split across multiple chapters of this guide. Before we can
continue learning more about the module system by creating a custom mini-NixOS
(almost) from scratch, we must take a detour to learn about derivations, which
are the topic of the next chapter. See you there!
