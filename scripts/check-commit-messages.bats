#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# The stub hook accepts only `chore:` subjects, so these tests cover which
# commits reach the hook.
setup() {
    script="$BATS_TEST_DIRNAME/check-commit-messages.sh"
    cd "$BATS_TEST_TMPDIR"

    mkdir bin
    cat > bin/pre-commit <<'EOF'
#!/usr/bin/env bash
while [ "$1" != --commit-msg-filename ]; do shift; done
grep -q '^chore: ' "$2"
EOF
    chmod +x bin/pre-commit
    PATH="$PWD/bin:$PATH"

    git init -q -b develop repo
    cd repo
    git config user.name Test
    git config user.email test@example.com
    git commit -q --allow-empty -m "chore: Start"
    base=$(git rev-parse HEAD)
}

commit() {
    git commit -q --allow-empty -m "$1"
}

@test "accepts typed commits" {
    commit "chore: First"
    commit "chore: Second"
    run "$script" "$base" HEAD
    [ "$status" -eq 0 ]
}

@test "reports every untyped commit, not only the first" {
    commit "Untyped one"
    commit "chore: Typed"
    commit "Untyped two"
    run "$script" "$base" HEAD
    [ "$status" -eq 1 ]
    [ "$(grep -c '::error::' <<< "$output")" -eq 2 ]
}

@test "skips merge commits" {
    git switch -q -c feature
    commit "chore: On the branch"
    git switch -q develop
    commit "chore: On develop"
    git merge -q --no-ff --no-edit feature
    run "$script" "$base" HEAD
    [ "$status" -eq 0 ]
}

@test "ignores commits before the base" {
    commit "Untyped before"
    base=$(git rev-parse HEAD)
    commit "chore: After"
    run "$script" "$base" HEAD
    [ "$status" -eq 0 ]
}
