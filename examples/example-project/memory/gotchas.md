# Gotchas
<!-- Last updated: 2026-09-10 -->

- The dev server binds `::` first. On a machine where `localhost` resolves to `127.0.0.1`
  only, `curl localhost:3000` refuses while `curl [::1]:3000` answers. Use `127.0.0.1` in
  scripts or bind `0.0.0.0` explicitly. Found 2026-09-10; cost an hour.
