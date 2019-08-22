---
title: hyper.rs
layout: home
---

```rust
extern crate hyper;
# mod no_run {

use hyper::{Body, Response, Server};
use hyper::rt::Future;
use hyper::service::service_fn_ok;

fn main() {
    let addr = ([127, 0, 0, 1], 3000).into();

    let new_svc = || {
        service_fn_ok(|_req|{
            Response::new(Body::from("Hello, World!"))
        })
    };

    let server = Server::bind(&addr)
        .serve(new_svc)
        .map_err(|e| eprintln!("server error: {}", e));

    hyper::rt::run(server);
}
# }
```
