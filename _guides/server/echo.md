---
title: Echo, echo, echo
---

You already have a [Hello World server](hello-world.md)? Excellent! Usually,
servers do more than just spit out the same body for every request. To
exercise several more parts of hyper, this guide will go through
building an echo server.

An echo server will listen for incoming connections and send back the
request body as the response body on `POST` requests.

## Routing

First thing we will do, beyond renaming our service to `echo`, is setup some
routing. We want to have a route explaining instructions on how to use
our server, and another for receiving data. Oh, and we should also
handle the case when someone asks for a route we don't know!

We're going to be using more of the [futures][future-crate] crate, so let's add
that as a dependency:

```toml
[dependencies]
hyper = "0.12"
futures = "0.1" # yes, 0.1 for now
```

Then, we need to add some to our imports:

```rust
# extern crate hyper;
extern crate futures;

use futures::future;
use hyper::{Method, StatusCode};
# fn main() {}
```

And make some changes to your `Service`, such as returning a `Future` of a `Response`,
since we may not have one ready immediately:

```rust
# extern crate futures;
# extern crate hyper;
# use futures::future::{self, Future};
# use hyper::{Body, Method, Request, Response, StatusCode};

// Just a simple type alias
type BoxFut = Box<Future<Item=Response<Body>, Error=hyper::Error> + Send>;

fn echo(req: Request<Body>) -> BoxFut {
    let mut response = Response::new(Body::empty());

    match (req.method(), req.uri().path()) {
        (&Method::GET, "/") => {
            *response.body_mut() = Body::from("Try POSTing data to /echo");
        },
        (&Method::POST, "/echo") => {
            // we'll be back
        },
        _ => {
            *response.status_mut() = StatusCode::NOT_FOUND;
        },
    };

    Box::new(future::ok(response))
}
# fn main() {}
```

We built a super simple routing table just by matching on the `method`
and `path` of an incoming `Request`. If someone requests `GET /`, our
service will let them know they should try our echo powers out. We also
are checking for `POST /echo`, but currently don't do anything about it.

Our third rule catches any other method and path combination, and
changes the `StatusCode` of the `Response`. The default status of a
`Response` is HTTP's `200 OK` (`StatusCode::OK`), which is correct for
the other routes. But the third case will instead send back `404 Not
Found`.

Finally, we introduced returning a `Future`. So far, we have the `Response`
ready immediately, so we can wrap it in a `future::ok` call.

What's with the `Box`? The example so far doesn't need it, and even as we
expand it, it is true that you can do all these without allocating a trait
object. The reason, though, is for ease. We will need to return *different*
`Future`s, while starting out, it's easiest to just put all the different
possible return values into a boxed trait object.

## Hooking up the Service

Since we're changing the status code, we can't use the same `service_fn_ok` from the previous guide to wrap our service.
Instead, we'll use `service_fn`:

```rust
# extern crate hyper;
use hyper::service::service_fn;
```

So, the server setup will change accordingly (inlined a bit for brevity):

```rust
# extern crate futures;
# extern crate hyper;
# 
# use futures::future;
# use hyper::rt::Future;
# use hyper::{Body, Request, Response, Server};
# use hyper::service::service_fn;
# 
# type BoxFut = Box<Future<Item=Response<Body>, Error=hyper::Error> + Send>;
# 
# fn echo(_req: Request<Body>) -> BoxFut {
#     Box::new(future::ok(Response::new(Body::empty())))
# }
# 
# fn run() {
    let addr = ([127, 0, 0, 1], 3000).into();

    let server = Server::bind(&addr)
        .serve(|| service_fn(echo))
        .map_err(|e| eprintln!("server error: {}", e));

    hyper::rt::run(server);
# }
# fn main() {}
```

## Body Streams

So let's get that echo in place. We'll start with the simplest solution, and
then make alterations exercising more complex things you can do with the
`Body` streams.

First up, plain echo. Both the `Request` and the `Response` have body streams,
and by default, you can easily just pass the `Body` of the `Request` into the
`Response`.

```rust
# extern crate hyper;
# use hyper::{Body, Method, Request, Response};
# fn echo(req: Request<Body>) -> Response<Body> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// inside that match from before
(&Method::POST, "/echo") => {
    *response.body_mut() = req.into_body();
},
#         _ => unreachable!(),
#     }
#     response
# }
# fn main() {}
```

Running our server now will echo any data we `POST` to `/echo`. That was easy.
What if we wanted to uppercase all the text? We could use a `map` on our streams.

### Body mapping

We're going to need a couple of extra imports, so let's add those to the top of the file:

```rust
# extern crate futures;
# extern crate hyper;
use futures::Stream;
use hyper::Chunk;
# fn main() {}
```

A `Body` implements the `Stream` trait from futures, producing a bunch of
`Chunk`s, as data comes in. A `Chunk` is just a convenient type from hyper
that represents a bunch of bytes. It can be easily converted into other
typical containers of bytes.

Next, let's add a new `/echo/uppercase` route mapping the body to uppercase:

```rust
# extern crate hyper;
# use hyper::rt::Stream;
# use hyper::{Body, Method, Request, Response};
# fn echo(req: Request<Body>) -> Response<Body> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/uppercase") => {
    // This is actually a new `futures::Stream`...
    let mapping = req
        .into_body()
        .map(|chunk| {
            chunk.iter()
                .map(|byte| byte.to_ascii_uppercase())
                .collect::<Vec<u8>>()
        });

    // Use `Body::wrap_stream` to convert it to a `Body`...
    *response.body_mut() = Body::wrap_stream(mapping);
},
#         _ => unreachable!(),
#     }
#     response
# }
# fn main() {}
```

And like that, we have two echo routes: `/echo` which does no transformation,
and `/echo/uppercase` which returns all bytes after converting them to ASCII
uppercase.

## Buffering the Request Body

What if we want our echo service to reverse the data it received and send it
back to use? We can't really stream the data as it comes in, since we need to
find the end before we can respond. To do this, we can explore how to easily
collect the full body.

In this case, we can't really generate a `Response` immediately. Instead, we
must wait for the full request body to be received.

1. With `GET /`, `POST /echo`, and `POST /echo/uppercase`, we have an immediate `Response`, and would like to use `future::ok`.
2. With `POST /echo/reverse`, we need to wait before we can give a `Response`. We'll be waiting on concatenating all the `Chunk`s together, so this future would be a `futures::stream::Concat2` combined with a `futures::future::Map`.

Since we're returning boxed `Future`s, this should be pretty easy to do.

We want to concatenate the request body, and map the result into our `reverse` function, and return the eventual result.

```rust
# extern crate hyper;
# use hyper::{Body, Method, Request, Response};
# use hyper::rt::{Future, Stream};
# fn echo(req: Request<Body>) -> Box<Future<Item=Response<Body>, Error=hyper::Error> + Send> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/reverse") => {
    // This is actually a new `Future`, waiting on `concat`...
    let reversed = req
        .into_body()
        // A future of when we finally have the full body...
        .concat2()
        // `move` the `Response` into this future...
        .map(move |chunk| {
            let body = chunk.iter()
                .rev()
                .cloned()
                .collect::<Vec<u8>>();

            *response.body_mut() = Body::from(body);
            response
        });

    // We can't just return the `Response` from this match arm,
    // because we can't set the body until the `concat` future
    // completed...
    //
    // However, `reversed` is actually a `Future` that will return
    // a `Response`! So, let's return it immediately instead of
    // falling through to the default return of this function.
    return Box::new(reversed)
},
#         _ => unreachable!(),
#     }
# }
# fn main() {}
```

You can see a compiling [example here][example].

[example]: {{ site.examples_url }}/echo.rs
[future-crate]: https://github.com/rust-lang-nursery/futures-rs
