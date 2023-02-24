#!/bin/sh

for value in legacy stable
do
    if [ ! -e "$value/Cargo.toml" ]; then
        if [ ! -d $value ]; then
            cargo new $value
        else
            cargo init $value
        fi
        if [ $value = legacy ]; then
            cat >> "$value/Cargo.toml" <<-EOF
    futures = "0.3"
    hyper = { version = "0.14", features = ["full"] }
    hyper-tls = "0.5"
    tokio = { version = "1", features = ["full"] }
EOF
            cargo build --manifest-path "$value/Cargo.toml"
        fi
        if [ $value = stable ]; then
            cat >> "$value/Cargo.toml" <<-EOF
    hyper = { version = "1.0.0-rc.3", features = ["full"] }
    tokio = { version = "1", features = ["full"] }
    http-body-util = "0.1.0-rc.2" 
EOF
            cargo build --manifest-path "$value/Cargo.toml"
        fi
    fi

    test_file() {
        echo "Testing: $f"
        rustdoc --edition 2018 --test $1 -L "$value/target/debug/deps"
    }

    if [ -n "$1" ]; then
        test_file $1
        exit $?
    fi

    status=0
    for f in `git ls-files | grep "^_$value\/.*\.md$"`; do
        test_file $f
        s=$?
        if [ "$s" != "0" ]; then
            status=$s
        fi
    done
done

exit $status
