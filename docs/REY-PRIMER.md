# Rey beta primer for Capybara contributors

This is a deliberately small subset of Rey that is known to compile with the
v0.3.0 toolchain. When in doubt, copy the idioms used under
`std/src/` (or `~/.rey/std/src/`).

## Entry point

```rey
import std::process;

func main(): void {
    println("hello");
    process.exit(0);
}
```

## Imports

```rey
// Standard library
import std::fs;
import std::process;
import std::toml;

// Project module (relative)
import "./config.rey" as config;
```

## Functions and types

```rey
func add(a: int, b: int): int {
    return a + b;
}

func greet(name: string): void {
    println("hello " + name);
}
```

## Structs

```rey
struct Package {
    pub name: string,
    pub version: string,
    pub entry: string,
}

func newPackage(name: string): Package {
    return Package {
        name: name,
        version: "0.1.0",
        entry: "src/main.rey",
    };
}
```

## Conditionals and loops

```rey
if condition {
    // ...
} else {
    // ...
}

// while loop
var i = 0;
while i < 10 {
    i = i + 1;
}

// loop with break
loop {
    if done { break; }
}
```

## Calling out to commands

Capybara invokes `rey build`, `clang`, `git`, etc. through the standard process API:

```rey
import std::process;

var res = process::run("rey", ["build", "src/main.rey", "-o", "build/app"]);
if res.code != 0 {
    println("build failed: " + res.stderr);
    process::exit(res.code);
}
```
