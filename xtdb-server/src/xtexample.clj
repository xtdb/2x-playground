(ns xtexample
  (:require [core2.api :as c2]
            [core2.local-node :as local-node]
            [core2.sql.pgwire :as pgwire]))

(def node (local-node/start-node {}))
(def server (pgwire/serve node))

;; TODO: remove this when we have basic DML and run a batch insert instead
(defn add-sample-txs []
  (let [tx (c2/submit-tx node [[:put {:_id (random-uuid) :name "James"}]
                               [:put {:_id (random-uuid) :name "Matt"}]
                               [:put {:_id (random-uuid) :name "Dan"}]
                               [:put {:_id :bill, :name "Bill"}
                                {:_valid-time-start #inst "2016"
                                 :_valid-time-end #inst "2018"}]
                               [:put {:_id :jeff, :also_name "Ted"}
                                {:_valid-time-start #inst "2018"
                                 :_valid-time-end #inst "2020"}]
                               [:put {:_id :codd, :name "Edgar Codd"}
                                {:_valid-time-start #inst "2000"}]
                               [:put {:_id :codd, :name "Edgar F. Codd"}
                                {:_valid-time-start #inst "3000"}]
                               [:put {:_id :mccarthy, :name "John McCarthy"}
                                {:_valid-time-start #inst "4000"
                                 :_valid-time-end #inst "4001"}]])]
    (println "Sample transaction sent:\n\n" (deref tx))))

(defn run [opts]
  (println "XTDB started.")
  (add-sample-txs)
  (read-line))

(run {})
