#!/usr/bin/env bats

setup() {
    script="$BATS_TEST_DIRNAME/check-tested-with.sh"
    cd "$BATS_TEST_TMPDIR"
}

cabal_with() {
    printf 'name: partir-qua-world\n%s\n' "$1" > partir-qua-world.cabal
}

@test "accepts a series matching the compiler in use" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    run "$script" 9.10.3
    [ "$status" -eq 0 ]
}

@test "accepts a compiler version with no patch component" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    run "$script" 9.10
    [ "$status" -eq 0 ]
}

@test "accepts the tree a Renovate bump leaves behind" {
    cabal_with 'tested-with:         GHC == 9.14.*'
    run "$script" 9.14.1
    [ "$status" -eq 0 ]
}

@test "rejects a compiler ahead of tested-with" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    run "$script" 9.14.1
    [ "$status" -eq 1 ]
    [[ "$output" == *"declares GHC 9.10 but the compiler in use is 9.14.1"* ]]
}

@test "rejects tested-with ahead of the compiler" {
    cabal_with 'tested-with:         GHC == 9.14.*'
    run "$script" 9.10.3
    [ "$status" -eq 1 ]
    [[ "$output" == *"declares GHC 9.14"* ]]
}

@test "rejects a tested-with that is not a series constraint" {
    cabal_with 'tested-with:         GHC >= 9.10'
    run "$script" 9.10.3
    [ "$status" -eq 1 ]
    [[ "$output" == *"no GHC series found"* ]]
}

@test "rejects a cabal file carrying no tested-with" {
    cabal_with '-- nothing here'
    run "$script" 9.10.3
    [ "$status" -eq 1 ]
    [[ "$output" == *"no GHC series found"* ]]
}

@test "rejects a missing compiler version" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    run "$script"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

@test "rejects an empty compiler version" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    run "$script" ""
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

@test "rejects a directory holding no cabal file" {
    run "$script" 9.10.3
    [ "$status" -eq 2 ]
    [[ "$output" == *"found 0"* ]]
}

@test "rejects a directory holding several cabal files" {
    cabal_with 'tested-with:         GHC == 9.10.*'
    cp partir-qua-world.cabal other.cabal
    run "$script" 9.10.3
    [ "$status" -eq 2 ]
    [[ "$output" == *"found 2"* ]]
}
