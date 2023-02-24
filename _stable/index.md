---
title:  Getting Started
layout: guide
permalink: /guides/1/
---

***Note:** these guides are for the upcoming version `1.0` of hyper,
click [here](/guides/0.14) to see the `0.14` guides.*

hyper is an HTTP library for the Rust language.

You can start using it by first adding it to your `Cargo.toml`:

```toml
[dependencies]
hyper = { version = "1.0.0-rc.3", features = ["full"] }
```

- If building a web server, continue with the [Server guide][].
- If trying to talk to a server, continue with the [Client guide][].

You could also look at the [generated API documentaton][docs].

[docs]: {{ site.docs_url }}
[Server guide]: server/hello-world
[Client guide]: client/basic
