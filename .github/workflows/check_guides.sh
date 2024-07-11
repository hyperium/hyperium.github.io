#!/bin/sh

for value in legacy stable; do
  if [ ! -e "$value/Cargo.toml" ]; then
    if [ ! -d "$value" ]; then
      cargo new "$value"
    else
      cargo init "$value"
    fi

    case "$value" in
      legacy)
        cat >> "$value/Cargo.toml" <<-EOF
        [dependencies]
        futures = "0.3"
        hyper = { version = "0.14", features = ["full"] }
        hyper-tls = "0.5"
        tokio = { version = "1", features = ["full"] }
EOF
        ;;
      stable)
        cat >> "$value/Cargo.toml" <<-EOF
        [dependencies]
        hyper = { version = "1", features = ["full"] }
        tokio = { version = "1", features = ["full"] }
        http-body-util = "0.1"
        hyper-util = { version = "0.1", features = ["full"] }
        tower = "0.4"
EOF
        ;;
    esac

    cargo build --manifest-path "$value/Cargo.toml"
  fi

  test_file() {
    echo "Testing: $1"
    rustdoc --edition 2021 --test "$1" -L "$value/target/debug/deps"
  }

  if [ -n "$1" ]; then
    test_file "$1"
    exit $?
  fi

  status=0
  for f in $(git ls-files | grep "^_$value\/.*\.md$"); do
    test_file "$f"
    s=$?
    ((status == 0)) && status=$s
  done
done

exit $status
