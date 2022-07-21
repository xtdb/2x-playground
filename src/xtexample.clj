(ns xtexample
  (:require [core2.api :as c2]
            [core2.local-node :as local-node]
            [core2.sql.pgwire :as pgwire]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc :as jdbc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.connection :as jdbcc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.result-set :as jdbcr])
  (:import (java.sql Connection)))

(declare node)
(declare server)

;; TODO: remove this when we have basic DML
(defn add-sample-txs []
  (let [tx (c2/submit-tx node [[:put {:_id (random-uuid) :name "James"}]
                               [:put {:_id (random-uuid) :name "Matt"}]
                               [:put {:_id (random-uuid) :name "Dan"}]])]
    (println "Sample transaction sent:\n\n" (deref tx))))

(defn run [opts]
  (println "XTDB started.")
  (add-sample-txs)
  #_(read-line))

(defn- jdbc-conn ^Connection [& params]
  (jdbc/get-connection "jdbc:postgresql://localhost/xtdb"))

(comment
  (with-open [conn (jdbc-conn)]
    (jdbc/execute! conn ["SELECT a.name FROM a"]))

  (def node (local-node/start-node {}))

  (def server (pgwire/serve node))

  (run {})

  ;; SELECT foo.name FROM foo
  )
