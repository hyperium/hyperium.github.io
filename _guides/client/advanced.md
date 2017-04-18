---
title: Advanced Client Usage
---

Once you've done all the setup in the simple guide, you probably
have more advanced request you need to make. In this guide, we'll
make a `POST` request, and make multiple requests at the same time.

As before, we setup a `Core` and `Client`:

```rust
let mut core = Core::new().unwrap();
let client = Client::new(&core.handle());
```

## Making a POST

We can prepare a [`Request`][Request] before giving it to the client.
Since we want to post some JSON, and not just simply get a resource,
that's what we'll do.

```rust
let json = r#"{"library":"hyper"}"#;
let mut req = Request::new(Method::Post, "http://httpbin.org/post");
req.headers_mut().set(ContentType::json());
req.headers_mut().set(ContentLength(json.len() as u64));
req.set_body(json);
```

We set the [`Method`][Method] to `Post`, and a URL, and some headers describing our
payload. Lastly, a call to `set_body` with our JSON bytes. Then, we
can give that to the `client` with the `request` method:

```rust
let post = client.request(req).and_then(|res| {
    println!("POST: {}", res.status());

    res.body().concat()
});
```

The future in `post` will resolve with a concatenated body stream,
which we'll print to the console soon. But first, let's also show
that we can make multiple requests at the same time.

Remember, the work in `post` won't actually do anything until we give
the future to the `core`.

## Multiple Requests

```rust
let get = client.get("http://httpbin.org/headers").and_then(|res| {
    println!("GET: {}", res.status());

    res.body().concat()
});
```

Just a simple `GET` request, also not actually running yet. We want to run
both of these futures until they are both finished. With futures, we call that
joining. We can [`join`][Join] the futures together, and that will return
a new `Future` that will only resolve once both are finished, yielding the return
values of both in a tuple.

```rust
let work = post.join(get);
let (posted, got) = core.run(work).unwrap();

println!("JSON: {}", str::from_utf8(&posted).unwrap());
println!("Headers: {}", str::from_utf8(&got).unwrap());
```

Last step, we are just decoding the bytes of the body into UTF-8 strings, and
printing them to stdout.

[Request]: {{ site.docs_url }}/hyper/client/struct.Request.html
[Method]: {{ site.docs_url }}/hyper/enum.Method.html
[Join]: {{ site.futures_url }}/futures/future/trait.Future.html#method.join
