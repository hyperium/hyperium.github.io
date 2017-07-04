
---
title: Parsing a JSON response body
---

This example shows how to use [serde JSON][serde_json] to parse the body of a response. The body provided by the hyper Client is a [`Stream`][Stream] of chunks of data. A `Stream` will yield its items as they become available. In order to use the serde JSON crate, we need the entire response body. There is a [concat2][Concat2] combinator that will allow us to concatenate the chunks of data into a single chunk in a non-blocking manner. Referencing the client implementation in the basic [example][client/basic], we can replace the `for_each` with `concat2`.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# extern crate serde_json;
# use std::io::{self, Write};
# use futures::{Future, Stream};
# use hyper::{Chunk, Client};
# use tokio_core::reactor::Core;
# use serde_json::Value;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
# let work = client.get(uri);
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
# let work = client.get(uri).and_then(|res| {
res.body().concat2().and_then(move |body: Chunk| {
    let v: Value = serde_json::from_slice(&body).unwrap();
    Ok(())
})
# });
# core.run(work)?;
# Ok(())
# }
# fn main() {}
```

The `response.body()` method returns a value of type `hyper::Body`. A `hyper::Body` is a [`Stream`][Stream] of [`Chunk`][Chunk] values. We need a non-blocking way to get all the chunks so we can deserialize the response. The `concat2()` function takes the separate body chunks and makes one `hyper::Chunk` value with the contents of the entire body. Once we have a chunk that contains the entire body contents, we can leverage the fact `Chunk` types can be converted, via `AsRef`, into a slice of bytes (`[u8]`). We can then use the `serde_json::from_slice()` function to deserialize the bytes into a `serde_json::Value`.

The complete example is below, with error handling. The `serde_json::Error` type does not automatically convert to `hyper::Error`, so instead we map the `serde_json::Error` to `io::Error`. The `io::Error` type will automatically convert to `hyper::Error`.

```rust
extern crate futures;
extern crate hyper;
extern crate tokio_core;
extern crate serde_json;
use std::io;
use futures::{Future, Stream};
use hyper::Client;
use tokio_core::reactor::Core;
use serde_json::Value;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
# let work = client.get(uri);
let mut core = Core::new()?;
let client = Client::new(&core.handle());

let uri = "http://httpbin.org/ip".parse()?;
let work = client.get(uri).and_then(|res| {
    println!("Response: {}", res.status());

    res.body().concat2().and_then(move |body| {
        let v: Value = serde_json::from_slice(&body).map_err(|e| {
            io::Error::new(
                io::ErrorKind::Other,
                e
            )
        })?;
        println!("current IP address is {}", v["origin"]);
        Ok(())
    })
});
core.run(work)?;
# Ok(())
# }
# fn main() {}
```

[client/basic]: {{ site.docs_url }}/guides/client/basic/
[serde_json]: https://docs.serde.rs/serde_json/
[Stream]: {{ site.futures_url }}/futures/stream/trait.Stream.html
[Concat2]: {{ site.futures_url }}/futures/stream/trait.Stream.html#method.concat2
[Chunk]: {{ site.docs_url }}/hyper/struct.Chunk.html
