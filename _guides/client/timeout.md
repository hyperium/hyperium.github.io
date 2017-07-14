---
title: General Timeout
---

There are cases when you want to limit the amount of time a client request takes. Using
[`tokio_core::Timeout`][Timeout], you can set a timeout for the entire request. This includes
the amount of time elapsed for the initial connection and any read and write operations.

Let us start with a basic get request.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use std::io;
# use std::str;
# use std::time::Duration;
# use futures::Future;
# use futures::future::Either;
# use futures::stream::Stream;
# use tokio_core::reactor::{Core, Timeout};
# use hyper::Client;
# fn run() -> Result<(), Box<::std::error::Error>> {
let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;

let mut core = Core::new()?;
let handle = core.handle();
let client = Client::new(&handle);

let get = client.get(url).and_then(|res| res.body().concat2());

let got = core.run(get)?;
println!("{}", str::from_utf8(&got)?);
# Ok(())
# }
# fn main() {}
```

Now we want to limit the time the request takes. We will create a `Timeout` future and specify the
maximum amount of time we want the get request to execute for. The `Timeout` requires a reference to
a `Handle` beacuse it will be spawned in the `Core` along with the get request.


```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use std::io;
# use std::str;
# use std::time::Duration;
# use futures::Future;
# use futures::future::Either;
# use futures::stream::Stream;
# use tokio_core::reactor::{Core, Timeout};
# use hyper::Client;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let handle = core.handle();

let timeout = Timeout::new(Duration::from_secs(5), &handle)?;

# Ok(())
# }
# fn main() {}
```

Now that we have a timeout future, we need to merge the `get` and `timeout` futures together and see
which one completes first. We can do this using the [`select2`][Select2] future.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use std::io;
# use std::str;
# use std::time::Duration;
# use futures::Future;
# use futures::future::Either;
# use futures::stream::Stream;
# use tokio_core::reactor::{Core, Timeout};
# use hyper::Client;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let mut core = Core::new()?;
# let handle = core.handle();
# let client = Client::new(&handle);
# let get = client.get(url).and_then(|res| res.body().concat2());
# let timeout = Timeout::new(Duration::from_secs(5), &handle)?;
let work = get.select2(timeout).then(|res| match res {
    Ok(Either::A((got, _timeout))) => Ok(got),
    Ok(Either::B((_timeout_error, _get))) => {
        Err(hyper::Error::Io(io::Error::new(
            io::ErrorKind::TimedOut,
            "Client timed out while connecting",
        )))
    }
    Err(Either::A((get_error, _timeout))) => Err(get_error),
    Err(Either::B((timeout_error, _get))) => Err(From::from(timeout_error)),
});

# let got = core.run(work)?;
# println!("{}", str::from_utf8(&got)?);
# Ok(())
# }
# fn main() {}
```

When using `select2` we need to account for four possibilities: the get request completing
successfully, the timeout completing successfully, the get request having an error and the timeout
having an error. `select2` will return the result of the future completing/erroring as well as the
incomplete future using the `Either` enum. In this case, we are not interested in the incomplete future.
In order to aid in the understanding of how `select2` works, none of the variables have been elided.

The complete example is below.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use std::io;
# use std::str;
# use std::time::Duration;
# use futures::Future;
# use futures::future::Either;
# use futures::stream::Stream;
# use tokio_core::reactor::{Core, Timeout};
# use hyper::Client;
# fn run() -> Result<(), Box<::std::error::Error>> {
let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;

let mut core = Core::new()?;
let handle = core.handle();
let client = Client::new(&handle);

let get = client.get(url).and_then(|res| res.body().concat2());

let timeout = Timeout::new(Duration::from_secs(5), &handle)?;
let work = get.select2(timeout).then(|res| match res {
    Ok(Either::A((got, _timeout))) => Ok(got),
    Ok(Either::B((_timeout_error, _get))) => {
        Err(hyper::Error::Io(io::Error::new(
            io::ErrorKind::TimedOut,
            "Client timed out while connecting",
        )))
    }
    Err(Either::A((get_error, _timeout))) => Err(get_error),
    Err(Either::B((timeout_error, _get))) => Err(From::from(timeout_error)),
});

let got = core.run(work)?;
println!("{}", str::from_utf8(&got)?);
# Ok(())
# }
# fn main() {}
```

[Timeout]: {{ site.tokio_core_url }}/tokio_core/reactor/struct.Timeout.html
[Select2]: {{ site.futures_url }}/futures/future/trait.Future.html#method.select2
