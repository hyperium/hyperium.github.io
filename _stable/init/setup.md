---
title:  Initial Setup
layout: guide
permalink: /guides/1/init/setup/
---

This will help get your initial setup ready to be able to try out the
lessons in the guides.

## Dependencies

To make things simple, you can add the follow crates to your
`Cargo.toml`:

```toml
[dependencies]
hyper = { version = "1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1"
hyper-util = { version = "0.1", features = ["full"] }
```

And with that, you're good to go! Depending on what you want to
accomplish, you can move on to either the [client][] or [server][]
guides.

[client]: ../../client/basic
[server]: ../../server/hello-world/
