(ns xtexample
  (:require [core2.api :as c2]
            [core2.local-node :as local-node]
            [core2.sql.pgwire :as pgwire]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc :as jdbc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.connection :as jdbcc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.result-set :as jdbcr]
            [jsonista.core :as json]
            [honey.sql :as sql])
  (:import (java.sql Connection)
           (org.postgresql.util PGobject)))

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
  (jdbc/get-connection "jdbc:postgresql://localhost/xtdb/"))

(def mapper (json/object-mapper {:decode-key-fn keyword}))
(def ->json json/write-value-as-string)
(def <-json #(json/read-value % mapper))

(defn ->pgobject
  "Transforms Clojure data to a PGobject that contains the data as
  JSON. PGObject type defaults to `jsonb` but can be changed via
  metadata key `:pgtype`"
  [x]
  (let [pgtype (or (:pgtype (meta x)) "jsonb")]
    (doto (PGobject.)
      (.setType pgtype)
      (.setValue (->json x)))))

(defn <-pgobject
  "Transform PGobject containing `json` or `jsonb` value to Clojure
  data."
  [^org.postgresql.util.PGobject v]
  (let [type  (.getType v)
        value (.getValue v)]
    (if (#{"jsonb" "json"} type)
      (when value
        (with-meta (<-json value) {:pgtype type}))
      value)))

(comment
  (def node (local-node/start-node {}))

  (def server (pgwire/serve node))

  (run {})

  (with-open [conn (jdbc-conn)]
    (->> (jdbc/execute! conn (sql/format {:select :a.name :from :a}))
         (map :name)
         first))

  )

(comment
  (def overlaps "APP_TIME OVERLAPS" :overlaps)

  (sql/register-op! overlaps)

  (defn- my-formatter [f x]
    (let [[sql & params] (sql/format-expr x)]
      (into [(str "FOR SYSTEM_TIME AS OF " sql )] params)))

  (sql/register-clause! :for-system-time-as-of my-formatter :with-data)

  (sql/clause-order)

  (sql/format {:select [:foo.name :bar.also_name]
               :from [:foo :bar]
               :join-by [:left [[:baz]
                                [:using :id]]]
               :where [:overlaps :foo.APP_TIME :bar.APP_TIME]
               :for-system-time-as-of [:inline 123]})
  )
