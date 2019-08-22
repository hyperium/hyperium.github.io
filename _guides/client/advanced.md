---
title: Advanced Client Usage
---

Once you've done all the setup in the [simple guide][], you probably
have more advanced requests you need to make. In this guide, we'll
make a `POST` request, and make multiple requests at the same time.

## Making a POST

We can prepare a [`Request`][Request] before giving it to the client.
Since we want to post some JSON, and not just simply get a resource,
that's what we'll do.

```rust
# extern crate hyper;
use hyper::{Method, Request};
# fn main() {}
```

After a quick addition to imports

```rust
# extern crate hyper;
# extern crate http;
# use http::header::HeaderValue;
# use hyper::{Method, Request, Body};
# fn run() {
// still inside rt::run...
let json = r#"{"library":"hyper"}"#;
let uri: hyper::Uri = "http://httpbin.org/post".parse().unwrap();
let mut req = Request::new(Body::from(json));
*req.method_mut() = Method::POST;
*req.uri_mut() = uri.clone();
req.headers_mut().insert(
    hyper::header::CONTENT_TYPE,
    HeaderValue::from_static("application/json")
);
# }
# fn main() {}
```

We set the [`Method`][Method] to `Post`, add a URL, and some headers describing our
payload. Lastly, a call to `set_body` with our JSON bytes. Then, we
can give that to the `client` with the `request` method:

```rust
# extern crate futures;
# extern crate hyper;
# extern crate http;
# use futures::{Future, Stream};
# use http::header::HeaderValue;
# use hyper::{Client, Method, Request, Body};
# fn run() -> Result<(), Box<dyn std::error::Error>> {
# let client = Client::new();
# let json = r#"{"library":"hyper"}"#;
# let uri: hyper::Uri = "http://httpbin.org/post".parse()?;
# let mut req = Request::new(Body::from(json));
# *req.method_mut() = Method::POST;
# *req.uri_mut() = uri.clone();
# req.headers_mut().insert("content-type", HeaderValue::from_static("application/json"));
// still inside rt::run...
let post = client.request(req).and_then(|res| {
    println!("POST: {}", res.status());

    res.into_body().concat2()
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
# use futures::{Future, Stream};
# use hyper::{Client, Method, Request};
# fn run() -> Result<(), Box<dyn std::error::Error>> {
# let client = Client::new();
// still inside rt::run...
let get = client.get("http://httpbin.org/headers".parse().unwrap()).and_then(|res| {
    println!("GET: {}", res.status());

    res.into_body().concat2()
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
# extern crate http;
# extern crate tokio;
# use futures::{Future, Stream};
# use http::header::HeaderValue;
# use hyper::{rt, Client, Method, Request, Body};
# use std::str;
# fn run() {
# rt::run(rt::lazy(|| {
# let client = Client::new();
# let json = r#"{"library":"hyper"}"#;
# let uri: hyper::Uri = "http://httpbin.org/post".parse().unwrap();
# let mut req = Request::new(Body::from(json));
# *req.method_mut() = Method::POST;
# *req.uri_mut() = uri.clone();
# req.headers_mut().insert("content-type", HeaderValue::from_static("application/json"));
# let post = client.request(req).and_then(|res| {
#     println!("POST: {}", res.status());
#
#     res.into_body().concat2()
# });
#
# let get = client.get("http://httpbin.org/headers".parse().unwrap()).and_then(|res| {
#     println!("GET: {}", res.status());
#
#     res.into_body().concat2()
# });
// still inside rt::run...
let work = post.join(get);

work
    .map(|(posted, got)| {
        println!("GET: {:?}", got);
        println!("POST: {:?}", posted);
    })
    .map_err(|err| {
        println!("Error: {}", err);
    })
# }));
# }
# fn main() {}

```

Last step, we are just printing them to stdout.

[simple guide]: ./basic.md
[Request]: {{ site.docs_url }}/hyper/client/struct.Request.html
[Method]: {{ site.docs_url }}/hyper/enum.Method.html
[Join]: {{ site.futures_url }}/futures/future/trait.Future.html#method.join
