;; Copyright © 2023, JUXT LTD.

(ns v2-landing.client
  (:require
   [xtdb.node :as xt.node]
   [xtdb.client :as xt.client]
   [xtdb.api :as xt]))

(def my-node (xt.node/start-node {:xtdb/server {:port 3001}
                                  :xtdb/pgwire {:port 5432}}))

(def my-client (xt.client/start-client "http://localhost:3001"))

(xt/status my-client)

(xt/submit-tx my-client [[:put :posts {:xt/id 1234
                                       :user-id 5678
                                       :text "hello world!"}]])

(xt/q my-client '{:find [text]
                  :where [($ :posts [text])]})
