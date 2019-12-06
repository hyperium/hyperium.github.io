#!/bin/sh

if [ ! -e tmp/Cargo.toml ]; then
    if [ ! -d tmp ]; then
        cargo new tmp
    else
        cargo init tmp
    fi
    cat >> tmp/Cargo.toml <<-EOF
futures = "0.3"
hyper = { git = "https://github.com/hyperium/hyper" }
hyper-tls = { git = "https://github.com/hyperium/hyper-tls" }
tokio = { version = "0.2", features = ["full"] }
EOF
    cargo build --manifest-path tmp/Cargo.toml
fi

test_file() {
    echo "Testing: $f"
    rustdoc --edition 2018 --test $1 -L tmp/target/debug/deps
}

if [ -n "$1" ]; then
    test_file $1
    exit $?
fi

status=0
for f in `git ls-files | grep '\.md$'`; do
    test_file $f
    s=$?
    if [ "$s" != "0" ]; then
        status=$s
    fi
done

exit $status
