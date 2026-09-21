# Example project

A small synthetic project with the protocol's files in place, so you can see the shape before
installing it into your own. Nothing here is from a real estate.

```sh
# from the repository root
./install.sh --project examples/example-project     # puts hooks, commands and settings in place
./install.sh --check   examples/example-project     # silent: every budget holds
```

To see the check fire, make the index long and run it again:

```sh
for i in $(seq 1 120); do echo "- line $i"; done >> examples/example-project/memory/MEMORY.md
./install.sh --check examples/example-project
git checkout examples/example-project/memory/MEMORY.md
```
