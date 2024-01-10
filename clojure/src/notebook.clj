;; # XTDB ‘Core2’ + HoneySQL experiments

;; Welcome! [Core2](https://github.com/xtdb/core2) is an experimental SQL-first database prototype from the [XTDB](https://xtdb.com/) team. This namespace is a [Clerk](https://github.com/nextjournal/clerk) "notebook" showcasing the existing functionality in Core2 in combination with a few other tools within the Clojure ecosystem.

;; Please read the instructions carefully before evaluating anything, and in particular, *do not* immediately eval this entire namespace 🙂

^{:nextjournal.clerk/visibility {:code :fold :result :hide}}
(ns notebook
  {:nextjournal.clerk/toc true
   :nextjournal.clerk/open-graph
   {:url "https://github.com/xtdb/core2-playground"
    :title "XTDB Core2 + HoneySQL experiments"
    :description "XTDB Core2 + HoneySQL experiments (powered by Clerk)"
    :image "https://cdn.nextjournal.com/data/QmbHy6nYRgveyxTvKDJvyy2VF9teeXYkAXXDbgbKZK6YRC?filename=book-of-clerk-og-image.png&content-type=image/png"}}
  (:require [clojure.string :as str]
            [clojure.pprint :as pprint]
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
            [nextjournal.clerk :as clerk]
            [jsonista.core :as json]
            [honey.sql :as sql]
            [honey.sql.helpers :as hsql]
            [portal.api :as p]
            [clj-test-containers.core :as tc])
  (:import (java.sql Connection PreparedStatement)
           (org.postgresql.util PGobject)
           (java.net URLEncoder)))

;; ## Powered by Clerk ⚡

;; [Clerk](https://github.com/nextjournal/clerk) is a live-programming Clojure notebook experience that makes building interactive tutorials like this one _easy_, and running through them _fun_! Even if "running through" is read-only for now 😅 Kudos to the team behind Clerk for doing a really great job 🙏

;; If you are viewing a static HTML version of this notebook then feel free to skip the next couple of sections as all the examples should be fully rendered & ready for passive consumption! Otherwise, let's continue...

;; ## Booting up & REPL usage

;; Before we start, let's assume you have no other Core2-related REPL open or Docker image running. Equally let's assume that you have no local Postgres instance running on port `5432` that might conflict.

;; 1. Start a REPL using the instructions in `clojure/readme.md` and connect to it from your editor

;; 2. Evaluate the above ns definition in isolation first - do not eval the whole namespace!

;; 3. Once that ns eval has returned, eval the initializing `do` block inside the first `comment` below (this will take some time) and then open your browser at `http://localhost:7777`.

^{::clerk/visibility {:code :hide :result :hide}}
(defn show-raw-value [x]
  (clerk/code (with-out-str (pprint/pprint x))))

^{::clerk/visibility {:code :fold :result :hide}}
(do
  (comment ;; initializing `do` block (this will take some time)
    (do
      (clerk/clear-cache!)

      (clerk/serve! {;;:watch-paths ["src"]
                     :browse? false}) ;; http://localhost:7777
      (clerk/show! "src/notebook.clj"))
    )

  (declare my-node) ;; by default, an ephemeral Core2 node will be started up by Clerk automatically when the `serve!` command runs (after also clearing the Clerk cache)

  (comment ;; a handy reset `do` block in case the state gets confusing
    (do
      (when (not= (type my-node) clojure.lang.Var$Unbound)
        (.close my-node))
      (clerk/halt!)
      (clerk/clear-cache!)
      (clerk/serve! {;;:watch-paths ["src"]
                     :browse? false}) ;; http://localhost:7777 - remember to refresh the webpage!
      (clerk/show! "src/notebook.clj"))
    ))

;; If all is well (we'll confirm that soon enough) then Clerk will have already evaluated the rest of the namespace on your behalf, which includes starting up an ephemeral Core2 node (as we'll see below shortly). This means you don't need to eval any of the side-effecting forms hereafter and can focus on understanding the read-only query interactions.

;; Unfortunately it is not recommended to use Clerk's file watcher or interactive `show!` facilities with this notebook at this time due to the caching and side-effect complexities. Instead you can use the REPL as normal or to see the changes in Clerk you can use the reset `do` block above (which is a little too slow to feel interactive).

;; ## `next.jdbc` boilerplate

;; Next we'll need some boilerplate for round-tripping JSON values via [`next.jdbc`](https://github.com/seancorfield/next-jdbc) and the out-of-the-box Postgres JDBC driver.
;; These protocol extensions avoid the hassles of dealing with `PGobject` types directly via interop.

^{::clerk/visibility {:code :fold :result :hide}}
(do
  (def mapper (json/object-mapper {:decode-key-fn keyword}))

  (defn ->json [v]
    (let [s (json/write-value-as-string v)]
      (if (inst? v)
        ;;(str "DATE " (subs s 0 11) "\"")
        (str "TIMESTAMP " (subs s 0 11) " " (subs s 12 20) "\"")
        s)))

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
      (<-pgobject v))))

;; ## Start a Core2 node

;; Before continuing, know that three options exist for starting Core2 in this context:
;; - You can start an in-process node that exposes port `5432` - whilst this is convenient, Core2 is not ultimately intended for in-process usage
;; - You can start an `xtdb/core2` Docker container (default pgwire port is `5432`), e.g. using `docker pull xtdb/core2:latest && docker run -p 5432:5432 xtdb/core2:latest`
;; - You can start an `xtdb/core2` Docker container using Java Testcontainers that _feels_ like it's in-process (just not quite as snappy!)

;; For the purposes of this tutorial though we are starting up an ephemeral (i.e. data is not persisted across restarts) Core2 node using Java Testcontainers, and by the time you are reading this your node should have already started.

^{:nextjournal.clerk/visibility {:code :fold :result :hide}}
(do
  (declare container)
  (declare jdbc-config-str)

  (defn stop-container! []
    (when (not= (type container) clojure.lang.Var$Unbound)
      (tc/stop! container)))

  (deftype MyContainer []
    java.io.Closeable
    (close [this] (stop-container!)))

  (defn start-container! []
    (stop-container!)
    (def container (-> (tc/create {:image-name    "xtdb/core2:eb3325d8"
                                   :exposed-ports [5432]
                                   :env-vars      {}})
                       #_(tc/bind-filesystem! {:host-path      "/tmp"
                                               :container-path "/opt"
                                               :mode           :read-only})
                       (tc/start!)))
    (def jdbc-config-str (str "jdbc:postgresql://localhost:" (get (:mapped-ports container) 5432) "/xtdb/"))
    (->MyContainer))

  (defn jdbc-conn ^Connection [& params]
    (jdbc/get-connection jdbc-config-str))

  (when (not= (type my-node) clojure.lang.Var$Unbound)
    (.close my-node))

  (def my-node (start-container!))

  ;; If you would prefer to connect to your own Docker container then you can comment out this entire `do` block and restart your REPL. You will probably want to restart the Docker container each time prior to evaluating the handy reset `do` block mentioned above.

  ;; (def my-node (node/start-node {:core2/pgwire {:port 5432}})) ;; use this for in-process

  ;; Assuming a node is now running, this `next.jdbc` snippet should be able to produce connections to it:
  #_(defn jdbc-conn ^Connection [& params]
    (jdbc/get-connection (str "jdbc:postgresql://localhost:"
                              (or (:port params) 5432)
                              "/xtdb/")))
  )

;; Let's give it a spin:
(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["INSERT INTO my_table (id, val) Values (123, 'foo'), ('bar', 456)"])
  (jdbc/execute! my-conn ["SELECT my_table.id, my_table.val FROM my_table"]))

;; ...did it return `[{:id 123 :val "foo"} {:id "bar" :val 456}]` ? Hopefully! If you are seeing multiple such entries then you are likely witnessing the effect of repeated evaluations of the above combined with Core2's default application-time visibility (across all versions). This isn't a problem, although you may wish to restart your node to reset the database state as the notebook has gotten out of sync.

;; ## Core2 101

;; Despite using the Postgres wire protocol ('pgwire') exclusively in this tutorial (for now...[FlightSQL is coming soon](https://arrow.apache.org/blog/2022/02/16/introducing-arrow-flight-sql/)!), Core2 is very different to Postgres and is not seeking to be directly compatible with it. Instead Core2 implements a novel SQL dialect based primarily on the published standards but with some carefully chosen additions, with the main objective of bringing the key principles embodied in XTDB 1.x — immutability, schemaless records, and temporal querying — to a mainstream SQL audience.

;; Let's review the things that make Core2 relatively unique in the world of SQL:

;; ### Instant Schemaless Writes

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["INSERT INTO posts (id, user_id, text)
                             VALUES (1234, 5678, 'Hello World!')"])
  (jdbc/execute! my-conn ["SELECT posts.text FROM posts"]))

;; Core2 does not require any pre-defined schema or tables. Yet at the same time every insert, update, and delete is immutable, as we'll see shortly.

;; ### First-Class Arrays and Objects

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["INSERT INTO people (id, name, friends)
                             VALUES (5678, 'Sarah',
                                     [{'user': 'Dan'},
                                      {'user': 'Kath'}])"])
  (jdbc/execute! my-conn ["SELECT people.friends[2] AS friend FROM people"]))

;; Nested data is handled natively. Objects are not opaque or reduced to a subset of types (i.e. unlike Postgres' JSONB). Instead nested data is seamlessly integrated with SQL using a familiar feeling syntax.

;; ### Enhanced SQL:2011

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["INSERT INTO posts (id, user_id, text)
                             VALUES (1234, 5678, 'Hello Bitemporality!')"])
  (jdbc/execute! my-conn ["SELECT posts.text FROM posts"]))

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["SET APPLICATION_TIME_DEFAULTS TO AS_OF_NOW"])
  (jdbc/execute! my-conn ["SELECT posts.text FROM posts"]))

;; Core2 defaults to the SQL:2011 standard behaviours for inserting and querying "across all time", but it also offers optional defaults for a more intuitive experience.

;; ### Cross-Time Queries

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["SET APPLICATION_TIME_DEFAULTS TO AS_OF_NOW"])
  (jdbc/execute! my-conn ["INSERT INTO posts (id, user_id, text, application_time_start)
                             VALUES (9012, 5678, 'Happy 2025!', DATE '2025-01-01')"])
  (jdbc/execute! my-conn ["SELECT posts.text FROM posts"]) ;; returns just 1 entry as-of 'now'
  (jdbc/execute! my-conn ["SELECT posts.text FROM posts
                             FOR APPLICATION_TIME AS OF DATE '2025-01-02'"])) ;; returns the future entry also

;; Thinking about time in Core2 is optional – but rest assured that it is universal. Advanced applications can even query time itself.

;; ### Native Apache Arrow

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["SELECT more_posts.text
                             FROM ARROW_TABLE('https://xtdb.com/more_posts.arrow')
                             AS more_posts"]))

;; Core2 speaks [Apache Arrow](https://arrow.apache.org/) as readily as it speaks SQL. The internal architecture also uses Apache Arrow extensively to unlock possibilities for future development and high-performance integration.

;; ### Complete Erasure

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["ERASE FROM people WHERE people.id=5678"])
  (jdbc/execute! my-conn ["SELECT people.id FROM people"]))

;; To comply with privacy laws, erasure is necessary when handling otherwise immutable data.

;; ## Behaviours to be aware of

;; In addition to some [preliminary documentation](https://core2docs.xtdb.com/), which is worth a quick look, there are some caveats about Core2's current behaviour worth mentioning here:
;; - all data is returned as JSON by the pgwire driver, regardless of the native storage types being used internally (e.g. you can insert a DATE but will be returned as an ISO string)
;; - INSERTs cannot return any data, including counts of modified rows
;; - all columns must be fully-qualified in queries
;; - there is no user-facing information schema, and `SELECT *` will only return columns referenced in a query
;; - rows will be filtered out where a column is SELECTed and the given row has no value stored for the column
;; - duplicate column names across separate tables do not work, see https://github.com/xtdb/core2/issues/535

;; ## HoneySQL 101

;; As per the description in HoneySQL's [readme](https://github.com/seancorfield/honeysql), HoneySQL is: "SQL as Clojure data structures. Build queries programmatically -- even at runtime -- without having to bash strings together."

;; To familiarise yourself with HoneySQL it is worth giving that readme a skim now and keep the documentation open as you continue working through this namespace.

;; Adapting our example:
(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn (sql/format {:select [:my-table.id
                                               :my-table.val]
                                      :from :my-table})))

;; You can also preview the SQL by calling `sql/format` in isolation:
(sql/format {:select [:my-table.id
                      :my-table.val]
             :from :my-table}
            {:pretty true})

;; We can create a couple of helper functions to improve the interactive experience as we embark on our HoneySQL adventure:
(def f sql/format) ;; f for f-ormat

(defn q [m & [c]] ;; q for q-uery
  ^::clerk/no-cache
  (let [_exec-count c]
    (with-open [my-conn (jdbc-conn)]
      (jdbc/execute! my-conn ["SET APPLICATION_TIME_DEFAULTS TO AS_OF_NOW"]) ;; let's always use this from now on
      (jdbc/execute! my-conn (sql/format m)))))

;; Much easier on the eyes:

(q {:select [:my-table.id
             :my-table.val]
    :from :my-table
    :where [:= :my-table.val 456]})

;; ### Temporary `next.jdbc` boilerplate

;; `next.jdbc` also offers higher-level functions for inserting and retrieving data. To cope with Core2's current limitations however we will use a slightly modified version of HoneySQL's `insert!` which sidesteps parameter typing issues (and similarly when attempting to use `:insert-into`).

^{:nextjournal.clerk/visibility {:code :fold :result :hide}}
(do
  (defn single-quotify [s]
    (str/replace s #"\"" "'"))

  (defn for-insert*
    "don't use prepared parameters to avoid type handling, skip table `safe-name` check (it's a private fn)"
    [table key-map opts]
    (let [entity-fn (:table-fn opts identity)
          params    (bsql/as-keys key-map opts)]
      (assert (seq key-map) "key-map may not be empty")
      (into [(str "INSERT INTO " (entity-fn (name table))
                  " (" params ")"
                  " VALUES (" (single-quotify (str/join ", " (map ->json (vals key-map)))) ")"
                  (when-let [suffix (:suffix opts)]
                    (str " " suffix)))])))

  (defn insert!*
    "overriding for-insert"
    ([connectable table key-map]
     (insert!* connectable table key-map {}))
    ([connectable table key-map opts]
     (let [opts (merge (:options connectable) opts)]
       (prn (for-insert* table key-map opts))
       (jdbc/execute-one! connectable
                          (for-insert* table key-map opts)
                          (merge {:return-keys false} opts)))))

  (defn insert! [table key-map]
    (with-open [my-conn (jdbc-conn)]
      (insert!* my-conn table key-map jdbc/snake-kebab-opts))))

;; ## SQL:2011 / `snodgrass-99`

;; One of the big motivations behind Core2 is the desire to offer the full suite of temporal functionality seen in the [SQL:2011](https://en.wikipedia.org/wiki/SQL:2011) revision of the SQL standard.
;; To illustrate the purpose of bitemporal modelling and the usage of the SQL:2011 functionality, the following examples have been adapted from `bitemporal/snodgrass.sql` (which is a more extensive resource located in this same `core2-playground` repository).

;; - Derived from "Developing Time-Oriented Database Applications in SQL" by Richard T. Snodgrass.
;; - A digital copy of the book is available freely online from the author @ https://www2.cs.arizona.edu/~rts/tdbbook.pdf
;; - This tutorial is based on the examples in Chapter 10 (p301 of the pdf)
;; - Various excerpts have been adapted and included below. However, the source material (the book) is worth heavily referring to for the complete context, and to compare the differences side-by-side between the SQL-92 examples and Core2's SQL:2011 implementation.
;; - Use of the [Bitemporal Visualizer](https://bitemporal-visualizer.github.io/) is recommended.

;; ### Background (excerpt)

;; Information is the key asset of many companies. Nykredit, a major Danish mortgage bank, is a good example. In 1989, the Danish legislature changed the Mortgage Credit Act to allow mortgage providers to market loans directly to customers and through real estate agents

;; One of the challenges was achieving high data quality on the customers and their loans, while expanding the traditional focus to also include customer support. Managers needed access to up-to-date data to set benchmarks an identify problems in various areas of the business. The sheer volume of the data, nine million loans to eight million customers concerning seven million properties, demands that eliminating errors in the data must be highly efficient.

;; It was mandated that changes to critical tables be tracked. This implies that the tables have system-time support. As these tables also model changes in reality, they require application-time support. The result is termed a bitemporal table, reflecting these two aspects of underlying temporal support. With such tables, IT personnel can first determine when the erroneous data was stored (a system time), roll back the table to that point, and look at the application-time history. They can then determine what the correct application-time history should be. At that point, they can tell the customer service person what needs to be changed, or if the error was in the processing of a user transaction, they may update the database manually.

;; ### [10.2] MODIFICATIONS

;; Let's follow the history, over both application time and system time, of a flat in Aalborg, at Skovvej 30 for the month of January 1998.

;; Starting with Current Modifications (Inserts, Updates, Deletes)

;; For Core2 an explicit ID is needed, let's not complicate everything with UUIDs for now and assume we are talking about flat '1'...

;; #### [MOD1] Eva Nielsen buys the flat at Skovvej 30 in Aalborg on January 10, 1998.
(insert! :prop-owner {:id 1
                      :customer-number 145
                      :property-number 7797
                      :application-time-start #inst "1998-01-10"})

;; Here we have but one region, associated with Eva Nielsen, that starts today in system time and extends to until changed, and that begins also at time 10 in application time and extends to forever.
(q {:select [:x.id
             :x.customer-number
             :x.application-time-start
             :x.application-time-end
             :x.system-time-start
             :x.system-time-end]
    :from [[:prop-owner :x]]
    :where [[:= :x.id 1]]})

;; To avoid repetition, let's factor out the time columns and use short aliases:
(def time-cols [[:x.application-time-start :app-start]
                [:x.application-time-end :app-end]
                [:x.system-time-start :sys-start]
                [:x.system-time-end :sys-end]])

^{::clerk/viewer show-raw-value} ;; Clerk allows you define custom viewers to pretty-print the raw edn too
(q {:select (into [:x.customer-number]
                  time-cols)
    :from [[:prop-owner :x]]
    :where [[:= :x.id 1]]})

;; Let's print the output in a string format suitable for copying across to the [Bitemporal Visualizer](https://bitemporal-visualizer.github.io/):
(clerk/html [:pre (-> (q {:select (into [:x.id
                                         :x.customer-number]
                                        time-cols)
                          :from [[:prop-owner :x]]})
                      pprint/print-table
                      with-out-str
                      (subs 1))])

;; This calls for another notebook helper function to avoid repetition:
(defn t [m & [c]] ;; t for t-able
  ^::clerk/no-cache
  (clerk/html [:pre (-> (q m c)
                        pprint/print-table
                        with-out-str
                        (#(if (= (count %) 0) " " %))
                        (subs 1))]))

;; And while we're at it we can pipe that table into a hyperlink that directly opens the Visualizer in a new tab and displays the data:
(defn link [m & [c]]
  ^::clerk/no-cache
  (str "https://bitemporal-visualizer.github.io/?t="
       (-> (q m c)
           pprint/print-table
           with-out-str
           (#(if (= (count %) 0) " " %))
           (subs 1)
           (URLEncoder/encode "UTF-8"))))

(defn l [m & [c]] ;; l for l-ink
  ^::clerk/no-cache
  (clerk/html [:a {:href (link m c)
                   :target "_blank"} "[Open the Visualizer]"]))

;; For example...
(l {:select (into [:x.customer-number]
                  time-cols)
    :from [[:prop-owner :x]]
    :where [[:= :x.id 1]]}
   1)

;; Note the use of the added `exec-count` parameter getting passed through here, we'll use this (e.g. manually increment) to avoid picking up Clerk's cached evaluations from previous executions of any given query.

;; Use the visualization tool liberally from now on to help reason about the history and compare against the diagrams seen in the book. With only one entry here for the moment though the visualization is just a big boring black rectangle.

;; #### [MOD2] Peter Olsen buys the flat; this legal system transfers ownership from Eva to him
(insert! :prop-owner {:id 1
                      :customer-number 827
                      :property-number 7797
                      :application-time-start #inst "1998-01-15"})

;; Observe the change in ownership as-of 'now' along with the new application-time-start:
(t {:select (into [:x.customer-number]
                  time-cols)
    :from [[:prop-owner :x]]
    :where [[:= :x.id 1]]}
   1)

;; To see the _full_ history with our Core2-specific application_time_defaults with vanilla HoneySQL we can do it like this:
(t {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       " FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME")] :x]]
    :where [[:= :x.id 1]]}
   2)

;; Note there a 3 entries. This is because the original validity region needed "splitting" into two parts, so that the later part could be overridden by the new value. Try changing the `t` to `l` to visualize this result.

;; Ultimately it will be great for HoneySQL to offer first-class support in `:from` for the SQL:2011 table period specifications rather than using `:raw` (which is a powerful escape hatch).

;; #### [MOD3] We perform a current deletion when we find out that Peter has sold the property to someone else

;; The buyer has the mortgage handled by another mortgage company. From the bank's point of view, the property no longer exists as of(an application time of) now.
(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["SET APPLICATION_TIME_DEFAULTS TO AS_OF_NOW"])
  (jdbc/execute! my-conn ["
DELETE
FROM prop_owner
FOR PORTION OF APPLICATION_TIME FROM DATE '1998-01-20' TO END_OF_TIME
WHERE prop_owner.property_number = 7797"]))

;; Note that using `next.jdbc`'s `delete!` (instead of this string DML) will require similar shenanigans like `insert!` above. (TODO)

;; See that the current view is deleted with the following returning 0 rows:
(q {:select (into [:x.customer-number]
                  time-cols)
    :from [[:prop-owner :x]]
    :where [[:= :x.id 1]]}
   3)

;; If we now request the application-time history as best known, we will learn that Eva owned the at from January 10 to January 15, and Peter owned the at from January 15 to January 20. Note that all prior states are retained. We can still time-travel back to January 18 and request the application-time history, which will state that on that day we thought that Peter still owned the at.

(l {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       "  FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME")] :x]]
    :where [[:= :x.id 1]]}
   4)

;; When visualized, the current deletion has "chopped off" the top-right corner, so that the region is now L-shaped.

;; #### [MOD4] A sequenced insertion performed on January 23: Eva actually purchased the flat on January 3.

;; Now we are looking at [10.2.2] Sequenced Modifications within the book. For bitemporal tables, the modication is sequenced only on application time; the modication is always a current modification on system time, from now to until changed.

(insert! :prop-owner {:id 1
                      :customer-number 145
                      :property-number 7797
                      :application-time-start #inst "1998-01-03"
                      :application-time-end #inst "1998-01-10"})

;; Look again
(l {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       "  FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME")] :x]]
    :where [[:= :x.id 1]]}
   5)

;; This insertion is termed a retroactive modification, as the period of applicability is before the modification date Sequenced (and nonsequenced) modifications can also be postactive, an example being a promotion that will occur in the future (in application time).

;; (An application-end time of "forever" is generally not considered a postactive modification; only the application-start time is considered.)

;; A sequenced modification might even be simultaneously retroactive, postactive, and current, when its period of applicability starts in the past and extends into the future (e.g., a fixed-term assignment that started in the past and ends at a designated date in the future)

;; #### [MOD5] We learn now 26 that Eva bought the flat not on January 10...

;; ...as initially thought, nor on January 3, as later corrected, but on January 5. This requires a sequenced version of the following deletion:

(with-open [my-conn (jdbc-conn)]
  (jdbc/execute! my-conn ["SET APPLICATION_TIME_DEFAULTS TO AS_OF_NOW"])
  (jdbc/execute! my-conn ["
DELETE
FROM prop_owner
FOR PORTION OF APPLICATION_TIME
FROM DATE '1998-01-03' TO DATE '1998-01-05'"]))

;; Look again
(l {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       "  FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME")] :x]]
    :where [[:= :x.id 1]]}
   6)

;; [MOD6] We next learn that Peter bought the flat on January 12...
;; ...not January 15 as previously thought. This requires a sequenced version of the following update. This update requires a period of applicability of January 12 through 15, setting the customer number to 145. Effectively, the ownership must be transferred from Eva to Peter for those three days.
(insert! :prop-owner {:id 1
                      :customer-number 145
                      :property-number 7797
                      :application-time-start #inst "1998-01-05"
                      :application-time-end #inst "1998-01-12"})

(insert! :prop-owner {:id 1
                      :customer-number 827
                      :property-number 7797
                      :application-time-start #inst "1998-01-12"
                      :application-time-end #inst "1998-01-20"})

;; Look again
(l {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       "  FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME")] :x]]
    :where [[:= :x.id 1]]}
   7)


;; ### [10.3.1] Time-Slice Queries

;; A common query or view over the application-time state table is to capture the state of the enterprise at some point in the past (or future). This query is termed a application-time time-slice. For an auditable tracking log changes, we might seek to reconstruct the state of the monitored table as of a date in the past; this query is termed a system time-slice. As a bitemporal table captures application and system time, both time-slice variants are appropriate on such tables.

;; Time-slices are useful also in understanding the information content of a bitemporal table. A system time-slice of a bitemporal table takes as input a system-time instant and results in a application-time state table that was present in the database at that specified time.

;; A system time-slice query corresponds to a vertical slice in the time diagram.

;; An application time-slice query corresponds to a horizontal slice as input application-time instant and results in a system-time in the time diagram.

;; A bitemporal time-slice query extracts a single point from a time diagram, resulting in a snapshot table. A bitemporal time-slice takes as input two instants, a application-time and a system-time instant, and results in a snapshot state of the information regarding the enterprise at that application time, as recorded in the database at that system time. The result is the facts located at the intersection of the two lines, in this case, Eva.

;; Give the owner of the flat at Skovvej 30 in Aalborg on January 13 as stored in the Prop Owner table on January 18.
(q {:select (into [:x.customer-number]
                  time-cols)
    :from [[[:raw (str (sql/format-entity :prop-owner)
                       "  FOR SYSTEM_TIME AS OF DATE '2099-01-01' FOR APPLICATION_TIME AS OF DATE '1998-01-13'")] :x]]
    :where [[:= :x.id 1]]}
   8)

;; ### And so on...

;; Feel free to study and adapt the examples in snodgrass-99.sql as desired!

;; ## Advanced HoneySQL and Beyond

;; ... [WIP]

;; ### Attempting to work around the (temporary) lack of an information schema...

(defn map-vals [f m] (reduce-kv (fn [m k v] (assoc m k (f v))) {} m))

(defn insert!**
  "overriding for-insert"
  ([connectable table key-map]
   (insert!* connectable table key-map {}))
  ([connectable table key-map opts]
   (let [opts (merge (:options connectable) opts)
         key-map (assoc key-map :cols (str/join " " (map #(subs (str %) 1) (keys key-map))))]
     (prn (for-insert* table key-map opts))
     (jdbc/execute-one! connectable
                        (for-insert* table key-map opts)
                        (merge {:return-keys false} opts)))))

(defn select-star-for-id [conn table id] ;; TODO use table
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
  ;; remember: only JSON-shaped types can be round-tripped via pgwire (currently)!
  ;; we don't use `(with-meta m {:pgtype "json"})` as XT doesn't process actual JSON
  ;; DATEs (etc.) will be returned as ISO strings
  ;; don't use arrays yet (due to bugs), objects may also be buggy and cannot be compared
  ;; work with whole values only (don't attempt nested lookups, for now)
  ;; JSON string keys are returned as keywords
  ;; use snake_case for persistence interop (TODO reconfigure to use jdbc/snake-kebab-opts)
  ;; but consider next.jdbc builders: as-kebab-maps and as-unqualified-kebab-maps (see https://clojurians.slack.com/archives/C1Q164V29/p1662995380957559)
  (with-open [conn (jdbc-conn)]
    (jdbc/execute-one! conn [ "SET application_time_defaults TO as_of_now;"])
    (let [m1 {:id 1234 :name 4579999 :foo "asdf" :arr [9 1 [2 [1 3]]] :obj {:a {:b {:c 1 :d "asdf"} :e {:f 789 :g {:h 123}}}} :my_json3 {:a_f {:b "c"}} :my_date #inst "1990-01-01"}]
      (insert!** conn :a m1)
      (let [e (select-star-for-id conn :a (:id m1))]
        [(= e m1) e])))

  (with-open [conn (jdbc-conn)]
    (jdbc/execute! conn [ "SELECT x.my_json3 FROM a AS x (id, my_json3);"]))

  (with-open [conn (jdbc-conn)]
    (jdbc/execute! conn (sql/format {:select :a.id
                                     :from :a
                                     :where [:= :a.obj
                                             [:raw (-> {:c 1 :d "asdf"}
                                                       ->json
                                                       single-quotify)]]})))

  )

;; ### HoneySQL Period Extensions

(comment
  (def overlaps "APP_TIME OVERLAPS" :overlaps)

  (sql/register-op! overlaps)

  (sql/clause-order)

  (sql/format {:select [:foo.name :bar.also_name]
               :from [[[:raw "foo FOR ALL APPLICATION_TIME"] :x] :bar]
               :join-by [:left [[:baz]
                                [:using :id]]]
               :where [:overlaps :foo.APP_TIME :bar.APP_TIME]
               })

  ;; interesting: https://github.com/strojure/parsesso/blob/default/test/demo/honeysql_select.clj

  )


;; ## Static Build

;; 1. Clear the cache (clerk/clear-cache!) (or `rm .clerk/cache/*` / delete the `.clerk` directory)
;; 2. `clj -X:nextjournal/clerk` (and be sure to not save this namespace in parallel / trigger cache changes)
;; 3. Browse at `public/build/src/notebook.html`

;; Hopefully this can be published on https://github.clerk.garden/ soon!
