---
title:  Upgrade from 0.14 to 1
layout: guide
permalink: /guides/1/upgrading/
---

This guide is meant to help you upgrade from v0.14 of hyper to v1.

## Backports and Deprecations

Before upgrading, you can start preparing your 0.14 code base by enabling the
`backports` and `deprecated` features of hyper in your `Cargo.toml`. Like
this:

```toml
[dependencies]
hyper = { version = "0.14", features = ["etc", "backports", "deprecated"] }
```

The `backports` feature brings several of the new types from 1.0 to 0.14. If
you enable `deprecated` feature as well, it will add deprecation warnings to
any of hyper's types that have direct backports available.

**NOTE**: This won't give you warnings about changes where backports were not
able to be provided.

## Changelog

As a general rule, we tried hard to mark every possible breaking change in the
[changelog][]. Read through the "breaking changes" section of the 1.0 releases
(including the RC 1-4), which will provide suggestions on how to overcome each
one.

## `hyper::Body`

The `Body` type has changed to be a trait (what used to be `HttpBody`).

The 0.14 `Body` could be multiple variants, and in v1 they have been split into
[distinct types][http-body-util]. You'll benefit from analzying each place you
use `hyper::Body` to decide which solution to switch to.

- In general, if you don't need a specific variant, consider making your usage
  generic, accepting an `impl Body` (or `where B: Body`).
- If you want a type that can be any variant, you could use `BoxBody`.
- Otherwise, the [more specific variants][http-body-util] allow for a more
  explicit API in your code.

## `hyper::Client`

The higher-level pooling `Client` was removed from hyper 1.0. A similar type
was added to [`hyper-util`][], called [`client::legacy::Client`][legacy]. It's
mostly a drop-in replacement.

## `hyper::Server`

The v0.14 `hyper::Server` does not have a drop-in replacement, since it had
problems.

For a server type that can handle both HTTP/1 and HTTP/2 at the same time,
use the [`server::conn::auto::Builder`][auto] from [`hyper-util`][].

The listening server acceptor can be replaced with a simple loop.


[changelog]: https://github.com/hyperium/hyper/blob/master/CHANGELOG.md#v100-2023-11-15
[`hyper-util`]: https://crates.io/crates/hyper-util
[legacy]: https://docs.rs/hyper-util/latest/hyper_util/client/legacy/struct.Client.html
[auto]: https://docs.rs/hyper-util/latest/hyper_util/server/conn/auto/struct.Builder.html
