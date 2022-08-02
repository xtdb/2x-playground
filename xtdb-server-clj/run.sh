#!/usr/bin/env bash

clojure -X:deps prep :force true
clj -X:run
