If you tried to look at the list of `builtins`{.nix} functions, you probably
noticed that many are very basic. Nix is not the only language to provide few
advanced helper functions. In fact, many programming languages have very basic
language features and then provide a standard library that the user can include
(or one that is automatically included) to gain access to more advanced
utilities. Thankfully, there's an official project that can help provide more
helper functions for Nix:
[nixpkgs](https://github.com/NixOS/nixpkgs){target="\_blank"}.

# Introduction to Nixpkgs

Nixpkgs is pretty much just a bunch of Nix code in a GitHub repository. You
might have heard of it because it contains over 100000 packages and is the
official source of packages for NixOS, but that's not all that it has. Among the
many, one of the other things it provides is a library for Nix containing
various useful functions. Because nixpkgs is an official project of the NixOS
Foundation, you can think of this library as the standard library of Nix!

As for all the other useful code nixpkgs contains, such as the one providing the
already mentioned packages, it will be discussed in future chapters.

# Anatomy of the library

If we want to understand how the nixpkgs library works, we should start by
finding out where it is located and looking there. If you open the
[nixpkgs repository](https://github.com/NixOS/nixpkgs/), you might notice a
`lib` folder. That is indeed where most of the code for the nixpkgs library is
contained. In the `lib` folder there is a `README.md` which gives us some
information about this library. The following comes directly from the start of
that file:

```md
The evaluation entry point for `lib` is [`default.nix`](default.nix). This file
evaluates to an attribute set containing two separate kinds of attributes:

- Sub-libraries: Attribute sets grouping together similar functionality. Each
  sub-library is defined in a separate file usually matching its attribute name.

  Example: `lib.lists` is a sub-library containing list-related functionality
  such as `lib.lists.take` and `lib.lists.imap0`. These are defined in the file
  [`lists.nix`](lists.nix).

- Aliases: Attributes that point to an attribute of the same name in some
  sub-library.

  Example: `lib.take` is an alias for `lib.lists.take`.
```

It informs us that `default.nix` is the main file and that it evaluates to an
attribute set. It already sounds similar to `builtins`{.nix}, which is also an
attribute set! It also lets us know that library functions are divided in
sub-libraries, which are accessible from the main attribute set as attributes.

These are some examples of sub-libraries:

- `strings` - Contains functions related to string manipulation.
- `lists` - Contains functions for general list operations.
- `licenses` - Contains information about various copyright licenses.

These sub-libraries are themselves simply attribute sets. Most of the useful
attributes from these attribute sets are then also inherited in the main
library's attribute set.

In addition, the nixpkgs library also inherits most of the `builtins`{.nix}. For
example, it means that using `lib.map`{.nix} is the same as using
`builtins.map`{.nix}.

> Note: Not all of the `builtins`{.nix} are left unchanged. An example is
> `lib.functionArgs`{.nix}, which is slightly different from
> `builtins.functionArgs`{.nix}. Explaining the reason for this difference is
> beyond the purpose of this chapter, but only few `builtins`{.nix} are actually
> changed, so you shouldn't worry too much about this.

# Importing the library

Enough theory, let's try it out! There are various ways to import nixpkgs, but
for now we'll pick the one which uses features we already learned in previous
chapters: using `builtins`{.nix}. We can use the `builtins.fetchTarball`
function to download the source code tarball from GitHub and verify its hash.

To do that, we must choose which branch to use. Nixpkgs has many git branches
serving different purposes. The ones we are interested in are the ones paired
with NixOS releases. NixOS' release cycle aims for a release every 6 months,
which corresponds to a new branch named after the year and month of the release:

- nixos-24.11
- nixos-24.05
- nixos-23.11
- nixos-23.05
- nixos-22.11
- ...

In addition, there is a `nixos-unstable` branch which corresponds to the next
NixOS release (which, at the time of writing, is NixOS 25.05).

We'll use the `nixos-unstable` branch for now, which means we'll use the URL
`https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz`. To ensure
reproducibility, we'll need the hash of its contents, which we can obtain with
the following command:

```bash
❯ nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz
path is '/nix/store/mydjm57miy0p6lv66asan2rf53a5fah8-nixos-unstable.tar.gz'
053xxy1bn35d9088h3rznhqkqq7lnnhn4ahrilwik8l4b6k8inlq
```

> Note: If you are familiar with Git and GitHub, you can specify a revision by
> adding `?rev=<revision>` at the end of the URL to ensure you don't need to
> change the hash too often because of `nixos-unstable` updating.

We can now use the `builtins.fetchTarball`{.nix} function to download the
tarball:

```nix
builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  # You have to use the hash you got from the previous command here!
  sha256 = "053xxy1bn35d9088h3rznhqkqq7lnnhn4ahrilwik8l4b6k8inlq";
}
```

Let's evaluate the Nix file:

```bash
❯ nix-instantiate --eval download-nixpkgs.nix
unpacking 'https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz' into the Git cache...
"/nix/store/1728d3jg85mkz2w2cvk6vi74i30fn6x7-source"
```

It seems it gave us a string containing a path. Let's see what that folder
contains:

```bash
❯ ls /nix/store/1728d3jg85mkz2w2cvk6vi74i30fn6x7-source
ci               COPYING      doc        lib          nixos  README.md
CONTRIBUTING.md  default.nix  flake.nix  maintainers  pkgs   shell.nix
```

> Note: The path here is in the Nix store (`/nix/store`). This topic will be
> discussed in a future chapter.

It contains the nixpkgs source code! Thanks to the complex relation between
strings and paths in Nix, we can import this path using the `import`{.nix}
builtin. Note that we are importing a folder. When we do that, Nix will look for
a `default.nix` file in that folder and import it instead.

```nix
let
  nixpkgsPath = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "053xxy1bn35d9088h3rznhqkqq7lnnhn4ahrilwik8l4b6k8inlq";
  };
in
import nixpkgsPath
```

Here is the output:

```bash
❯ nix-instantiate --eval import-nixpkgs.nix
<LAMBDA>
```

Looks like the value of the `default.nix` file of nixpkgs is a function. This
function is the entry point of nixpkgs and expects the "settings" we wish to set
for nixpkgs as argument. This sounds complicated: let's instead directly import
the `lib` folder we previously learned about:

```nix
let
  nixpkgsPath = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "053xxy1bn35d9088h3rznhqkqq7lnnhn4ahrilwik8l4b6k8inlq";
  };
in
import (nixpkgsPath + "/lib")
```

Evaluating this gives us an attribute set with many attributes. We did it! That
is indeed the library.

# Using the library

Let's try it out. Let's say we have a string and want to find out whether it
starts with `"/home"`{.nix} or not. For this task, we could use the
`builtins.match`{.nix} function, but that would require writing an extended
POSIX regular expression, which sounds scary. We can instead use one of the
functions available in the `strings` sub-library: `lib.strings.hasPrefix`. It is
a function that takes two arguments (via currying, see the
[first chapter](/posts/1-road-to-nix-nix-syntax#function){target="\_blank"} if
you don't know what that means) and returns a boolean.

```nix
let
  nixpkgsPath = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "053xxy1bn35d9088h3rznhqkqq7lnnhn4ahrilwik8l4b6k8inlq";
  };
  lib = import (nixpkgsPath + "/lib");
in
{
  first = lib.strings.hasPrefix "/home" "/home/tobor/.config/nix/nix.conf";
  second = lib.strings.hasPrefix "/home" "/etc/nix/nix.conf";
}
```

Here is the output:

```bash
❯ nix-instantiate --eval --strict lib-strings-hasprefix.nix
{ first = true; second = false; }
```

As expected, the `lib.strings.hasPrefix`{.nix} function correctly assessed
whether the strings started with the `"/home"`{.nix} prefix or not. Note that
because most useful sub-library attributes are inherited in the main attribute
set, we could've just written `lib.hasPrefix`{.nix} instead.

> Note: Even though this "just works" in most cases, you should still be careful
> about such assumptions. `lib.hasPrefix`{.nix} is a good example because both
> `lib.lists.hasPrefix`{.nix} and `lib.strings.hasPrefix`{.nix} exist (and even
> more). In this case, `lib.hasPrefix`{.nix} is the `strings` version.

Now that we've seen that the library works, we should ask ourselves how. Since
this is a "standard library", we must not forget that it is written in Nix! We
can find the source code of the `hasPrefix` function in the
[lib/strings.nix](https://github.com/NixOS/nixpkgs/blob/fb37e557172307f197b7b3fbc0296a5f3ca5b43e/lib/strings.nix#L748){target="\_blank"}
file in nixpkgs:

```nix
hasPrefix =
  pref:
  str:
  # Before 23.05, paths would be copied to the store before converting them
  # to strings and comparing. This was surprising and confusing.
  warnIf
    (isPath pref)
    ''
      lib.strings.hasPrefix: The first argument (${toString pref}) is a path value, but only strings are supported.
          There is almost certainly a bug in the calling code, since this function always returns `false` in such a case.
          This function also copies the path to the Nix store, which may not be what you want.
          This behavior is deprecated and will throw an error in the future.
          You might want to use `lib.path.hasPrefix` instead, which correctly supports paths.''
    (substring 0 (stringLength pref) str == pref);
```

It contains a few checks and warnings, but we can see that it uses
`builtins`{.nix} and other library functions to get the job done. You might
notice that the builtin functions calls are written without `builtins`{.nix}.
That's because they are inherited from the `builtins`{.nix} attribute set near
the
[top of the file](https://github.com/NixOS/nixpkgs/blob/fb37e557172307f197b7b3fbc0296a5f3ca5b43e/lib/strings.nix#L17){target="\_blank"}:

```nix
inherit (builtins)
  compareVersions
  elem
  elemAt
  filter
  fromJSON
  genList
  head
  isInt
  isList
  isAttrs
  isPath # Here
  isString
  match
  parseDrvName
  readFile
  replaceStrings
  split
  storeDir
  stringLength # Here
  substring # Here
  tail
  toJSON
  typeOf
  unsafeDiscardStringContext
  ;
# Note that `toString` is not here because it can be used without `builtins`,
# just like `import`, `throw` and `map` for example!
```

Going back to the function definition, you might notice that there is a long
comment
[just above it](https://github.com/NixOS/nixpkgs/blob/fb37e557172307f197b7b3fbc0296a5f3ca5b43e/lib/strings.nix#L717){target="\_blank"}:

```nix
/**
  Determine whether a string has given prefix.


  # Inputs

  `pref`
  : Prefix to check for

  `str`
  : Input string

  # Type

  \`\`\`
  hasPrefix :: string -> string -> bool
  \`\`\`

  # Examples
  :::{.example}
  ## `lib.strings.hasPrefix` usage example

  \`\`\`nix
  hasPrefix "foo" "foobar"
  => true
  hasPrefix "foo" "barfoo"
  => false
  \`\`\`

  :::
*/
```

This is a documentation comment. It is used to generate the documentation for
the function, which can be found
[here in the manual](https://nixos.org/manual/nixpkgs/unstable/#function-library-lib.strings.hasPrefix){target="\_blank"}.
The nixpkgs manual is the official place to find
[documentation for library functions](https://nixos.org/manual/nixpkgs/unstable/#sec-functions-library){target="\_blank"}.
Remember that a nice unofficial way to find functions is to use
[noogle.dev](https://noogle.dev){target="\_blank"}.

# Understanding type signatures

You might notice that in the above documentation comment there is a type:

```
hasPrefix :: string -> string -> bool
```

This is the type signature of the function. It describes what arguments should
be passed and what it returns.

The first word is the name of the function. After the `::`, there is the type.
It shows that it takes a string and returns a function which takes a string and
returns a boolean (currying!).

Let's look at a more complicated example, such as the
`lib.attrsets.mapAttrsRecursiveCond`{.nix} function. Understanding what it does
is not necessary for now, as we're just interested in its type:

```
mapAttrsRecursiveCond :: (AttrSet -> Bool) -> ([String] -> a -> b) -> AttrSet -> AttrSet
```

The first argument is a function that takes an attribute set and returns a
boolean. This means we must pass a function to
`lib.attrsets.mapAttrsRecursiveCond`{.nix}. For example:

```nix
# Assume as.enable is a boolean here
partiallyApplied = lib.attrsets.mapAttrsRecursiveCond (as: as.enable)
```

After we do that, we'll have a partially applied function (which, to be clear,
is just a normal function) with the following type:

```
partiallyApplied :: ([String] -> a -> b) -> AttrSet -> AttrSet
```

In other words, `lib.attrsets.mapAttrsRecursiveCond`{.nix} returned a function
that takes as argument another function. The function we must pass as argument
takes a list of strings and returns a function which takes any value and returns
any value. For example:

```nix
partiallyApplied2 = partiallyApplied (list: x: { inherit list x; })
```

Next, we have a partially applied function with the following type signature:

```
partiallyApplied2 :: AttrSet -> AttrSet
```

It looks like we have to pass an attribute set, for example:

```nix
final = partiallyApplied2 { a.enable = true; enable = true; }
```

The only part now left of the original type signature is the following:

```
final :: AttrSet
```

which implies that the type of `final` should be an attribute set.

Our complete function call that complies with the provided type signature is
then:

```nix
lib.attrsets.mapAttrsRecursiveCond (as: as.enable) (list: x: {
  inherit list x;
}) {
  a.enable = true;
  enable = true;
}
```

and the output is an attribute set.

Understanding these type signatures is very useful when dealing with library
functions.

# Summary

- Nixpkgs is a GitHub repository containing a lot of Nix code.
- Nixpkgs has many things, including a standard library for Nix.
- `builtins.fetchTarball`{.nix} can be used to download nixpkgs in Nix.
- The library is an attribute set, which is split in various sub-libraries.
- Most useful attributes defined in the sub-libraries are inherited in the main
  attribute set.
- Functions in the library usually have a documentation comment above their
  definition, which may include their type signature.

That's it for now! In the next chapter we're going to dive deeper into the
nixpkgs library by taking a look at the module system it provides. The module
system is at the very core of how NixOS works: we're getting closer!
