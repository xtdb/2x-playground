(ns xtexample
  (:require [core2.api :as c2]
            [core2.local-node :as local-node]
            [core2.sql.pgwire :as pgwire]))

(def node (local-node/start-node {}))
(def server (pgwire/serve node))

(def data-simple [[:put {:_id (random-uuid) :name "James"}]
                  [:put {:_id (random-uuid) :name "Matt"}]
                  [:put {:_id (random-uuid) :name "Dan"}]
                  [:put {:_id (random-uuid)
                         :name "Steven"
                         :age 40}]
                  [:put {:_id (random-uuid)
                         :name "Jeremy"
                         :age 32}]
                  [:put {:_id (random-uuid)
                         :name "Matt"
                         :age 31}]
                  [:put {:_id (random-uuid)
                         :name "Dan"
                         :age 35}]])

(def data-nested [[:put {:_id (random-uuid)
                         :trade_date (.toString (java.time.Instant/parse "2022-06-24T12:34:56.000000Z"))
                         :trade_user "Jon"
                         :bird    {:iam "jon's map"
                                   :with 1234.5432}
                         :exchange   "juxt"}]
                  [:put {:_id (random-uuid)
                         :trade_date (.toString (java.time.Instant/now))
                         :matt_nums  [1, 2, 3, 4]
                         :bird    {:iam "mat's map"
                                   :with 1234.5432}
                         :trade_user "Matt"
                         :exchange   "juxt"}]
                  [:put {:_id (random-uuid)
                         :trade_date (.toString (java.time.Instant/now))
                         :dan_map    {:iam "a map"
                                      :with 1234.5432}
                         :trade_user "Dan"
                         :exchange   "juxt"}]])

(def data-temporal-app [[:put {:_id :bill, :name "Bill"}
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
                          :_valid-time-end #inst "4001"}]])

;; TODO: remove this when we have basic DML and run a batch insert instead
(defn add-sample-txs []
  (let [tx (c2/submit-tx node (vec (concat data-simple data-nested data-temporal-app)))]
    (println "Sample transaction sent:\n\n" (deref tx))))

(defn run [opts]
  (println "XTDB started.")
  (add-sample-txs)
  (read-line))

(run {})
