#!/usr/bin/zsh

docker run --name starknet-devnet -p 5050:5050 --env-file .starknet-devnet-env --rm shardlabs/starknet-devnet-rs 