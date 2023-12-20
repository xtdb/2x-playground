;; # Learn XTQL Today, with Clojure

;; Welcome! This is a [Clerk](https://github.com/nextjournal/clerk) "notebook" written for [Clojure](https://clojure.org) users as a showcase of XTDB's developer-friendly query language: XTQL.

;; XTQL is designed to be language agnostic and supports a first-class JSON representation for use with a wide variety of client libraries (coming soon!). However, for this tutorial we are focused on the Clojure client library experience.

;; Learn XTQL Today is derived from the classic [learndatalogtoday.org](http://learndatalogtoday.org) tutorial. This interactive tutorial designed to teach you XTQL. XTQL is a declarative database query language with roots in logic programming and SQL. XTQL has equivalent expressive power to SQL and relies on the SQL standard library to ensure full interoperability between the two languages.

;; The JSON version of XTQL is essentially a more verbose translation of the [edn](https://github.com/edn-format/edn)-based representation seen below.

;; Please read the instructions carefully before evaluating anything, and in particular, *do not* immediately eval this entire namespace 🙂

^{:nextjournal.clerk/visibility {:code :hide :result :hide}}
(ns learn-xtql-today-with-clojure
  {:nextjournal.clerk/toc :collapsed
   :nextjournal.clerk/open-graph
   {:url "https://github.com/xtdb/2x-playground"
    :title "Learn XTQL Today, with Clojure"
    :description "An XTQL tutorial for Clojurists (powered by Clerk)"
    #_:image #_"https://cdn.nextjournal.com/data/QmbHy6nYRgveyxTvKDJvyy2VF9teeXYkAXXDbgbKZK6YRC?filename=book-of-clerk-og-image.png&content-type=image/png"}}
  (:require [xtdb.node :as xt.node]
            [xtdb.api :as xt]
            [nextjournal.clerk :as clerk]))

;; ## Powered by Clerk ⚡

;; [Clerk](https://github.com/nextjournal/clerk) is a live-programming Clojure notebook experience that makes building interactive tutorials like this one _easy_, and running through them _fun_!

;; If you are viewing a static HTML version of this notebook then feel free to skip the next couple of sections as all the examples should be fully rendered & ready for passive consumption! Otherwise, let's continue...

;; ## Booting up & REPL usage

;; Before we start, let's assume you have no other XTDB-related REPL open or Docker image running. Equally let's assume that you have no other local software running on port `3000` that might conflict.

;; 1. Start a REPL using the instructions in `clojure/readme.md` and connect to it from your editor

;; 2. Evaluate the ns definition in isolation first - do not eval the whole namespace!

;; 3. Once that has ns eval has returned successfully, eval the initializing `do` block inside the first `comment` below (this will take some time) and then open your browser at [`https://localhost:7777`](http://localhost:7777)

^{::clerk/visibility {:code :hide :result :hide}}
(do
  (comment ;; initializing `do` block (this will take some time)
    (do
      (clerk/clear-cache!)

      (clerk/serve! {:watch-paths ["src"]
                     :browse? false}) ;; http://localhost:7777
      (clerk/show! "src/learn-xtql-today-with-clojure.clj"))

    )

  (declare my-node) ;; by default, an ephemeral XTDB node will be started up by Clerk automatically when the `serve!` command runs (after also clearing the Clerk cache)

  (comment ;; a handy reset `do` block in case the state gets confusing
    (do
      (when (not= (type my-node) clojure.lang.Var$Unbound)
        (.close my-node))
      (clerk/halt!)
      (clerk/clear-cache!)
      (clerk/serve! {:watch-paths ["src"]
                     :browse? false}) ;; http://localhost:7777 - remember to refresh the webpage!
      (clerk/show! "src/learn-xtql-today-with-clojure.clj"))
    ))

;; If all is well (we'll confirm that soon enough) then Clerk will have already evaluated the rest of the namespace on your behalf, which includes starting up an ephemeral XTDB server container (as we'll see below shortly). This means you don't need to eval any of the side-effecting forms hereafter and can focus on understanding the read-only query interactions.

;; ## Start an in-process, ephemeral XTDB server

;; We will run XTDB as an in-process server which is useful for writing tests and rapid experimentation. However, XTDB, in general, is intended to be run in production as an out-of-process server (like a regular database server/cluster) and therefore use of remote APIs is strongly recommended for the best experience.

;; For the purposes of this tutorial though we are starting up an ephemeral (i.e. data is not persisted across restarts) XTDB 'node', and by the time you are reading this your node should have already started.

;; First we must use `start-node` - no configuration is supplied so all data is in-memory and will be lost when the node is closed or the environment is shutdown.

^{::clerk/visibility {:result :hide}}
(def my-node (xt.node/start-node {}))

;; The XTDB instance, referred to by `my-node`, should now be active, which we can confirm using `status` which returns `{:latest-completed-tx nil :latest-submitted-tx nil}`

(xt/status my-node)

;; Next we need some data. XTDB interprets maps as both "documents" and "jagged rows" interchangeably. These maps work without a predefined schema - they only need a valid ID primary key. In the data below (which is defined using edn, and fully explained in the next section) we are using integers as IDs. We are also using nested vector values, meaning the schema is not properly normalized (in the regular SQL sense of "3NF") - but no problem - XTQL can handle this!

;; The following two vectors of maps contain two kinds of documents: documents relating to people (actors and directors) and documents relating to movies. As a convention to aid human interpretation, all persons have IDs like `1XX` and all movies have IDs like `2XX`. Many ID value types are supported, such as strings and UUIDs, which may be more appropriate in a real application.

^{::clerk/visibility {:code :fold :result :show}}
(def my-persons
  [{:person/name "James Cameron",
    :person/born #inst "1954-08-16T00:00:00.000-00:00",
    :xt/id 100}
   {:person/name "Arnold Schwarzenegger",
    :person/born #inst "1947-07-30T00:00:00.000-00:00",
    :xt/id 101}
   {:person/name "Linda Hamilton",
    :person/born #inst "1956-09-26T00:00:00.000-00:00",
    :xt/id 102}
   {:person/name "Michael Biehn",
    :person/born #inst "1956-07-31T00:00:00.000-00:00",
    :xt/id 103}
   {:person/name "Ted Kotcheff",
    :person/born #inst "1931-04-07T00:00:00.000-00:00",
    :xt/id 104}
   {:person/name "Sylvester Stallone",
    :person/born #inst "1946-07-06T00:00:00.000-00:00",
    :xt/id 105}
   {:person/name "Richard Crenna",
    :person/born #inst "1926-11-30T00:00:00.000-00:00",
    :person/death #inst "2003-01-17T00:00:00.000-00:00",
    :xt/id 106}
   {:person/name "Brian Dennehy",
    :person/born #inst "1938-07-09T00:00:00.000-00:00",
    :xt/id 107}
   {:person/name "John McTiernan",
    :person/born #inst "1951-01-08T00:00:00.000-00:00",
    :xt/id 108}
   {:person/name "Elpidia Carrillo",
    :person/born #inst "1961-08-16T00:00:00.000-00:00",
    :xt/id 109}
   {:person/name "Carl Weathers",
    :person/born #inst "1948-01-14T00:00:00.000-00:00",
    :xt/id 110}
   {:person/name "Richard Donner",
    :person/born #inst "1930-04-24T00:00:00.000-00:00",
    :xt/id 111}
   {:person/name "Mel Gibson",
    :person/born #inst "1956-01-03T00:00:00.000-00:00",
    :xt/id 112}
   {:person/name "Danny Glover",
    :person/born #inst "1946-07-22T00:00:00.000-00:00",
    :xt/id 113}
   {:person/name "Gary Busey",
    :person/born #inst "1944-07-29T00:00:00.000-00:00",
    :xt/id 114}
   {:person/name "Paul Verhoeven",
    :person/born #inst "1938-07-18T00:00:00.000-00:00",
    :xt/id 115}
   {:person/name "Peter Weller",
    :person/born #inst "1947-06-24T00:00:00.000-00:00",
    :xt/id 116}
   {:person/name "Nancy Allen",
    :person/born #inst "1950-06-24T00:00:00.000-00:00",
    :xt/id 117}
   {:person/name "Ronny Cox",
    :person/born #inst "1938-07-23T00:00:00.000-00:00",
    :xt/id 118}
   {:person/name "Mark L. Lester",
    :person/born #inst "1946-11-26T00:00:00.000-00:00",
    :xt/id 119}
   {:person/name "Rae Dawn Chong",
    :person/born #inst "1961-02-28T00:00:00.000-00:00",
    :xt/id 120}
   {:person/name "Alyssa Milano",
    :person/born #inst "1972-12-19T00:00:00.000-00:00",
    :xt/id 121}
   {:person/name "Bruce Willis",
    :person/born #inst "1955-03-19T00:00:00.000-00:00",
    :xt/id 122}
   {:person/name "Alan Rickman",
    :person/born #inst "1946-02-21T00:00:00.000-00:00",
    :xt/id 123}
   {:person/name "Alexander Godunov",
    :person/born #inst "1949-11-28T00:00:00.000-00:00",
    :person/death #inst "1995-05-18T00:00:00.000-00:00",
    :xt/id 124}
   {:person/name "Robert Patrick",
    :person/born #inst "1958-11-05T00:00:00.000-00:00",
    :xt/id 125}
   {:person/name "Edward Furlong",
    :person/born #inst "1977-08-02T00:00:00.000-00:00",
    :xt/id 126}
   {:person/name "Jonathan Mostow",
    :person/born #inst "1961-11-28T00:00:00.000-00:00",
    :xt/id 127}
   {:person/name "Nick Stahl",
    :person/born #inst "1979-12-05T00:00:00.000-00:00",
    :xt/id 128}
   {:person/name "Claire Danes",
    :person/born #inst "1979-04-12T00:00:00.000-00:00",
    :xt/id 129}
   {:person/name "George P. Cosmatos",
    :person/born #inst "1941-01-04T00:00:00.000-00:00",
    :person/death #inst "2005-04-19T00:00:00.000-00:00",
    :xt/id 130}
   {:person/name "Charles Napier",
    :person/born #inst "1936-04-12T00:00:00.000-00:00",
    :person/death #inst "2011-10-05T00:00:00.000-00:00",
    :xt/id 131}
   {:person/name "Peter MacDonald",
    :person/born #inst "1939-02-20T00:00:00.000-00:00"
    :xt/id 132}
   {:person/name "Marc de Jonge",
    :person/born #inst "1949-02-16T00:00:00.000-00:00",
    :person/death #inst "1996-06-06T00:00:00.000-00:00",
    :xt/id 133}
   {:person/name "Stephen Hopkins",
    :person/born #inst "1958-11-01T00:00:00.000-00:00"
    :xt/id 134}
   {:person/name "Ruben Blades",
    :person/born #inst "1948-07-16T00:00:00.000-00:00",
    :xt/id 135}
   {:person/name "Joe Pesci",
    :person/born #inst "1943-02-09T00:00:00.000-00:00",
    :xt/id 136}
   {:person/name "Ridley Scott",
    :person/born #inst "1937-11-30T00:00:00.000-00:00",
    :xt/id 137}
   {:person/name "Tom Skerritt",
    :person/born #inst "1933-08-25T00:00:00.000-00:00",
    :xt/id 138}
   {:person/name "Sigourney Weaver",
    :person/born #inst "1949-10-08T00:00:00.000-00:00",
    :xt/id 139}
   {:person/name "Veronica Cartwright",
    :person/born #inst "1949-04-20T00:00:00.000-00:00",
    :xt/id 140}
   {:person/name "Carrie Henn",
    :person/born #inst "1976-05-07T00:00:00.000-00:00"
    :xt/id 141}
   {:person/name "George Miller",
    :person/born #inst "1945-03-03T00:00:00.000-00:00",
    :xt/id 142}
   {:person/name "Steve Bisley",
    :person/born #inst "1951-12-26T00:00:00.000-00:00",
    :xt/id 143}
   {:person/name "Joanne Samuel",
    :person/born #inst "1957-08-05T00:00:00.000-00:00",
    :xt/id 144}
   {:person/name "Michael Preston",
    :person/born #inst "1938-05-14T00:00:00.000-00:00",
    :xt/id 145}
   {:person/name "Bruce Spence",
    :person/born #inst "1945-09-17T00:00:00.000-00:00",
    :xt/id 146}
   {:person/name "George Ogilvie",
    :person/born #inst "1931-03-05T00:00:00.000-00:00",
    :xt/id 147}
   {:person/name "Tina Turner",
    :person/born #inst "1939-11-26T00:00:00.000-00:00",
    :xt/id 148}
   {:person/name "Sophie Marceau",
    :person/born #inst "1966-11-17T00:00:00.000-00:00",
    :xt/id 149}])

^{::clerk/visibility {:code :fold :result :show}}
(def my-movies
  [{:movie/title "The Terminator",
    :movie/year 1984,
    :movie/director 100,
    :movie/cast [101 102 103],
    :movie/sequel 207,
    :xt/id 200}
   {:movie/title "First Blood",
    :movie/year 1982,
    :movie/director 104,
    :movie/cast [105 106 107],
    :movie/sequel 209,
    :xt/id 201}
   {:movie/title "Predator",
    :movie/year 1987,
    :movie/director 108,
    :movie/cast [101 109 110],
    :movie/sequel 211,
    :xt/id 202}
   {:movie/title "Lethal Weapon",
    :movie/year 1987,
    :movie/director 111,
    :movie/cast [112 113 114],
    :movie/sequel 212,
    :xt/id 203}
   {:movie/title "RoboCop",
    :movie/year 1987,
    :movie/director 115,
    :movie/cast [116 117 118],
    :xt/id 204}
   {:movie/title "Commando",
    :movie/year 1985,
    :movie/director 119,
    :movie/cast [101 120 121],
    :xt/id 205}
   {:movie/title "Die Hard",
    :movie/year 1988,
    :movie/director 108,
    :movie/cast [122 123 124],
    :xt/id 206}
   {:movie/title "Terminator 2: Judgment Day",
    :movie/year 1991,
    :movie/director 100,
    :movie/cast [101 102 125 126],
    :movie/sequel 208,
    :xt/id 207}
   {:movie/title "Terminator 3: Rise of the Machines",
    :movie/year 2003,
    :movie/director 127,
    :movie/cast [101 128 129],
    :xt/id 208}
   {:movie/title "Rambo: First Blood Part II",
    :movie/year 1985,
    :movie/director 130,
    :movie/cast [105 106 131],
    :movie/sequel 210,
    :xt/id 209}
   {:movie/title "Rambo III",
    :movie/year 1988,
    :movie/director 132,
    :movie/cast [105 106 133],
    :xt/id 210}
   {:movie/title "Predator 2",
    :movie/year 1990,
    :movie/director 134,
    :movie/cast [113 114 135],
    :xt/id 211}
   {:movie/title "Lethal Weapon 2",
    :movie/year 1989,
    :movie/director 111,
    :movie/cast [112 113 136],
    :movie/sequel 213,
    :xt/id 212}
   {:movie/title "Lethal Weapon 3",
    :movie/year 1992,
    :movie/director 111,
    :movie/cast [112 113 136],
    :xt/id 213}
   {:movie/title "Alien",
    :movie/year 1979,
    :movie/director 137,
    :movie/cast [138 139 140],
    :movie/sequel 215,
    :xt/id 214}
   {:movie/title "Aliens",
    :movie/year 1986,
    :movie/director 100,
    :movie/cast [139 141 103],
    :xt/id 215}
   {:movie/title "Mad Max",
    :movie/year 1979,
    :movie/director 142,
    :movie/cast [112 143 144],
    :movie/sequel 217,
    :xt/id 216}
   {:movie/title "Mad Max 2",
    :movie/year 1981,
    :movie/director 142,
    :movie/cast [112 145 146],
    :movie/sequel 218,
    :xt/id 217}
   {:movie/title "Mad Max Beyond Thunderdome",
    :movie/year 1985,
    :movie/director [142 147],
    :movie/cast [112 148],
    :xt/id 218}
   {:movie/title "Braveheart",
    :movie/year 1995,
    :movie/director [112],
    :movie/cast [112 149],
    :xt/id 219}])

;; Note: XTDB also has a JSON-over-HTTP API that naturally supports JSON documents using JSON-LD for an extended range of types.

;; The following code maps over both sets of docs to generate a single transaction containing one `put` operation per document, whilst also specifying the relevant table, and then submits the transaction.

(xt/submit-tx my-node (concat
                       (for [doc my-persons]
                         (xt/put :persons doc))
                       (for [doc my-movies]
                         (xt/put :movies doc))))

;; Note: loading the small amount of data we defined above can be comfortably done in a single transaction. In practice you will often find throughput benefits to batching `put` operations into groups of 1000 at a time.

;; With XTDB running and the data loaded, you can now execute a query, which is a Clojure list, by passing it to XTDB's `q` API. The meaning of this query will become apparent very soon!

(xt/q my-node '(from :movies [movie/title]))

;; To simplify this `xt/q` call throughout the rest of the tutorial we can define a new `q` function that saves us a few characters and visual clutter.

^{::clerk/visibility {:code :show :result :hide}}
(def q (partial xt/q my-node))

;; Queries can then be executed trivially:

(q '(from :movies [movie/title]))

;; ## Extensible Data Notation

;; An XTQL query is written in [extensible data notation (edn)](http://edn-format.org). Edn is a data format similar to JSON, but it:

;; * has more base types,
;; * is extensible with user defined value types,
;; * is a subset of [Clojure](http://clojure.org) data.

;; Edn consists of:

;; * Numbers: `42`, `3.14159`
;; * Strings: `"This is a string"`
;; * Keywords: `:kw`, `:namespaced/keyword`, `:foo.bar/baz`
;; * Symbols: `max`, `+`, `title`, `?title`
;; * Vectors: `[1 2 3]` `[foo "bar" ?baz 123 ...]`
;; * Lists: `(3.14 :foo [:bar :baz])`, `(+ 1 2 3 4)`
;; * Instants: `#inst "2021-05-26"`
;; * ...and a few other things which we will not need in this tutorial.

;; ## Basic Queries

;; Once again let's look at our first example query which finds all movie titles in our example database and this time discuss how it works:

(q '(from :movies [movie/title]))

;; XTQL queries consist of composable operators, optionally combined with a pipeline, but in this instance we only have [`from`](https://docs.xtdb.com/reference/main/xtql/queries.html#_from) which is a "source" operator that retrieves a relation from a table stored in XTDB.

;; The first argument it takes is the keyword name of the table to fetch data from, here it is the `:movies` table. The operator then takes a vector of definitions of which columns to return, in this case just listing the plain symbol `movie/title` which corresponds to the `:movie/title` key within our document.

;; The example database we're using contains mostly *movies* from the 1980s. You'll find information about movie titles, release year, directors, cast members, etc. As the tutorial advances we'll learn more about the contents of the database and how it's organized.

;; (TODO "The following schema diagram should serve as a helpful reference")

;; If we wish to find the IDs (as in the `:xt/id` primary key) of all people named (via the `:person/name` key) "Ridley Scott" we are able to specify a mapping to a string value within the `from` operator's column definition. This mapping acts as a filter. In this case there is only one match:

(q '(from :persons [{:person/name "Ridley Scott"} xt/id]))

;; Alternatively, we can construct a "pipeline" of operators to perform the same task more explicitly and use an explicit [`where`](https://docs.xtdb.com/reference/main/xtql/queries.html#_where) operator to filter the source relation. The `=` equality expression is used within the `where` operator.

(q '(-> (from :persons [person/name xt/id])
        (where (= person/name "Ridley Scott"))))

;; Since XTQL is subjected to query planning and optimization, these two queries result in an identical execution plan, at least as far as filtering is concerned.

;; If we want to avoid unnecessarily processing and returning the `person/name` column in the output relation (returned under the `:person/name` key in each result map), we can use a final [`return`](https://docs.xtdb.com/reference/main/xtql/queries.html#_return) operator to restrict the output to a specific set of of columns.

(q '(-> (from :persons [person/name xt/id])
        (where (= person/name "Ridley Scott"))
        (return xt/id)))

;; ### Exercises

;; Q1. Find the IDs and titles of movies in the database

(q '(from :solve-me [xt/id]))

;; Q2. Find the name of all people in the database

(q '(from :solve-me [xt/id]))

;; Q3. Find the IDs of movies made in 1987

(q '(from :solve-me [xt/id]))


;; ### Solutions

;; A1.

(q '(-> (from :movies [xt/id movie/title])))

;; A2.

(q '(-> (from :persons [person/name])))

;; A3.

(q '(-> (from :movies [xt/id movie/year])
        (where (= movie/year 1987))
        (return xt/id)))

;; ## Unification

;; Joins in XTQL are primarily specified using the [`unify`](https://docs.xtdb.com/reference/main/xtql/queries.html#_unify) operator - this combines multiple input relations based on the use of logic variables to represent and connect various columns. This provides a declarative, and yet terse, method of specifying join conditions (i.e., how relations relate to each other). The elements within a unify scope are called "clauses".  The user-provided clause order is unimportant, and should be arranged for ease for human comprehension.

;; Let's say we want to find out who starred in "Lethal Weapon". We will need to process two source relations for this, both `:movies` and `:persons`, and to achieve this we can embed two `from` operators within a `unify` (which itself simply returns a relation). However this requires introducing our first user-named logic variable (here we have chosen `p`) and we also need to [`unnest`](https://docs.xtdb.com/reference/main/xtql/queries.html#_unnest) the stored vector of IDs retrieved as `movie/cast`:

(q '(-> (unify (from :movies [{:movie/title "Lethal Weapon"} movie/cast])
               (unnest {p movie/cast})
               (from :persons [{:xt/id p} person/name]))
        (return person/name)))

;; Logic variables can be re-used and referenced as much as required, across many clauses, within a unify scope. Think of unify as similar to simultaneous equations in mathematics.

;; ### Exercises

;; Q1. Find movie titles made in 1985

(q '(from :solve-me [xt/id]))

;; Q2. What year was "Alien" released?

(q '(from :solve-me [xt/id]))

;; Q3. Who directed RoboCop? You will need to use `[<movie-eid> :movie/director <person-eid>]` to find the director for a movie.

(q '(from :solve-me [xt/id]))

;; Q4. Find directors who have directed Arnold Schwarzenegger in a movie.

(q '(from :solve-me [xt/id]))

;; ### Solutions

;; A1.

(q '(-> (from :movies [movie/title {:movie/year 1985}])
        (return movie/title)))

;; A2.

(q '(-> (from :movies [{:movie/title "Alien"} movie/year])
        (return movie/year)))

;; A3.

(q '(-> (unify (from :movies [{:movie/title "RoboCop"} movie/director])
               (from :persons [{:xt/id movie/director} person/name]))
        (return person/name)))

;; A4.

(q '(-> (unify (from :persons [{:xt/id arnie} {:person/name "Arnold Schwarzenegger"}])
               (from :movies [movie/cast movie/director])
               (unnest {arnie movie/cast})
               (from :persons [{:xt/id movie/director} person/name]))
        (return person/name)))

;; ## Parameterized queries

;; Looking at this query:

(q '(-> (unify (from :persons [{:xt/id sylvester} {:person/name "Sylvester Stallone"}])
               (from :movies [movie/cast movie/title])
               (unnest {sylvester movie/cast}))
        (return movie/title)))

;; It would be great if we could reuse this query to find movie titles for any actor and not just for "Sylvester Stallone". This is possible using parameters, which are supplied as a map under an `:args` key to options map of `xt/q`. Within queries, arguments can be referenced using the `$` prefix to a symbol.

(q '(-> (unify (from :persons [{:xt/id p} {:person/name $name}])
               (from :movies [movie/cast movie/title])
               (unnest {p movie/cast}))
        (return movie/title))
   {:args {:name "Sylvester Stallone"}})

;; You can pass any number of input parameters to a query, and these parameters can be used for relations as well as the full range of value types.

;; For example, let's say you have the vector `["James Cameron" "Arnold Schwarzenegger"]` and you want to use this as input to find all movies where these two people collaborated.  First, outside of XTQL, you would need to reshape the vector into a valid relation (i.e., a vector of maps with named columns) and refer to it via the [`rel`](https://docs.xtdb.com/reference/main/xtql/queries.html#_rel) source operator:

(q '(-> (unify (rel $director-actor-rel [director actor])
               (from :persons [{:xt/id d} {:person/name director}])
               (from :persons [{:xt/id a} {:person/name actor}])
               (from :movies [{:movie/director d} movie/cast movie/title])
               (unnest {a movie/cast}))
        (return movie/title))
   {:args {:director-actor-rel [{:director "James Cameron"
                                 :actor "Arnold Schwarzenegger"}]}})

;; Say you want to find all movies directed by either James Cameron **or** Ridley Scott, you can simply add an additional row to the input relation:

(q '(-> (unify (rel $directors [director])
               (from :persons [{:xt/id p} {:person/name director}])
               (from :movies [{:movie/director p} movie/title]))
        (return movie/title))
   {:args {:directors [{:director "James Cameron"}
                       {:director "Ridley Scott"}]}})

;; Now let's consider an input relation with columns `movie-title` and `box-office-earnings`:

'[
  ...
  {:movie-title "Die Hard" :box-office-earnings 140700000}
  {:movie-title "Alien" :box-office-earnings 104931801}
  {:movie-title "Lethal Weapon" :box-office-earnings 120207127}
  {:movie-title "Commando" :box-office-earnings 57491000}
  ...
]

;; Let's use this data, and the data in our database, to find box office earnings for a particular director:

(q '(-> (unify (rel $earnings-data [movie-title box-office-earnings])
               (from :persons [{:xt/id p} {:person/name $director}])
               (from :movies [{:movie/director p} {:movie/title movie-title}])
               )
        (return movie-title box-office-earnings))
   {:args {:director "Ridley Scott"
           :earnings-data [{:movie-title "Die Hard" :box-office-earnings 140700000}
                           {:movie-title "Alien" :box-office-earnings 104931801}
                           {:movie-title "Lethal Weapon" :box-office-earnings 120207127}
                           {:movie-title "Commando" :box-office-earnings 57491000}]}})

;; ### Exercises

;; Q1. Find movie title by year

(q '(from :solve-me [xt/id])
   {:args {:year 1988}})

;; Q2. Given a list of movie titles, find the title and the year that movie was released.

(q '(from :solve-me [xt/id])
   {:args {:title-rel [{:title "Lethal Weapon"}]}})

;; Q3. Find all movie `title`s where the `actor` and the `director` has worked together

(q '(from :solve-me [xt/id])
   {:args {:director-actor-rel [{:director "James Cameron"
                                 :actor "Arnold Schwarzenegger"}]}})

;; Q4. Write a query that, given an actor name and a relation with movie-title/rating, finds the movie titles and corresponding rating for which that actor was a cast member.

(q '(from :solve-me [xt/id])
   {:args {:name "Mel Gibson"
           :title-rating-rel [{:title "Die Hard"
                               :rating 8.3}]}})

;; ### Solutions

;; A1.

(q '(-> (from :movies [{:movie/year $year} movie/title])
        (return movie/title))
   {:args {:year 1988}})Ambra Dolce

;; A2.

(q '(unify (rel $title-rel [title])
           (from :movies [movie/year {:movie/title title}]))
   {:args {:title-rel [{:title "Lethal Weapon"}
                       {:title "Lethal Weapon 2"}
                       {:title "Lethal Weapon 3"}]}})

;; A3.

(q '(-> (unify (rel $director-actor-rel [director actor])
               (from :persons [{:xt/id d} {:person/name director}])
               (from :persons [{:xt/id a} {:person/name actor}])
               (from :movies [{:movie/director d} movie/cast movie/title])
               (unnest {a movie/cast}))
        (return movie/title))
   {:args {:director-actor-rel [{:director "James Cameron"
                                 :actor "Michael Biehn"}]}})

;; A4.

(q '(-> (unify (rel $title-rating-rel [title rating])
               (from :persons [{:xt/id p} {:person/name $name}])
               (from :movies [movie/cast {:movie/title title}])
               (unnest {p movie/cast}))
        (return title rating))
   {:args {:name "Mel Gibson"
           :title-rating-rel [{:title "Die Hard", :rating 8.3}
                              {:title "Alien", :rating 8.5}
                              {:title "Lethal Weapon", :rating 7.6}
                              {:title "Commando", :rating 6.5}
                              {:title "Mad Max Beyond Thunderdome", :rating 6.1}
                              {:title "Mad Max 2", :rating 7.6}
                              {:title "Rambo: First Blood Part II", :rating 6.2}
                              {:title "Braveheart", :rating 8.4}
                              {:title "Terminator 2: Judgment Day", :rating 8.6}
                              {:title "Predator 2", :rating 6.1}
                              {:title "First Blood", :rating 7.6}
                              {:title "Aliens", :rating 8.5}
                              {:title "Terminator 3: Rise of the Machines", :rating 6.4}
                              {:title "Rambo III", :rating 5.4}
                              {:title "Mad Max", :rating 7.0}
                              {:title "The Terminator", :rating 8.1}
                              {:title "Lethal Weapon 2", :rating 7.1}
                              {:title "Predator", :rating 7.8}
                              {:title "Lethal Weapon 3", :rating 6.6}
                              {:title "RoboCop", :rating 7.5}]}})

;; ## Expressions

;; So far, we have only been dealing with joining of data across relations and unnested columns using basic equality. We have not yet seen how to handle questions like "*Find all movies released before 1984*". This is where **expressions** come into play.

;; Let's start with the query for the question above:

(q '(-> (from :movies [movie/title movie/year])
        (where (< movie/year 1984))))

;; Like all other functions and expressions in XTQL, this use of `<` reflects the standard SQL definition and behaviours (in SQL `<` is often referred to as a comparison operator"). This is particularly important to keep in mind when creating such expressions that work across multiple types (e.g. comparing different numeric values).

;; You can use [any supported SQL function](https://docs.xtdb.com/reference/main/stdlib.html) from the XTDB standard library:

(q '(-> (from :persons [person/name])
        (where (like person/name "M%"))))

;; Note: if there are functions you need that we have not implemented yet, please ask or feel free to open an issue. XTDB does not currently support any extension point for user-defined functions (UDFs).

;; ### Exercises

;; Q1. Find movies older than a certain year (inclusive)

(q '(from :solve-me [xt/id])
   {:args {:year 1979}})

;; Q2. Find actors older than Danny Glover

(q '(from :solve-me [xt/id]))

;; Q3. Find movies newer than `year` (inclusive) and has a `rating` higher than the one supplied

(q '(from :solve-me [xt/id])
   {:args {:year 1990
           :rating 8.0
           :title-rating-rel [{:title "Braveheart", :rating 8.4}
                              {:title "Predator 2", :rating 6.1}]}})

;; ### Solutions

;; A1.

(q '(-> (from :movies [movie/title movie/year])
        (where (<= movie/year $year))
        (return movie/title))
   {:args {:year 1979}})

;; A2.

(q '(-> (unify (from :persons [{:person/name "Danny Glover"} {:person/born b1}])
               (from :persons [xt/id person/name {:person/born b2}])
               (where (< b2 b1))
               (from :movies [movie/cast])
               (unnest {xt/id movie/cast}))
        (return person/name)))

;; A3.

(q '(-> (unify (rel $title-rating-rel [{:rating r} title])
               (from :movies [{:movie/title title} movie/year])
               (where (<= $year movie/year)
                      (< $rating r)))
        (return title))
   {:args {:year 1990
           :rating 8.0
           :title-rating-rel [{:title "Die Hard", :rating 8.3}
                              {:title "Alien", :rating 8.5}
                              {:title "Lethal Weapon", :rating 7.6}
                              {:title "Commando", :rating 6.5}
                              {:title "Mad Max Beyond Thunderdome", :rating 6.1}
                              {:title "Mad Max 2", :rating 7.6}
                              {:title "Rambo: First Blood Part II", :rating 6.2}
                              {:title "Braveheart", :rating 8.4}
                              {:title "Terminator 2: Judgment Day", :rating 8.6}
                              {:title "Predator 2", :rating 6.1}
                              {:title "First Blood", :rating 7.6}
                              {:title "Aliens", :rating 8.5}
                              {:title "Terminator 3: Rise of the Machines", :rating 6.4}
                              {:title "Rambo III", :rating 5.4}
                              {:title "Mad Max", :rating 7.0}
                              {:title "The Terminator", :rating 8.1}
                              {:title "Lethal Weapon 2", :rating 7.1}
                              {:title "Predator", :rating 7.8}
                              {:title "Lethal Weapon 3", :rating 6.6}
                              {:title "RoboCop", :rating 7.5}]}})

;; ## Generating columns

;; In addition to defining constraints, expressions can be used to transform data and return it via adding columns using the [`with`](https://docs.xtdb.com/reference/main/xtql/queries.html#_with) operator - either new columns for the next operator in a pipeline, or as additional columns within the `unify` scope.

;; For example, given a person's birthday, it's easy to calculate the (very approximate) age of a person:

(q '(-> (from :persons [{:person/name $name} person/born])
        (with {:age (- (extract "YEAR" (current-date)) (extract "YEAR" person/born))}))
   {:args {:name "Tina Turner"}})

;; ## To Be Continued...

;; ## Conclusion

;; Congratulations for making it through the tutorial - we hope this knowledge helps you in your XTQL journey! Any and all feedback is appreciated, as are new contributions, please email [hello@xtdb.com](mailto:hello@xtdb.com) or open an issue via [GitHub](https://github.com/xtdb/2x-playground)

;; ## Copyright & License

;; The MIT License (MIT)

;; Copyright © 2013 - 2023 Jonas Enlund

;; Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;; ## Thank You

;; Thank you Jonas and contributors for freely licensing your excellent materials!

;; ## Static Build

;; If you're in an active REPL, run the following

(comment (clerk/build! {:paths ["src/learn-xtql-today-with-clojure.clj"]}))

;; Or otherwise:

;; 1. Clear the cache (clerk/clear-cache!) (or `rm .clerk/cache/*` / delete the `.clerk` directory)

;; 2. `clj -J--add-opens=java.base/java.nio=ALL-UNNAMED -X:nextjournal/clerk` (and be sure to not save this namespace in parallel / trigger cache changes)

;; 3. Browse the HTML file(s) created under `public/build/`
