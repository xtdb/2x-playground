(require '[clojure.java.io :as io])
(require '[clojure.string :as str])

(defn id-string-to-string-id [s]
  (->> (str/split s #"'")
       (remove #(= % ""))
       first))

;; a table-prefix is required until _table id partitioning is implemented
(defn prepend-composite-string-pk-2 [table-prefix s]
  (let [[id1s id2s & r] (str/split s #",") ;; assume first two ids don't contain ','
        id1s (subs id1s 1) ;; assume the line starts with '('
        id1 (id-string-to-string-id id1s)
        id2 (id-string-to-string-id id2s)]
    (str "('" table-prefix "___" id1 "___" id2 "'," id1s "," id2s "," (str/join "," r))))

(def startl "set transaction read write; begin;")
(def endl "commit;")
(def batch-size 500)

(with-open [w (io/writer  "sakila-final.sql" :append true)]
  (with-open [rdr (io/reader "sakila-tmp.sql")]
    (loop [[batch [l & r]] [batch-size (line-seq rdr)]]
      (let [start (= batch batch-size)
            end (= batch 0)
            batch (if (= batch 0) (inc batch-size) batch)
            startl (if start startl "")
            endl (if end endl "")]
        (when (some? l)
          (recur (cond (str/starts-with? l "Insert into film_actor")
                       (let [[l2 l3 l4 l5 & r] r]
                         (.write w (str/join "\n" [startl l l2 l3 (prepend-composite-string-pk-2 "film_actor" l4) l5 endl ""]))
                         [(dec batch) r])

                       (str/starts-with? l "Insert into film_category")
                       (let [[l2 l3 l4 l5 & r] r]
                         (.write w (str/join "\n" [startl l l2 l3 (prepend-composite-string-pk-2 "film_category" l4) l5 endl ""]))
                         [(dec batch) r])

                       (str/starts-with? l "Insert into")
                       (let [[l2 l3 l4 l5 & r] r]
                         (.write w (str/join "\n" [startl l l2 l3 l4 l5 endl ""]))
                         [(dec batch) r])

                       :else
                       (do (.write w (str l "\n"))
                           [batch r]))))))
    (.write w endl)))
