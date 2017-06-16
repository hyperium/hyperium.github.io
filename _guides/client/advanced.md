---
title: Advanced Client Usage
---

Once you've done all the setup in the simple guide, you probably
have more advanced request you need to make. In this guide, we'll
make a `POST` request, and make multiple requests at the same time.

As before, we setup a `Core` and `Client`:

```rust
# extern crate hyper;
# extern crate tokio_core;
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
let mut core = Core::new()?;
let client = Client::new(&core.handle());
# Ok(())
# }
# fn main() {}
```

## Making a POST

We can prepare a [`Request`][Request] before giving it to the client.
Since we want to post some JSON, and not just simply get a resource,
that's what we'll do.

```rust
# extern crate hyper;
use hyper::{Method, Request};
use hyper::header::{ContentLength, ContentType};
# fn main() {}
```

After a quick addition to imports

```rust
# extern crate hyper;
# use hyper::{Method, Request};
# use hyper::header::{ContentLength, ContentType};
# fn run() -> Result<(), Box<::std::error::Error>> {
let json = r#"{"library":"hyper"}"#;
let uri = "http://httpbin.org/post".parse()?;
let mut req = Request::new(Method::Post, uri);
# let mut req: Request = req; // in full example, inference works
req.headers_mut().set(ContentType::json());
req.headers_mut().set(ContentLength(json.len() as u64));
req.set_body(json);
# Ok(())
# }
# fn main() {}
```

We set the [`Method`][Method] to `Post`, add a URL, and some headers describing our
payload. Lastly, a call to `set_body` with our JSON bytes. Then, we
can give that to the `client` with the `request` method:

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Client, Method, Request};
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/post".parse()?;
# let req = Request::new(Method::Post, uri);
let post = client.request(req).and_then(|res| {
    println!("POST: {}", res.status());

    res.body().concat2()
});
# Ok(())
# }
# fn main() {}
```

The future in `post` will resolve with a concatenated body stream,
which we'll print to the console soon. But first, let's also show
that we can make multiple requests at the same time.

Remember, the work in `post` won't actually do anything until we give
the future to the `core`.

## Multiple Requests

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Client, Method, Request};
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
let get = client.get("http://httpbin.org/headers".parse()?).and_then(|res| {
    println!("GET: {}", res.status());

    res.body().concat2()
});
# Ok(())
# }
# fn main() {}

```

Just a simple `GET` request, also not actually running yet. We want to run
both of these futures until they are both finished. With futures, we call that
joining. We can [`join`][Join] the futures together, and that will return
a new `Future` that will only resolve once both are finished, yielding the return
values of both in a tuple.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Client, Method, Request};
# use tokio_core::reactor::Core;
# use std::str;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/post".parse()?;
# let req = Request::new(Method::Post, uri);
# let post = client.request(req).and_then(|res| {
#     println!("POST: {}", res.status());
#
#     res.body().concat2()
# });
# let get = client.get("http://httpbin.org/headers".parse()?).and_then(|res| {
#     println!("GET: {}", res.status());
#
#     res.body().concat2()
# });
let work = post.join(get);
let (posted, got) = core.run(work).unwrap();

println!("POST: {}", str::from_utf8(&posted)?);
println!("GET: {}", str::from_utf8(&got)?);
# Ok(())
# }
# fn main() {}

```

Last step, we are just decoding the bytes of the body into UTF-8 strings, and
printing them to stdout.

[Request]: {{ site.docs_url }}/hyper/client/struct.Request.html
[Method]: {{ site.docs_url }}/hyper/enum.Method.html
[Join]: {{ site.futures_url }}/futures/future/trait.Future.html#method.join
