In previous chapters we learned about the Nix language, the nixpkgs library and
the module system it provides. We want to go further by making a mini-NixOS
(almost) implemented from scratch in order to learn how it works, but to do that
we first need to learn about derivations.

# Derivations

Derivations are a feature of the Nix language and package manager. They are kind
of like instructions on how to build what you could call a "package". For
example, you could have the source code of an app, such as one coded in C. A
derivation could contain instructions defining where to find the source code,
what software to use to compile it (as an example,
[gcc](https://gcc.gnu.org/){target="\_blank"}) and where to place the output.

In order to understand how derivations work and how to make one, we must first
quickly introduce the Nix store.

# Nix Store - Quick Introduction

The Nix store is a directory usually located at `/nix/store`. This directory
contains so-called "store objects". An example of a store object could be the
output of a derivation (a built "package"). Store objects are immutable, meaning
they cannot be changed, but rather only added and removed.

In order for the Nix store to keep track of what files and directories it
contains (and specifically their relations), it also has a database, which is
usually found at `/nix/var/nix/db`. We will look into why this is useful later!

# Creating a derivation

To better understand how it all works and what derivations actually are, we'll
start by making one. We will try a simple example and then go back to further
comprehend what actually happened.

The simplest way to create a derivation is to use the
`builtins.derivation`{.nix} function in Nix. It takes many arguments in the form
of an attribute set, but only the following are required:

- `name` (string) - The name of what we want to build. For an app, this might be
  its name. Keep in mind that you are free to choose pretty much any name you
  want: it's not important to the build process.
- `system` (string) - The CPU architecture and operating system the store object
  will be built for. Examples are `x86_64-linux` and `aarch64-linux`.
- `builder` (string or path) - The program to be used in the build process.

One of the optional attributes we will use is `args`, which contains a list of
the arguments to be passed to the builder. Those are what you would write after
a program's name in the command line.

Let's get started and use the `builtins.derivation`{.nix} function (a builtin
that can be used without writing `builtins`{.nix}). For the builder, we will use
[bash](https://www.gnu.org/software/bash/){target="\_blank"}, which allows us to
write a shell script that defines the build process. In order to do that, we'll
leverage the fact that when we call bash with the `-c` argument, we can execute
a script:

```bash
❯ bash -c 'pwd; echo "hey there"'
/home/tobor
hey there
```

We will use `/bin/sh`, which on NixOS contains the bash executable (note: this
is not the recommended way. We will discuss this later).

```nix
derivation {
  # Give a custom name to our built store path
  name = "my-first-derivation";
  # I personally am on `aarch64-linux`, but you are probably on `x86_64-linux`
  system = "aarch64-linux";
  # Use /bin/sh as builder, which is bash
  builder = "/bin/sh";

  # Arguments that will be passed to the builder we specified above
  args = [
    "-c"
    # Our script goes in here, which is what is passed after `-c`
    ''
      echo "Starting the build process!"

      # Write "Nix is great!" to the file $out
      echo "Nix is great!" > $out
    ''
  ];
}
```

You might notice how we used the environment variable `$out` and might be
wondering what it is. It's the path to the build output! We must write our
output there.

Now that we have written the code to specify how our store object should be
created, it's time to actually create it. This is a two step process:
instantiation and realisation.

# Instantiation

Derivations are also store objects, specifically files ending in `.drv`. The
process of creating a `.drv` store object is called instantiation. Yes! That's
exactly where the name of the `nix-instantiate`{.bash} command we've been
running this whole time comes from. By default, this command returns the store
path of the instantiated derivation contained in the evaluated output of the
file. The evaluated output of the file is simply the value
`builtins.derivation`{.nix} returns, at which we will take a look later. We were
previously running `nix-instantiate`{.bash} with the `--eval` option, which
specifies that the evaluated value of the file should not be considered as a
derivation, but rather only printed.

We can now simply run `nix-instantiate`{.bash} with our file as the only
argument (without `--eval`):

```bash
❯ nix-instantiate my-first-derivation.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
```

We can safely ignore the warning for now, it is not relevant. What we should
focus on is the path we received. It is the path to the derivation file: a store
object. Its name follows the following format: `/nix/store/<hash>-<name>.drv`.
We can ignore the `<hash>` part for now.

Let's look at the contents of our derivation file:

```bash
❯ cat /nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
Derive([("out","/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation","","")],[],[],"aarch64-linux","/bin/sh",["-c","echo \"Starting the build process!\"\n\n# Write \"Nix is great!\" to the file $out\necho \"Nix is great!\" > $out\n"],[("builder","/bin/sh"),("name","my-first-derivation"),("out","/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation"),("system","aarch64-linux")])
```

Wow! Not the easiest format to read. We can use the
`nix --extra-experimental-features "nix-command" derivation show`{.bash} command
to view it in JSON (note: the `nix-command` experimental feature is part of the
content of a future chapter, so it won't be explained at the moment):

```json
❯ nix --extra-experimental-features "nix-command" derivation show /nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
{
  "/nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv": {
    "args": [
      "-c",
      "echo \"Starting the build process!\"\n\n# Write \"Nix is great!\" to the file $out\necho \"Nix is great!\" > $out\n"
    ],
    "builder": "/bin/sh",
    "env": {
      "builder": "/bin/sh",
      "name": "my-first-derivation",
      "out": "/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation",
      "system": "aarch64-linux"
    },
    "inputDrvs": {},
    "inputSrcs": [],
    "name": "my-first-derivation",
    "outputs": {
      "out": {
        "path": "/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation"
      }
    },
    "system": "aarch64-linux"
  }
}
```

We can see the arguments we passed to `builtins.derivation`{.nix} represented in
the JSON output: `args`, `builder`, `name` and `system` are left unchanged. We
can also find some new information:

- `env` - These are the environment variables that will be set when running the
  builder. Note how all of our string arguments are also present here! We could
  have set `ABC = "test";` in the argument of `builtins.derivation`{.nix} and
  `ABC` would have appeared in `env`. We can also find `$out` here.
- `outputs` - This contains the various outputs. By default there is only one
  output, which is `out`.
- `inputDrvs` and `inputSrcs` - We won't focus on those yet, we'll discuss them
  later.

Let's focus quickly on the output path `out`. It follows this format:
`/nix/store/<hash>-<name>[-<output>]`, where `-<output>` would be `out` and is
only present if it's different from `out`, meaning that in this case it is not
present and the store path is just `/nix/store/<hash>-<name>`.

The `<hash>` here is a
[hash](https://en.wikipedia.org/wiki/Hash_function){target="\_blank"} of the
derivation inputs, such as `builder`, `name`, `args`, .... This means that
derivations with the same inputs will have the same output path! If we try to
change even just the name in the arguments we pass to `derivation`{.nix}, we'll
see that the output path will change.

# Realisation

Building a derivation is part of its realisation process. We'll talk about the
rest of the realisation process later, but for now let's focus on building the
derivation.

We can do so by running the following command:

```bash
❯ nix-store --realise /nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
this derivation will be built:
  /nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
building '/nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv'...
Starting the build process!
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation
```

As you can see, it ran our script: it printed our
`"Starting the build process!"`{.bash} message and produced an output. Let's
check out the contents of the output:

```bash
❯ cat /nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation
Nix is great!
```

It indeed worked! Let's try to run the same command again:

```bash
❯ nix-store --realise /nix/store/sd5jzqvqxr8kvsl4bi9q6pfihpclwjlr-my-first-derivation.drv
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/70ab2bm4yv2pwi1grmkb9qjdfvbi0d7l-my-first-derivation
```

Interesting: it seems not to have printed our `"Starting the build process"` log
message. That's because it did not build at all! Nix saw that the output path
was already present in the Nix store and therefore did not bother building it
again. Nix assumes a derivation will produce the same outputs if ran with the
same inputs. During the build process, it takes great care to make sure it can
make such assumption:

- Network access is disabled during the build process
- The build process is done in a `/build` directory and other paths aside from
  the nix store cannot be accessed (apart from paths like `/bin/sh`, which are
  exceptions)
- The timestamps of the output are set to `1` (00:00:01 1/1/1970 UTC)
- The `PATH` environment variable is set to `/path-not-set`
- Many other things

All these precautions are to make builds **reproducible**, which means that they
will produce the same output when ran twice. Only if builds are reproducible can
Nix make the assumption it just made about not having to build the derivation
again.

> Note: This is the problem with using `/bin/sh`: It's not reproducible. If we
> change its value, then running the same derivation again may produce a
> different output. So, you might ask, what would the correct way be? It would
> be to use a derivation to build `bash`, which would create an immutable store
> object. The store path to this immutable store object could then be used
> instead of `/bin/sh`, ensuring that always the same version of `bash` is used.
> We won't be building `bash` using `builtins.derivation`{.nix} in this chapter,
> as that would be too complicated, so we'll just continue using `/bin/sh`.

Now that we've successfully built a derivation, let's quickly go back to the
arguments that `builtins.derivation`{.nix} takes. There is an important optional
one we didn't mention, which is `outputs`. By default, its value is
`[ "out" ]`{.nix}, but we can choose to have more outputs. If we for example set
it to `[ "out" "doc" ]`{.nix}, we can have a single derivation that produces two
store objects when built:

- `/nix/store/<hash>-<name>-doc`
- `/nix/store/<hash>-<name>`

In the build environment, we will have both `$out` and `$doc` available. Let's
try it out! We can write two different outputs, one in `$out` and one in `$doc`:

```nix
derivation {
  name = "two-outputs";
  system = "aarch64-linux";
  builder = "/bin/sh";
  # Add the `doc` output
  outputs = [
    "out"
    "doc"
  ];
  args = [
    "-c"
    ''
      echo "Hello output!" > $out
      echo "Hello documentation!" > $doc
    ''
  ];
}
```

Let's take a look at the derivation it instantiates:

```json
❯ nix-instantiate two-outputs.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv
❯ nix --extra-experimental-features "nix-command" derivation show /nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv
{
  "/nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv": {
    "args": [
      "-c",
      "echo \"Hello output!\" > $out\necho \"Hello documentation!\" > $doc\n"
    ],
    "builder": "/bin/sh",
    "env": {
      "builder": "/bin/sh",
      "doc": "/nix/store/s8vd44gi0vi31njk31hp1xc896hx0l7v-two-outputs-doc",
      "name": "two-outputs",
      "out": "/nix/store/zvhc82r9cmkjdsr6zvn47bwkmn2rapxb-two-outputs",
      "outputs": "out doc",
      "system": "aarch64-linux"
    },
    "inputDrvs": {},
    "inputSrcs": [],
    "name": "two-outputs",
    "outputs": {
      "doc": {
        "path": "/nix/store/s8vd44gi0vi31njk31hp1xc896hx0l7v-two-outputs-doc"
      },
      "out": {
        "path": "/nix/store/zvhc82r9cmkjdsr6zvn47bwkmn2rapxb-two-outputs"
      }
    },
    "system": "aarch64-linux"
  }
}
```

Notice how now we have both outputs in `outputs` with their correct path. Let's
now try realising the derivation:

```bash
❯ nix-store --realise /nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv
this derivation will be built:
  /nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv
building '/nix/store/0z2kyrrpb27pdlih54y7gwc0a4k18kwz-two-outputs.drv'...
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/s8vd44gi0vi31njk31hp1xc896hx0l7v-two-outputs-doc
/nix/store/zvhc82r9cmkjdsr6zvn47bwkmn2rapxb-two-outputs

❯ cat /nix/store/s8vd44gi0vi31njk31hp1xc896hx0l7v-two-outputs-doc
Hello documentation!

❯ cat /nix/store/zvhc82r9cmkjdsr6zvn47bwkmn2rapxb-two-outputs
Hello output!
```

It works! If you are interested in learning about other less used arguments you
can pass to `builtins.derivation`{.nix}, you can check out the
[official documentation](https://nix.dev/manual/nix/2.25/language/advanced-attributes){target="\_blank"}.

Before we move on to learning about references, we should probably take a look
at an aspect we've ignored until now: what's the output of the
`builtins.derivation`{.nix} function?

# Output of `builtins.derivation`{.nix}

In previous chapters we've read about the various types in Nix. We also learned
that a Nix file always evaluates to a single value. Naturally, that leaves the
question: What's the type that `builtins.derivation`{.nix} returns? Is it some
type we haven't mentioned and ignored until now?

No actually! The output of `builtins.derivation`{.nix} is a simple attribute
set. Nothing particularly special about it. The important thing that makes Nix
acknowledge it as a derivation is that it must have the attribute named `type`
set to `"derivation"`{.nix}. Let's evaluate the following `derivation`{.nix}
call:

```nix
derivation {
  name = "simple";
  system = "aarch64-linux";
  builder = "/bin/sh";
  args = [
    "-c"
    ''
      echo hey > $out
    ''
  ];
}
```

When running `nix-instantiate --eval --strict simple.nix`{.bash}, it comes out
to this (the output was modified to be formatted nicely):

```nix
{
  all = [ «repeated» ];
  args = [
    "-c"
    "echo hey > $out\n"
  ];
  builder = "/bin/sh";
  drvAttrs = {
    args = «repeated»;
    builder = "/bin/sh";
    name = "simple";
    system = "aarch64-linux";
  };
  drvPath = "/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv";
  name = "simple";
  out = «repeated»;
  outPath = "/nix/store/8dnv8qmv2myar174fjh8v2g6r8s6jxah-simple";
  outputName = "out";
  system = "aarch64-linux";
  type = "derivation";
}
```

Looking at this output, we notice how `builder`, `system`, `args` and `name`,
which are the attributes we passed as argument, have all been inherited in the
output. We also notice the `type` attribute we mentioned earlier. There are some
other attributes at play here:

- `drvPath` - The path to the derivation file.
- `outPath` - The path to the built output (which of course does not exist yet).
  In this case it is the one of the `out` output, which is the default output.
- `outputName` - The name of the output of `outPath`, in this case it is the
  default `"out"`{.nix}.
- Other attributes we won't currently focus on.

The question you might have now is: "Do we actually even need
`builtins.derivation`{.nix}? Can't we just write this manually?". Yes and no.
Let's try to instantiate the following Nix file, which evaluates to the value
presented above:

```nix
# We use a let binding to create the «repeated» values
let
  output = {
    all = [ output ];
    args = [
      "-c"
      "echo hey > $out\n"
    ];
    builder = "/bin/sh";
    drvAttrs = {
      args = output;
      builder = "/bin/sh";
      name = "simple";
      system = "aarch64-linux";
    };
    drvPath = "/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv";
    name = "simple";
    out = output;
    outPath = "/nix/store/8dnv8qmv2myar174fjh8v2g6r8s6jxah-simple";
    outputName = "out";
    system = "aarch64-linux";
    type = "derivation";
  };
in
output
```

Here's the output:

```bash
❯ nix-instantiate output.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv
```

We can compare it to the output of instantiating the `builtins.derivation`{.nix}
call:

```bash
❯ nix-instantiate simple.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv
```

They are the same! So it does work, we can create a derivation value without
using `builtins.derivation`{.nix}, but this does not mean that
`builtins.derivation`{.nix} doesn't do anything special.

It does indeed do something special, can you see it?

This whole process only worked because we already knew the path to the
derivation store object, meaning we could write it in the `drvPath` attribute.
If we remove `drvPath` from our `output.nix` file and instantiate it again, we
get the following error:

```bash
❯ nix-instantiate output.nix
error: derivation does not contain a 'drvPath' attribute
```

Let's try to set it to something random and run the command again:

```bash
❯ nix-instantiate output.nix
error:
       … while evaluating the 'drvPath' attribute of a derivation
         at /home/tobor/output.nix:16:5:
           15|     };
           16|     drvPath = "/nix/store/this-is-very-interesting";
             |     ^
           17|     name = "simple";

       error: path '/nix/store/this-is-very-interesting' is not in the Nix store
```

This gives us very useful insight about what is actually happening. It's not
`nix-instantiate`{.bash} that is creating the `.drv` file, but rather the call
to `builtins.derivation`{.nix}! The `nix-instantiate`{.bash} command just shows
the `drvPath` attribute (if valid) of an attribute set with `type` set to
`"derivation"`{.nix} where `outputName` and `name` are also set:

```nix
{
  name = "This can actually be a random string, but it must be present.";
  outputName = "out";
  type = "derivation";
  drvPath = "/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv";
}
```

This is what happens if we try to run `nix-instantiate`{.bash} with the above
code:

```bash
❯ nix-instantiate testing-our-theory.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/bpr4x7y8sr6vhp8zn9nrdshnvqdb8rc8-simple.drv
```

It displays our `drvPath` attribute! So no, the `builtins.derivation`{.nix}
doesn't just modify our argument attribute set slightly, but instead also
creates the derivation store object at evaluation time!

# References

In the real world, programs often don't just run by themselves. They sometimes
need dependencies and they need to know where to find these dependencies at
build time and at runtime. In Nix, all programs are in the Nix store. In NixOS,
many configuration files are also simply store objects in the Nix store. In
other words, when you use Nix, most of your stuff is in the Nix store. While it
may seem to be in other places, the files in the other places are simply
symlinks to the Nix store. You can think of a symlink like a file that links
whoever tries to read it to a different path, in this case a path in the Nix
store.

This implies that store objects in the Nix store must be able to reference each
other: as already mentioned, for example, a program must be able to contain the
path of its dependency (which may also be needed at build time). Since both the
program and its dependency are built derivations, Nix must ensure the dependency
is built before the program. Thankfully, this is all possible!

Let's look at a real example with derivations written in the Nix language:

```nix
let
  dependencyDerivation = derivation {
    name = "nice-dependency";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo "Will this work?" > $out
      ''
    ];
  };

  finalDerivation = derivation {
    name = "great-program";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo "Here is the path of my dependency ${dependencyDerivation.outPath}" > $out
      ''
    ];
  };
in
finalDerivation
```

We interpolate the output path of `dependencyDerivation` in the build script of
`finalDerivation`. Let's see what happens:

```bash
❯ nix-instantiate references.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv

❯ nix-store --realise /nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv
these 2 derivations will be built:
  /nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv
  /nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv
building '/nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv'...
building '/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv'...
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program

❯ cat /nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
Here is the path of my dependency /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency

❯ cat /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
Will this work?
```

Magic! Nix knew to build `nice-dependency` before `great-program`, but how? If
you think about it, we only interpolated its output path in a string and
building doesn't happen during evaluation. The `builtins.derivation`{.nix} call
of `finalDerivation` received as input a simple string, but it was able to
understand that it should output a derivation which contains information
specifying that another derivation must be built first.

The answer lies in a feature of the Nix language we haven't yet discussed:
String context.

# String context

The String type in Nix doesn't just contain a string of text, but can also
contain "metadata" about it. This "metadata" is called string context. This
string context contains additional information about the string, such as whether
the output of another derivation was interpolated to make the string.

We can use the `builtins.getContext`{.nix} function to get access to the string
context of a string:

```nix
let
  drv = derivation {
    name = "simple";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo simple > $out
      ''
    ];
  };
in
builtins.getContext drv.outPath
```

Here is the output:

```bash
❯ nix-instantiate --eval context.nix
{ "/nix/store/2r1bdcv7dxyf7r51hz2rnfxkj80g5gf8-simple.drv" = { outputs = [ "out" ]; }; }
```

Let's compare it to the string context of a "normal" string. We can use the `-E`
flag (`--expr`) to specify an expression to evaluate directly in the command:

```bash
❯ nix-instantiate --eval -E 'builtins.getContext "Hello, World!"'
{ }
```

Looks like a "normal" newly created string has no context, while the `outPath`
of a derivation has some context which identifies its origin as a derivation!
Let's try to interpolate `outPath` in another string:

```nix
let
  drv = derivation {
    name = "simple";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo simple > $out
      ''
    ];
  };
in
builtins.getContext "Here is my path '${drv.outPath}'. Yep!"
```

Here is the output:

```bash
❯ nix-instantiate --eval context.nix
{ "/nix/store/2r1bdcv7dxyf7r51hz2rnfxkj80g5gf8-simple.drv" = { outputs = [ "out" ]; }; }
```

It still contains the string context! Specifically, this context specifies that
the string contains the `out` output path of the derivation with path
`"/nix/store/2r1bdcv7dxyf7r51hz2rnfxkj80g5gf8-simple.drv"`{.nix}.

Let's try to evaluate the string context of the `outPath` of our previously
defined `finalDerivation`:

```nix
let
  dependencyDerivation = derivation {
    name = "nice-dependency";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo "Will this work?" > $out
      ''
    ];
  };

  finalDerivation = derivation {
    name = "great-program";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        echo "Here is the path of my dependency ${dependencyDerivation.outPath}" > $out
      ''
    ];
  };
in
# Here we get the string context of `outPath`!
builtins.getContext finalDerivation.outPath
```

Here is what comes out:

```bash
❯ nix-instantiate --eval references.nix
{ "/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv" = { outputs = [ "out" ]; }; }
```

It lets us know that the string contains the path to the `out` output of the
derivation with path
`"/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv"`{.nix}, but
where is the information about our `dependencyDerivation` derivation? That
information is now in the `.drv` store object of `great-program`! Let's check it
out:

```json
❯ nix --extra-experimental-features "nix-command" derivation show /nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv
{
  "/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv": {
    "args": [
      "-c",
      "echo \"Here is the path of my dependency /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency\" > $out\n"
    ],
    "builder": "/bin/sh",
    "env": {
      "builder": "/bin/sh",
      "name": "great-program",
      "out": "/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program",
      "system": "aarch64-linux"
    },
    "inputDrvs": {
      "/nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv": {
        "dynamicOutputs": {},
        "outputs": [
          "out"
        ]
      }
    },
    "inputSrcs": [],
    "name": "great-program",
    "outputs": {
      "out": {
        "path": "/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program"
      }
    },
    "system": "aarch64-linux"
  }
}
```

The attribute `inputDrvs`, which was empty in our previous examples, now
contains some information! Specifically, it contains information about
`dependencyDerivation`, which it got from the string context of the string we
passed in the `args` list.

When Nix sees that a derivation has a dependency derivation in `inputDrvs`, it
builds it (and any dependencies that derivation has) before building the main
derivation. This is also the main difference between **realisation** and
**building** in Nix. Building a derivation means building its output. Realising
a derivation means realising all of its dependencies and then usually building
the derivation itself (if it isn't already in the Nix store, as previously
discussed when we talked about reproducibility). Nix defines realisation as
being the process of ensuring a store path is valid.

# Closures

By now we've built a decent understanding of what the store objects in the Nix
store are and how they are made. At the start of the chapter, we also mentioned
that the Nix store had a database, which is located at `/nix/var/nix/db` by
default. You might be wondering where the database finds its place in this whole
system. The database is used to store references.

Earlier, we made a derivation which depended on another derivation. When their
store objects as built, we can say that the main object has a **reference** to
the dependency's store object. A store object having a reference means that the
path of another store object is mentioned in its content.

The Nix database stores information about these references. It can therefore let
you know which store objects must be in the Nix store for a store object to be
valid. The full list of the required store objects for a store object is its
**closure**.

We can view the closure of our previously built `great-program` using the
`nix-store --query --requisites`{.bash} command:

```bash
❯ nix-store --query --requisites /nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
```

As can be seen, the path
`/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency`, which is
contained in the contents of `great-program`, is part of `great-program`'s
closure.

The Nix database makes this retrieval possible. It's useful for various
commands. For example, you can delete a store object by using the
`nix-store --delete`{.bash} command. Let's try to delete `nice-dependency`'s
store object:

```bash
❯ nix-store --delete /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
finding garbage collector roots...
0 store paths deleted, 0.00 MiB freed
error: Cannot delete path '/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency' since it is still alive. To find out why, use: nix-store --query --roots and nix-store --query --referrers
```

It fails! This is because it knows that deleting this store object would
invalidate the existing `great-program` store object. We can verify this by
running the two commands it gave us in the error:

```bash
❯ nix-store --query --roots /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency

❯ nix-store --query --referrers /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
```

It seems to have no roots, which is a topic we will discuss further on. What is
important though, is that it has a referrer, which is `great-program`. This can
be known because of the Nix database and saves the Nix store from corruption by
accidental deletion of store objects that are needed by other store objects.

If we want to delete `nice-dependency`, we must first delete `great-program`:

```bash
❯ nix-store --delete /nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
finding garbage collector roots...
deleting '/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program'
deleting unused links...
note: currently hard linking saves 4080.51 MiB
1 store paths deleted, 0.00 MiB freed
```

Now we can successfully delete `nice-dependency` because it's not referenced
anymore:

```bash
❯ nix-store --delete /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
finding garbage collector roots...
deleting '/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency'
deleting unused links...
note: currently hard linking saves 4080.51 MiB
1 store paths deleted, 0.00 MiB freed
```

# Garbage Collector Roots

It's now time to understand what the `roots` we previously encountered means.
Over the course of this chapter we've built up quite a few store objects in the
Nix store. If we keep experimenting at this pace, eventually we'll end up with
many unnecessary store objects. We don't want to delete each manually, as that
would take ages. What we're looking for is a tool that can automatically delete
store objects. At the same time, we don't want all store objects to be deleted:
some store objects are programs we're actually using and have installed through
the Nix package manager (more on this in future chapters about NixOS,
home-manager, ...)!

The tool we're looking for is the Nix garbage collector. It will delete all
"unused" store objects. Garbage Collector roots (GC roots) are what determine
whether a store object is used. For now, let's forget about GC roots and focus
on the garbage collector. If we build `great-program` again, we can try removing
it from the nix store by using the garbage collector.

To ensure we don't make any accidental mistakes, we can use the following
command to check what store objects will be deleted:

```bash
❯ nix-store --gc --print-dead
finding garbage collector roots...
determining live/dead paths...
/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv
/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program
/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency
/nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv
```

All of these store objects are currently not being used, so they will be deleted
when we run `nix-store --gc`:

```bash
❯ nix-store --gc
finding garbage collector roots...
deleting garbage...
deleting '/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program'
deleting '/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency'
deleting '/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv'
deleting '/nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv'
deleting unused links...
note: currently hard linking saves 2868.49 MiB
4 store paths deleted, 0.00 MiB freed
```

After building `great-program` yet again, let's say we wanted to prevent
`nice-dependency` from being deleted. We can add a GC root. GC roots is a
directory that can be found at `/nix/var/nix/gcroots` by default. This folder
will contain symlinks to store paths. Store paths that are pointed to by
symlinks here won't be garbage collected. Adding a GC root simply means adding a
symlink in this directory.

> Warning: **You should NOT manually add GC roots** unless you know what you are
> doing. Please just read the following part instead of actually trying the
> commands out. Using the commands described below may add useless permanent
> state to your computer and cause other issues.

Let's add the GC root for `nice-dependency` by using the `ln -s`{.bash} command
to create a symbolic link (symlink):

```bash
sudo ln -s /nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency /nix/var/nix/gcroots/nice-dependency
```

And now let's run the garbage collector again:

```bash
❯ nix-store --gc
finding garbage collector roots...
deleting garbage...
deleting '/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program'
deleting '/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv'
deleting unused links...
note: currently hard linking saves 2868.49 MiB
2 store paths deleted, 0.00 MiB freed
```

Only `great-program` was deleted, but not `nice-dependency` because it has a GC
root. Let's now delete the GC root of `nice-dependency` and create one for
`great-program` (after building `great-program` again):

```bash
❯ sudo rm /nix/var/nix/gcroots/nice-dependency

❯ sudo ln -s /nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program /nix/var/nix/gcroots/great-program
```

Now, let's try collecting the garbage:

```bash
❯ nix-store --gc
finding garbage collector roots...
deleting garbage...
deleting unused links...
note: currently hard linking saves 2868.49 MiB
0 store paths deleted, 0.00 MiB freed
```

Nothing was deleted! This is because `nice-dependency`, which is not protected
by a GC root, is part of the closure of `great-program`. In order for
`great-program` to remain in the Nix store and stay valid, `nice-dependency`
must also be kept.

We can now remove the GC root and run the garbage collector again:

```bash
❯ sudo rm /nix/var/nix/gcroots/great-program

❯ nix-store --gc
finding garbage collector roots...
deleting garbage...
deleting '/nix/store/bxh74lngpjnrgjdd7pllhz7ni8ngnphw-great-program'
deleting '/nix/store/c0izjdgymxgsg6g8ssrz0pf4lzyr00c4-nice-dependency'
deleting '/nix/store/104chs4lskzpd2pvfn0ppx9nnkg0zj2f-great-program.drv'
deleting '/nix/store/mhcswq431icq8p8hb2sbb899095v2rms-nice-dependency.drv'
deleting unused links...
note: currently hard linking saves 2868.49 MiB
4 store paths deleted, 0.00 MiB freed
```

> Note: The `.drv` files were not deleted when `great-program` was in the GC
> roots. The `.drv` files are not actually needed once the derivation is built,
> but they are kept (when their output is in the GC roots) if the configuration
> option `keep-derivations` (`true`{.nix} by default) is enabled. We'll look at
> Nix configuration file (`nix.conf`) in future chapters, but if you wish to
> temporarily disable this option, you can add `--option keep-derivations false`
> to the command.

# Shortcuts

Now that we've learned what derivations are, what the Nix store & database are
and how to use them, we can look into some shortcuts to do this more easily.

## `nix-build`{.bash}

The `nix-build`{.bash} command can be used to run both `nix-instantiate`{.bash}
and `nix-store --realise`{.bash} in only one command.

```nix
derivation {
  name = "example";
  system = "aarch64-linux";
  builder = "/bin/sh";
  args = [
    "-c"
    ''
      echo "Hello example!" > $out
    ''
  ];
}
```

Running `nix-build`{.bash}:

```bash
❯ nix-build example-derivation.nix
this derivation will be built:
  /nix/store/5yricvihv1ddl1kvij82s2kn55g187rg-example.drv
building '/nix/store/5yricvihv1ddl1kvij82s2kn55g187rg-example.drv'...
/nix/store/2qvbyf6grlsj47mhl66sv5w4545hk0x6-example

❯ cat /nix/store/2qvbyf6grlsj47mhl66sv5w4545hk0x6-example
Hello example!
```

Note that `nix-build`{.bash} can also be called with a `.drv` store object. In
this case, it's pretty much equivalent to `nix-store --realise`{.bash}:

```bash
❯ nix-instantiate example-derivation.nix
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
/nix/store/5yricvihv1ddl1kvij82s2kn55g187rg-example.drv

❯ nix-build /nix/store/5yricvihv1ddl1kvij82s2kn55g187rg-example.drv
/nix/store/2qvbyf6grlsj47mhl66sv5w4545hk0x6-example
```

There is a very important difference whenever `nix-build`{.bash} is used instead
of the two commands we were previously using though: `nix-build`{.bash} adds a
GC root. In the current directory, a symlink called `result` is created to the
store path:

```bash
❯ ls
example-derivation.nix  result

❯ readlink result
/nix/store/2qvbyf6grlsj47mhl66sv5w4545hk0x6-example
```

This is not in the GC roots, so it's not a root yet, but `nix-build`{.bash} also
creates a symlink to the `result` file in the `/nix/var/nix/gcroots/auto`
folder. When GC roots are checked, the link is followed and if `result` exists,
then the path it points to is considered to be a GC root.

If `result` doesn't exist anymore, then when checking GC roots, the symlink to
`result` is automatically deleted:

```bash
❯ ls
example-derivation.nix  result

❯ rm result

❯ nix-store --gc
finding garbage collector roots...
removing stale link from '/nix/var/nix/gcroots/auto/mv9ldljqgqv997njyq4kq7dc6bpyf3dw' to '/home/tobor/example/result'
deleting garbage...
deleting '/nix/store/5yricvihv1ddl1kvij82s2kn55g187rg-example.drv'
deleting '/nix/store/2qvbyf6grlsj47mhl66sv5w4545hk0x6-example'
deleting unused links...
note: currently hard linking saves 3190.43 MiB
2 store paths deleted, 0.00 MiB freed
```

## Attribute set to String coercion

Attribute sets can be coerced to strings if they have a `__toString` attribute
or an `outPath` attribute. For example, we can do the following:

```nix
let
  myAttrs = {
    outPath = "World"
  };
in "Hello ${myAttrs}!" # Evaluates to "Hello World!"
```

Since attribute sets returned by the `derivation`{.nix} function have `outPath`,
we can simply interpolate a derivation without having to manually get `outPath`:

```nix
let
  myDrv = derivation {
    name = "interpolation";
    system = "aarch64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      "echo interpolated > $out"
    ];
  };
in
"Path to derivation output: ${myDrv}"
```

Here's the evaluation output:

```bash
❯ nix-instantiate --eval interpolation.nix
"Path to derivation output: /nix/store/xggagiaggpzlfd6s10qqa1mgz1q1alb1-interpolation"
```

Of course, this path doesn't exist because the derivation hasn't been built yet,
but the derivation is in the string context of the string, so it would be added
as a dependency if the string was needed for another derivation.

> Note: The `__toString` attribute works differently than `outPath`. It should
> be a function which gets passed the attribute set as argument and should
> return the string.

# Summary

- There's a Nix store and a Nix database, which keeps track of the relations
  between the items in the store.
- Store objects in the Nix store are immutable.
- Derivations are instructions on how to build a store object.
- Derivations are stored as store objects ending in `.drv`.
- Instantiation is the process of creating the `.drv` store objects.
- Outputs of derivations can have references to outputs of other derivations, in
  which case the other derivations must be built first.
- The closure of a store object is made up of all the closures of the store
  objects it references and the store object itself.
- Realisation is usually the process of building a derivation's closure and the
  closures of its outputs. Nix defines realisation as being the process of
  ensuring a store path is valid.
- Store paths for built derivations are in the form
  `/nix/store/<hash>-<name>[-<output>]` by default, where `-<output>` is only
  present if `<output>` is different than `out`.
- The hash in the path of a store object built from a derivation is by default
  made from the inputs of the derivation.
- A single derivation can have multiple outputs, but by default it has one
  output: `out`.
- The `builtins.derivation`{.nix} function is used to create the `.drv` store
  objects (instantiation).
- The Nix garbage collector can be used to delete unused store objects.
- A GC root can be created to show that a store object's closure is being used
  and prevent them it being deleted by the garbage collector.
- Strings in Nix are associated with a string context, which can contain
  additional information, such as the derivations from which the output paths it
  contains come from.
- Attribute sets can be coerced to strings if they have an `outPath` or a
  `__toString` attribute.

There is still a lot more to learn about derivations, but for now we've learned
enough about them. We're finally ready to start making our mini-NixOS (almost)
from scratch, which we will do in the next chapter!
