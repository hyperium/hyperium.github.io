---
title: Client Configuration
---

## Using TLS

By default, a [`Client`][] can only speak to HTTP addresses. This is because hyper doesn't
ship with a TLS implementation. You may have noticed that `Client::new()` returns a 
`Client<HttpConnector>`. We can plug in a different connector using the client config.

Since connecting to HTTPS addresses is so common, hyper provides a separate [hyper-tls][]
crate with a pluggable `HttpsConnector`. Here's how you'd use it.

```rust
extern crate hyper;
extern crate hyper_tls;
extern crate tokio_core;

use hyper::Client;
use hyper_tls::HttpsConnector;
use tokio_core::reactor::Core;

# fn run() -> Result<(), Box<::std::error::Error>> {
let mut core = Core::new()?;
let handle = core.handle();
let client = Client::configure()
    .connector(HttpsConnector::new(4, &handle)?)
    .build(&handle);

let req = client.get("https://hyper.rs".parse()?);
let res = core.run(req)?;
assert!(res.status().is_success());
# Ok(())
# }
# fn main() {}
```

## Connect

As mentioned in the section about TLS, [`Client`][] is generic over any type that
implements `Connect`. where `Connect` is a trait alias for a
`Service<Request=Uri, Response=T>` where `T` is  an IO stream.

You can plug in any kind of connector you need. This means that you could pick a
different TLS implementation than the one chosen by `hyper-tls`, such as `rustls`.
You could also have a completely different way of creating IO objects. Here's some
ideas of things that could be connectors:

- Unix sockets
- Proxies
- In-memory streams (such as for testing)

[`Client`]: {{ site.docs_url }}/hyper/struct.Client.html
[hyper-tls]: {{ site.hyper_tls_url }}
