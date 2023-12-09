---
title: Connectors, Pools, and HTTPS
layout: guide
---

> **Unstable**: The code discussed in this guide is in `hyper-util`,
> which is not as stable as that which is in `hyper`. It is production
> ready, but changes may come more frequently.

_TODO_

## What is a connector?

_TODO_

## Connection Pools

_TODO_

## HTTPS

hyper allows you to bring your own IO, so it can work on top of any TLS
implementation. (TODO: link to runtime guide)

There are also crates that provide "connectors" which result in
easy-to-use HTTPS for the legacy client in `hyper-util`. Each has their
own reason for existing, and pros and cons, but this list is provided to
help you get started[^tls-list]:

- [hyper-tls](https://crates.io/crates/hyper-tls)
- [hyper-rustls](https://crates.io/crates/hyper-rustls)
- [hyper-openssl](https://crates.io/crates/hyper-openssl)

[^tls-list]: This isn't an endorsement for any of the crates, and they all are maintained separately from hyper.
