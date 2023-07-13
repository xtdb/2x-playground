;; Copyright © 2023, JUXT LTD.

(ns v2-landing.embedded
  (:require
   [xtdb.node :as xt.node]
   [xtdb.api :as xt]))

(def xt-node (xt.node/start-node {:xtdb/server {:port 3001}
                                  :xtdb/pgwire {:port 5432}}))


(xt/status xt-node)

(xt/submit-tx xt-node [[:put :posts {:xt/id 1234
                                     :user-id 5678
                                     :text "hello world!"}]])

(xt/q xt-node '{:find [text]
                :where [($ :posts [text])]})

;; XTDB has always handled ~arbitrary data well - just put your maps in!
(xt/submit-tx xt-node [[:put :people {:xt/id 5678
                                      :name "Sarah"
                                      :friends [{:user "Dan"}
                                                {:user "Kath"}]}]])

;; XTDBv2 Datalog supports first-class nested lookups too:
(xt/q xt-node '{:find [dan-name]
                :where [($ :people [friends])
                        ;; We can use 'nth', which is part of XT's
                        ;; expression engine
                        [(nth friends 0) first-friend]
                        ;; We can pull out the :user field with '.'
                        [(. first-friend :user) dan-name]]})

;; Datalog uses as-of-now defaults
;; To view the entire history of a record:
(xt/q xt-node '{:find [person
                       valid-from valid-to
                       system-from system-to]
                :where [($ :people [{:xt/id 5678
                                     :xt/* person
                                     :xt/valid-from valid-from
                                     :xt/valid-to valid-to
                                     :xt/system-from system-from
                                     :xt/system-to system-to}]
                           {:for-valid-time :all-time
                            :for-system-time :all-time})]})

(xt/submit-tx xt-node [[:evict :people 5678]])
