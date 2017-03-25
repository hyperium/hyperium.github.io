---
title: Echo
layout: guide
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
use hyper::{Method, StatusCode};
```

And make some changes to your `Service`:

```rust
impl Service for Echo {
    // ... types here
#    type Request = Request;
#    type Response = Response;
#    type Error = hyper::Error;
#    type Future = futures::future::FutureResult<Self::Response, Self::Error>;

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

        futures::future::ok(response)
    }
}
```

We built a super simple routing table just by matching on the `method`
and `path` of an incoming `Request`. If someone requests `GET /`, our
service will let them know they should try our echo powers out. We also
are checking for `POST /echo`, but currently don't do anything about it.

Our third rule catches any other method and path combination, and
changes the `StatusCode` of the `Response`. The default status of a
`Response` is HTTP's `200 OK` (`StatusCode::Ok`), which is correct for
the other routes. But the third case will instead send back `400 Not
Found`.


