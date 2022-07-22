(ns repro
  (:require [core2.api :as c2]
            [core2.local-node :as local-node]
            [core2.sql.pgwire :as pgwire]
            [juxt.clojars-mirrors.nextjdbc.v1v2v674.next.jdbc :as jdbc])
  (:import (java.sql Connection)
           (ch.qos.logback.classic Level Logger)
           (org.slf4j LoggerFactory)))

(defn set-log-level! [ns level]
  (.setLevel ^Logger (LoggerFactory/getLogger (name ns))
             (when level
               (Level/valueOf (name level)))))

(defn- jdbc-conn ^Connection [& params]
  (jdbc/get-connection "jdbc:postgresql://localhost/xtdb/"))

(defn add-sample-txs [txs]
  (let [tx (c2/submit-tx node txs)]
    (println "Sample transaction sent:\n\n" (deref tx))))

(comment ;; OVERLAPS PERIOD with SYSTEM_TIME AS OF ISSUE
  (set-log-level! 'core2.sql.pgwire :debug)
  (def node (local-node/start-node {}))
  (def server (pgwire/serve node))
  (add-sample-txs [[:put {:_id :my-doc, :last_updated "2000"}
                    {:_valid-time-start #inst "2000"}]
                   [:put {:_id :my-doc, :last_updated "3000"}
                    {:_valid-time-start #inst "3000"}]
                   [:put {:_id :some-other-doc, :last_updated "4000"}
                    {:_valid-time-start #inst "4000"
                     :_valid-time-end #inst "4001"}]])
  (with-open [conn (jdbc-conn)]
    (->> (jdbc/execute! conn ["SELECT foo.last_updated FROM foo WHERE foo.APP_TIME OVERLAPS PERIOD (TIMESTAMP '4000-01-01 00:00:00', TIMESTAMP '4001-01-01 00:00:00') FOR SYSTEM_TIME AS OF TIMESTAMP '2000-01-01 00:00:00'"])))

  ;; Unhandled org.postgresql.util.PSQLException
  ;; ERROR: #core2.sql.parser.ParseFailure{:in "SELECT foo.last_updated FROM foo
  ;;  WHERE foo.APP_TIME OVERLAPS PERIOD (TIMESTAMP '4000-01-01 00:00:00',
  ;;  TIMESTAMP '4001-01-01 00:00:00') FOR SYSTEM_TIME AS OF TIMESTAMP '2000-01-01
  ;;  00:00:00'", :errs #{[:expected "GROUP"] [:expected "UNION"] [:expected "OR"]
  ;;                      [:expected "IS"] [:expected "HAVING"] [:expected "AND"] [:expected "ORDER"]
  ;;                      [:expected "<EOF>"] [:expected "OFFSET"] [:expected "EXCEPT"] [:expected
  ;;                                                                                     "FETCH"] [:expected "INTERSECT"]}, :idx 135} Detail: Parse error at line 1,
  ;; column 136: SELECT foo.last_updated FROM foo WHERE foo.APP_TIME OVERLAPS
  ;; PERIOD (TIMESTAMP '4000-01-01 00:00:00', TIMESTAMP '4001-01-01 00:00:00') FOR
  ;; SYSTEM_TIME AS OF TIMESTAMP '2000-01-01 00:00:00' ^ Expected one of: GROUP
  ;; UNION OR IS HAVING AND ORDER <EOF> OFFSET EXCEPT FETCH INTERSECT

  ;; Position: 136

  (.close server)
  (.close node)

  )
