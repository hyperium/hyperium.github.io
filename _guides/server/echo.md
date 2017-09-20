---
title: Echo, echo, echo
---

You already have a [Hello World server](./index)? Excellent! Usually,
servers do more than just spit out the same body for every request. To
exercise several more parts of hyper, this guide will go through
building an echo server.

An echo server will listen for incoming connections and send back the
request body as the response body on `POST` requests.

## Routing

First thing we will do, beyond renaming our service to `Echo`, is setup some
routing. We want to have a route explaining instructions on how to use
our server, and another for receiving data. Oh, and we should also
handle the case when someone asks for a route we don't know!

We need to add some to our imports:

```rust
# extern crate hyper;
use hyper::{Method, StatusCode};
# fn main() {}
```

And make some changes to your `Service`:

```rust
# extern crate futures;
# extern crate hyper;
# use futures::future::Future;
# use hyper::{Method, StatusCode};
# use hyper::server::{Request, Response, Service};

struct Echo;

impl Service for Echo {
    // ... types here
#    type Request = Request;
#    type Response = Response;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item=Self::Response, Error=Self::Error>>;

    fn call(&self, req: Request) -> Self::Future {
        let mut response = Response::new();

         match (req.method(), req.path()) {
            (&Method::Get, "/") => {
                response.set_body("Try POSTing data to /echo");
            },
            (&Method::Post, "/echo") => {
                // we'll be back
            },
            _ => {
                response.set_status(StatusCode::NotFound);
            },
        };

        Box::new(futures::future::ok(response))
    }
}

# fn main() {}
```

We built a super simple routing table just by matching on the `method`
and `path` of an incoming `Request`. If someone requests `GET /`, our
service will let them know they should try our echo powers out. We also
are checking for `POST /echo`, but currently don't do anything about it.

Our third rule catches any other method and path combination, and
changes the `StatusCode` of the `Response`. The default status of a
`Response` is HTTP's `200 OK` (`StatusCode::Ok`), which is correct for
the other routes. But the third case will instead send back `404 Not
Found`.

## Body Streams

So let's get that echo in place. We'll start with the simplest solution, and
then make alterations exercising more complex things you can do with the
`Body` streams.

First up, plain echo. Both the `Request` and the `Response` have body streams,
and by default, you can easily just pass the `Body` of the `Request` into the
`Response`.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::future::Future;
# use hyper::{Method, StatusCode};
# use hyper::server::{Request, Response, Service};
# struct Echo;
# impl Service for Echo {
#     // ... types here
#     type Request = Request;
#     type Response = Response;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item=Self::Response, Error=Self::Error>>;
#
#     fn call(&self, req: Request) -> Self::Future {
#         let mut response = Response::new();
#
#          match (req.method(), req.path()) {
#             (&Method::Get, "/") => {
#                 response.set_body("Try POSTing data to /echo");
#             },
// inside that match from before
(&Method::Post, "/echo") => {
    response.set_body(req.body());
},
#             _ => {
#                 response.set_status(StatusCode::NotFound);
#             },
#         };
#
#         Box::new(futures::future::ok(response))
#     }
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
use std::ascii::AsciiExt;
use futures::Stream;
use hyper::Chunk;
# fn main() {}
```

A `Body` implements the `Stream` trait from futures, producing a bunch of
`Chunk`s, as data comes in. A `Chunk` is just a convenient type from hyper
that represents a bunch of bytes. It can be easily converted into other
typical containers of bytes.

Next, let's make a function that maps our bytes into uppercase:

```rust
# extern crate hyper;
# use std::ascii::AsciiExt;
# use hyper::Chunk;
fn to_uppercase(chunk: Chunk) -> Chunk {
    let uppered = chunk.iter()
        .map(|byte| byte.to_ascii_uppercase())
        .collect::<Vec<u8>>();
    Chunk::from(uppered)
}
# fn main() {}
```

We'll also need to update the `Stream` type that our `Response` is using.
By default, it just uses `hyper::Body`, but `Response` can use any `Stream`
of items that implement `AsRef<[u8]>`. To make things easy, we'll use a boxed
`Stream`, like so:

```rust
# extern crate futures;
# extern crate hyper;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Method, StatusCode};
# use hyper::server::{Request, Response, Service};
# use std::ascii::AsciiExt;
# fn to_uppercase(chunk: Chunk) -> Chunk {
#     let uppered = chunk.iter()
#         .map(|byte| byte.to_ascii_uppercase())
#         .collect::<Vec<u8>>();
#     Chunk::from(uppered)
# }
# struct Echo;
impl Service for Echo {
#     type Request = Request;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item=Self::Response, Error=Self::Error>>;
    // other types stay the same
    type Response = Response<Box<Stream<Item=Chunk, Error=Self::Error>>>;

    fn call(&self, req: Request) -> Self::Future {
#         let mut response = Response::new();
#
#          match (req.method(), req.path()) {
            // ...
            // we need to convert this to a boxed stream now
            (&Method::Get, "/") => {
                let body: Box<Stream<Item=_, Error=_>> = Box::new(Body::from("Try POSTing to /echo!"));
                response.set_body(body);
            },
            // we make a Map stream, and box it!
            (&Method::Post, "/echo") => {
                let mapping = req.body().map(to_uppercase as fn(Chunk) -> Chunk);
                let body: Box<Stream<Item=_, Error=_>> = Box::new(mapping);
                response.set_body(body);
            },
            // ...
#             _ => {
#                 response.set_status(StatusCode::NotFound);
#             },
#         };
#
#         Box::new(futures::future::ok(response))
    }

}
# fn main() {}
```

## Buffering the Request Body

What if we wanted our echo service to respond with the data reversed? We can't really stream the data as it comes in, since we need to find the end before we can respond. To do this, we can explore how to easily collect the full body.

To reduce complexity for now, we'll back our uppercasing logic out, and go back to the default `Response` type.

In this case, however, we can't really generate a `Response` immediately, but instead must wait for the full request body to be received.


1. With `GET /`, we have an immediate `Response`, and would like to use `future::ok`.
2. With `POST /echo`, we need to wait before we can give a `Response`. We'll be waiting on concatenating all the `Chunk`s together, so this future would be a `futures::stream::Concat2` combined with a `futures::future::Map`.

Since we're returning boxed `Future`s, this should be pretty easy to do.

First up, we'll make a simple function to map onto our concatenated `Chunk`:

```rust
# extern crate hyper;
# use hyper::Chunk;
# use hyper::server::Response;
fn reverse(chunk: Chunk) -> Response {
    let reversed = chunk.iter()
        .rev()
        .cloned()
        .collect::<Vec<u8>>();
    Response::new()
        .with_body(reversed)
}
# fn main() {}
```

Now, we want to concatenate the request body, and map the result into our `reverse` function, and return the eventual result.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::{Future, Stream};
# use hyper::{Chunk, Method, StatusCode};
# use hyper::server::{Request, Response, Service};
# struct Echo;
# fn reverse(chunk: Chunk) -> Response {
#     let reversed = chunk.iter()
#         .rev()
#         .cloned()
#         .collect::<Vec<u8>>();
#     Response::new()
#         .with_body(reversed)
# }
impl Service for Echo {
#     type Request = Request;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item=Self::Response, Error=Self::Error>>;
    // back to default Response
    type Response = Response;

    fn call(&self, req: Request) -> Self::Future {
         match (req.method(), req.path()) {
            (&Method::Get, "/") => {
                Box::new(futures::future::ok(
                    Response::new().with_body("Try POSTing data to /echo")
                ))
            },
            (&Method::Post, "/echo") => {
                Box::new(
                    req.body()
                        .concat2()
                        .map(reverse)
                )
            },
            _ => {
                Box::new(futures::future::ok(
                    Response::new().with_status(StatusCode::NotFound)
                ))
            },
        }
    }
}
# fn main() {}
```
