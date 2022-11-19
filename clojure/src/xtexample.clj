(ns xtexample
  (:require [clojure.string :as str]
            [core2.api :as c2]
            [core2.node :as node]
            [core2.pgwire :as pgwire]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc :as jdbc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.connection :as jdbcc]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.prepare :as jdbcp]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.result-set :as jdbcr]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.types :as jdbct]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.date-time :as jdbcdt]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.sql :as jsql]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc.sql.builder :as bsql]
            [jsonista.core :as json]
            [honey.sql :as sql]
            [honey.sql.helpers :as hsql]
            [portal.api :as p])
  (:import (java.sql Connection PreparedStatement)
           (org.postgresql.util PGobject)))

(declare node)
(declare server)

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
      (when-let [value (<-json value)]
        (if (coll? value)
          (with-meta value {:pgtype type})
          value))
      value)))

(extend-protocol jdbcp/SettableParameter
  clojure.lang.IPersistentMap
  (set-parameter [m ^PreparedStatement s i]
    (.setObject s i (->pgobject m)))

  clojure.lang.IPersistentVector
  (set-parameter [v ^PreparedStatement s i]
    (.setObject s i (->pgobject v))))

(extend-protocol jdbcr/ReadableColumn
  org.postgresql.util.PGobject
  (read-column-by-label [^org.postgresql.util.PGobject v _]
    (<-pgobject v))
  (read-column-by-index [^org.postgresql.util.PGobject v _2 _3]
    (<-pgobject v)))


(defn insert!
  "regular jsql/insert! is blocked by an inability to handle `RETURING *`"
  ([connectable table key-map]
   (insert! connectable table key-map {}))
  ([connectable table key-map opts]
   (let [opts (merge (:options connectable) opts)
         key-map (assoc key-map :cols (str/join " " (map #(subs (str %) 1) (keys key-map))))]
     (jdbc/execute-one! connectable
                   (bsql/for-insert table key-map opts)
                   (merge {:return-keys false} opts)))))

(defn map-vals [f m] (reduce-kv (fn [m k v] (assoc m k (f v))) {} m))

(defn entity [conn id]
  ;; assumes as_of_now is already set
  #_(jdbc/execute-one! conn [ "SET application_time_defaults TO as_of_now;"])
  (letfn [(get-colls [conn id]
            (->> (some-> (jdbc/execute! conn (sql/format {:select :a.cols :from :a :where [:= :a.id id] :limit :1}))
                         first
                         :cols
            ;;             <-pgobject
                         (str/split #" "))
                 (map #(keyword "a" %))))]
    (let [colls (get-colls conn id)]
      colls
      (when (not-empty colls)
        (->> (jdbc/execute! conn (sql/format {:select colls
                                              :from :a :where [:= :a.id id] :limit :1}))
             first
             #_(map-vals <-pgobject))))))

(comment
  (def node (node/start-node {:core2/pgwire {}}))

  (with-open [conn (jdbc-conn)]
    (jdbc/execute-one! conn [ "SET application_time_defaults TO as_of_now;"])
    (let [m1 {:id 1234 :name 4579999 :foo "asdf" :mydate (jdbct/as-date #inst "1990-01-01") #_#_:arr [1 2 3]}]
      (insert! conn :a m1)
      (let [e (entity conn (:id m1))]
        [(= e m1) e])))

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
