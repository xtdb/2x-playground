# core2-playground

Add the following to your `~/.clojure/deps.edn`:

```clojure
:nREPL
{:extra-deps
  {nrepl/nrepl {:mvn/version "0.9.0"}}}
```

Run `clojure -X:deps prep :force true` to install deps.

Run `clj -M:nREPL -m nrepl.cmdline` and connect from your editor.
