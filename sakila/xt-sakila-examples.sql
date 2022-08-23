-- skipped entire queries due to:
-- OVER, USING

-- not working:
-- cast(<string> as INT)
-- concat() -- I left a few examples in, but otherwise instead transformed to return e.g. SELECT customer.first_name, customer.last_name
-- having with alias (instead of raw expression), can possibly just duplicate the expression as a workaround but I'm unsure of the impact/correctness
-- month(), year()

-- have only included the original if there are differences beyond FQ columns and the *_id -> id transform

-- also note:
-- capitalised film.title
-- ids are currently strings not numbers (examples ~always expected numbers), so have transformed all the explicit values in the queries accordingly
-- empty ' ' values: address.district, customer.phone

\! echo https://www.jooq.org/sakila;

\! echo Which actor has the most films?;
/*SELECT first_name, last_name, count(*) films
  FROM actor AS a
       JOIN film_actor AS fa USING (actor_id)
 GROUP BY actor_id, first_name, last_name
 ORDER BY films DESC
 LIMIT 1;*/
--
SELECT actor.first_name, actor.last_name, count(*) films
  FROM actor
       JOIN film_actor ON (actor.id = film_actor.actor_id)
 GROUP BY actor.id, actor.first_name, actor.last_name
 ORDER BY films DESC
 FETCH FIRST 1 ROWS ONLY;

\! echo https://datamastery.gitlab.io/exercises/sakila-queries-answers.sql;

\! echo How many distinct actors last names are there?;
select count(distinct actor.last_name) from actor;

\! echo Which last names are not repeated?;
select actor.last_name from actor group by actor.last_name having count(*) = 1;

\! echo Which last names appear more than once?;
select actor.last_name from actor group by actor.last_name having count(*) > 1;

\! echo Is 'Academy Dinosaur' available for rent from Store 1?;
\! echo Step 1: which copies are at Store 1?;
/*select film.film_id, film.title, store.store_id, inventory.inventory_id
  from inventory join store using (store_id) join film using (film_id)
 where film.title = 'Academy Dinosaur' and store.store_id = 1;*/
--
select distinct film.id, film.title, store.id, inventory.id
  from inventory join store on (inventory.store_id = store.id)
       join film on (inventory.film_id = film.id)
 where film.title = 'ACADEMY DINOSAUR' and store.id = '1';
-- ?? returns 56 duplicates without distinct, 4 with ...but inventory.id are all '1' ?!
\! echo Step 2: pick an inventory_id to rent:;
/*select inventory.inventory_id
  from inventory join store using (store_id)
       join film using (film_id)
       join rental using (inventory_id)
 where film.title = 'Academy Dinosaur'
   and store.store_id = 1
   and not exists (select * from rental
                    where rental.inventory_id = inventory.inventory_id
                      and rental.return_date is null);*/
--
select distinct inventory.id, film.title, store.id
  from inventory join store on (inventory.store_id = store.id)
       join film on (inventory.film_id = film.id)
       join rental on (rental.inventory_id = inventory.id)
 where film.title = 'ACADEMY DINOSAUR'
   and store.id = '1'
   and not exists (select * from rental
                    where rental.inventory_id = inventory.id
                      and rental.return_date is null);
-- ?? 168 with distinct, 4 with

\! echo Insert a record to represent Mary Smith renting 'Academy Dinosaur' from Mike Hillyer at Store 1 today;
--
/*insert into rental (rental_date, inventory_id, customer_id, staff_id)
  values (NOW(), 1, 1, 1);*/
--
insert into rental (rental_date, inventory_id, customer_id, staff_id)
  select current_timestamp id, current_timestamp rental_date, '1' inventory_id, '1' customer_id, '1' staff_id from (values (0)) a;
-- !! untested

--\! echo When is 'Academy Dinosaur' due?;
--\! echo Step 1: what is the rental duration?;
--select film.rental_duration from film where film.film_id = 1;
-- ?? dependent on the above and a trigger
-- etc.

--\! echo What is that average length of all the films in the sakila DB?;
-- select avg(film.length) from film; -- doesn't return an error even!
-- select avg(cast(film.length AS INT)) from film; -- error, same with NUMERIC

--\! echo What is the average length of films by category?;
-- etc.

--\! echo Which film categories are long?;
-- etc.

\! echo https://github.com/joelsotelods/sakila-db-queries/blob/master/sakila-db-queries.sql;

\! echo Display the first and last names of all actors from the table actor.;
select actor.first_name, actor.last_name from actor;

-- \! echo Display the first and last name of each actor in a single column in upper case letters. Name the column Actor Name.;
-- select upper(concat(actor.first_name, ' ', actor.last_name)) 'Actor Name' from actor;
-- !! can't have spaces in quoted column label like this

\! echo You need to find the ID number, first name, and last name of an actor, of whom you know only the first name, "Joe." What is one query would you use to obtain this information?;
select actor.id, actor.first_name, actor.last_name
  from actor
  where lower(actor.first_name) = lower('Joe');
-- NOTE: had to change "Joe" to 'Joe'

\! echo Find all actors whose last name contain the letters GEN:;
select actor.first_name, actor.last_name from actor where upper(actor.last_name) like '%GEN%';

\! echo Find all actors whose last names contain the letters LI. This time, order the rows by last name and first name, in that order:;
select actor.first_name, actor.last_name
  from actor
  where upper(actor.last_name)
  like '%LI%'
  order by actor.last_name, actor.first_name;
-- !! had to qualify the columns
-- and select * from actor where upper(actor.last_name) like '%LI%' order by actor.last_name; didn't work

\! echo Using IN, display the country_id and country columns of the following countries: Afghanistan, Bangladesh, and China:;
select country.id, country.country
  from country
  where country.country in ('Afghanistan', 'Bangladesh', 'China');

\! echo List the last names of actors, as well as how many actors have that last name.;
select actor.last_name, count(*) actor_count
  from actor
  group by actor.last_name
  order by actor_count desc, actor.last_name;

/*\! echo List last names of actors and the number of actors who have that last name, but only for names that are shared by at least two actors;
select actor.last_name, count(*) actor_count
  from actor
  group by actor.last_name
  having actor_count >1
  order by actor_count desc, actor.last_name;*/
-- !! HAVING is not working here, can't use alias?

/* TODO return to this one with working inserts
-- 4c. The actor HARPO WILLIAMS was accidentally entered in the actor table as GROUCHO WILLIAMS. Write a query to fix the record.

select * from actor where first_name = 'GROUCHO' and last_name = 'WILLIAMS';

update actor set first_name = 'HARPO', last_name = 'WILLIAMS' where first_name = 'GROUCHO' and last_name = 'WILLIAMS';

select * from actor where last_name = 'WILLIAMS';

-- 4d. Perhaps we were too hasty in changing GROUCHO to HARPO. It turns out that GROUCHO was the correct name after all! In a single query, if the first name of the actor is currently HARPO, change it to GROUCHO.

update actor set first_name = 'GROUCHO', last_name = 'WILLIAMS' where first_name = 'HARPO' and last_name = 'WILLIAMS';

select * from actor where last_name = 'WILLIAMS';*/

\! echo Use JOIN to display the first and last names, as well as the address, of each staff member. Use the tables staff and address:;
select stf.first_name, stf.last_name, adr.address, adr.district, adr.postal_code, adr.city_id
  from staff stf
       left join address adr
           on stf.address_id = adr.id;

/*\! echo Use JOIN to display the total amount rung up by each staff member in August of 2005. Use tables staff and payment.;
select stf.first_name, stf.last_name, sum(pay.amount)
  from staff stf
       left join payment pay
           on stf.id = pay.staff_id
 WHERE month(pay.payment_date) = 8
   and year(pay.payment_date)  = 2005
 group by stf.first_name, stf.last_name;*/
-- !! hmm, would be good to get these working


\! echo List each film and the number of actors who are listed for that film. Use tables film_actor and film. Use inner join.;
select flm.title, count(*) number_of_actors
  from film flm
       inner join film_actor fim_act
           on flm.id = fim_act.film_id
 group by flm.title
 order by number_of_actors desc;

\! echo How many copies of the film Hunchback Impossible exist in the inventory system?;
select flm.title, count(*) number_in_inventory
  from film flm
       inner join inventory inv
           on flm.id = inv.film_id
 where lower(flm.title) = lower('Hunchback Impossible')
 group by flm.title;

/*\! echo Using the tables payment and customer and the JOIN command, list the total paid by each customer. List the customers alphabetically by last name:;
select cust.first_name, cust.last_name, sum(pay.amount) TotalAmountPaid
  from payment pay
       join customer cust
           on pay.customer_id = cust.id
 group by cust.first_name, cust.last_name
 order by cust.last_name;*/
-- ?? not sure about this, no error

\! echo The music of Queen and Kris Kristofferson have seen an unlikely resurgence. As an unintended consequence, films starting with the letters K and Q have also soared in popularity. Use subqueries to display the titles of movies starting with the letters K and Q whose language is English.;
select film.title
  from film
 where (film.title like 'K%' or film.title like 'Q%')
   and film.language_id in (
     select language.id
       from language
      where language.name = 'English'
   )
 order by film.title;

\! echo Use subqueries to display all actors who appear in the film Alone Trip.;
select actor.first_name, actor.last_name
  from actor
 where actor.id in (
   select film_actor.actor_id
     from film_actor
    where film_actor.film_id in (
      select film.id from film where lower(film.title) = lower('Alone Trip')
    )
 );

\! echo You want to run an email marketing campaign in Canada, for which you will need the names and email addresses of all Canadian customers. Use joins to retrieve this information.;
\! echo Via Subquery
select customer.first_name, customer.last_name, customer.email
  from customer
 where customer.address_id in (
   select address.id
     from address
    where address.city_id in (
      select city.id
        from city
       where city.country_id in (
         select country.id
           from country
          where country.country = 'Canada'
       )
    )
 );
\! echo Via Join
select cus.first_name, cus.last_name, cus.email
  from customer cus
       join address adr
           on cus.address_id = adr.id
       join city cit
           on adr.city_id = cit.id
       join country cou
           on cit.country_id = cou.id
 where cou.country = 'Canada';

\! echo Sales have been lagging among young families, and you wish to target all family movies for a promotion. Identify all movies categorized as family films.;
select film.id, film.title, film.release_year
  from film
 where film.id in (
   select film_category.film_id
     from film_category
    where film_category.category_id in (
      select category.id
        from category
       where category.name = 'Family'
    )
 );

\! echo Display the most frequently rented movies in descending order.;
select A.id, A.title
  from film A
       join (
         select inv.film_id, count(ren.id) times_rented
           from rental ren
                join inventory inv
                    on ren.inventory_id = inv.id
          group by inv.film_id
       ) B
           on A.id = B.film_id
 order by B.times_rented desc;

/*\! echo Write a query to display how much business, in dollars, each store brought in.;
select A.id, B.sales
  from store A
       join (
         select cus.store_id, sum(pay.amount) sales
           from customer cus
                join payment pay
                    on pay.customer_id = cus.id
          group by cus.store_id
       ) B
           on A.id = B.store_id
  order by a.id;

\! echo Write a query to display for each store its store ID, city, and country.;
select sto.id, cit.city, cou.country
  from store sto
       left join address adr
           on sto.address_id = adr.id
       join city cit
           on adr.city_id = cit.id
       join country cou
           on cit.country_id = cou.id;

select A.*, B.sales
  from (
    select sto.id, cit.city, cou.country
      from store sto
           left join address adr
               on sto.address_id = adr.id
           join city cit
               on adr.city_id = cit.id
           join country cou
               on cit.country_id = cou.id
  ) A
       join (
         select cus.store_id, sum(pay.amount) sales
           from customer cus
                join payment pay
                    on pay.customer_id = cus.id
          group by cus.store_id
       ) B
           on A.id = B.store_id
 order by a.id;*/
-- !! need to be able to cast pay.amount

/*\! echo List the top five genres in gross revenue in descending order. (Hint: you may need to use the following tables: category, film_category, inventory, payment, and rental.);
select cat.name category_name, sum( IFNULL(pay.amount, 0) ) revenue
  from category cat
       left join film_category flm_cat
           on cat.id = flm_cat.category_id
       left join film fil
           on flm_cat.film_id = fil.id
       left join inventory inv
           on fil.id = inv.film_id
       left join rental ren
           on inv.id = ren.inventory_id
       left join payment pay
           on ren.id = pay.rental_id
 group by cat.name
 order by revenue desc
 FETCH FIRST 5 ROWS ONLY;*/
-- !! IFNULL needed also

/*\! echo https://stackoverflow.com/questions/59226077/queries-sql-sakila-bd;

\! echo Which are the top 10 customers with the most delays in returning movies.;
select c.id, count(*)
  from
    customer c
    inner join rental r
        on r.customer_id = c.id
    inner join film f
        on f.id = r.film_id
        and (datediff (r.rental_date, r.return_date)) > f.rental_duration
 group by c.id
 order by count(*) desc
 limit 10;*/
-- !! datediff needed

\! echo https://www.cs.dartmouth.edu/~cs61/Resources/Examples/SQL/sql_files/Sakila%20Example.sql;
\! echo same as https://dev.mysql.com/doc/sakila/en/sakila-usage.html ?

/*\! echo Rent a DVD - To rent a DVD, first confirm that the given inventory item is in stock, and then insert a row into the rental table. After the rental table is created, insert a row into the payment table. Depending on business rules, you may also need to check whether the customer has an outstanding balance before processing the rental.;
SELECT INVENTORY_IN_STOCK(10);

INSERT INTO rental(rental_date, inventory_id, customer_id, staff_id) VALUES(NOW(), 10, 3, 1);

SELECT @balance := get_customer_balance(3, NOW());

  INSERT INTO payment (customer_id, staff_id, rental_id, amount,  payment_date) VALUES(3,1,LAST_INSERT_ID(), @balance, NOW());

\! echo Return a DVD - To return a DVD, update the rental table and set the return date. To do this, first identify the rental_id to update based on the inventory_id of the item being returned. Depending on the situation, it may be necessary to check the customer balance and perhaps process a payment for overdue fees by inserting a row into the payment table.;

SELECT rental_id from rental where inventory_id=10 and customer_id=3 and return_date is NULL;

UPDATE rental SET return_date=NOW() WHERE rental_id=16050;

SELECT get_customer_balance(3, NOW());*/

/*\! echo Find Overdue DVDs - Many DVD stores produce a daily list of overdue rentals so that customers can be contacted and asked to return their overdue DVDs. To create such a list, search the rental table for films with a return date that is NULL and where the rental date is further in the past than the rental duration specified in the film table. If so, the film is overdue and we should produce the name of the film along with the customer name and phone number.;
SELECT customer.last_name, customer.first_name, address.phone, film.title
  FROM rental INNER JOIN customer ON rental.customer_id = customer.id
       INNER JOIN address ON customer.address_id = address.id
       INNER JOIN inventory ON rental.inventory_id = inventory.id
       INNER JOIN film ON inventory.film_id = film.id
 WHERE rental.return_date IS NULL
   AND rental_date + INTERVAL film.rental_duration DAY < CURRENT_DATE()
  LIMIT 5;*/
-- !! needs cast and interval

\! echo https://towardsdatascience.com/learning-sql-the-hard-way-4173f11b26f1;

/*\! echo find out how differently censored rated movies are timed differently using;
SELECT rating, avg(length) as length_avg
  FROM sakila.film
 GROUP BY rating
 ORDER BY length_avg desc;*/
-- needs cast for length

\! echo find out how many copies of each movie we have in our inventory;
SELECT temp.title, count(temp.title) as num_copies
  FROM (
    SELECT B.title
      FROM inventory A
           LEFT JOIN film B
               ON A.film_id = B.id) temp
 GROUP BY temp.title
 ORDER BY num_copies DESC;

\! echo https://www.programsbuzz.com/interview-question/sakila-database-questions-and-answers;

\! echo find the full name of the actor who has acted in the maximum number of movies;
/*select concat(First_name, ' ', Last_name) as Full_name
  from actor a
       inner join film_actor f
           using (actor_id)
 group by f.actor_id
 order by count(f.actor_id) desc
 limit 1;*/
--
select a.first_name, a.last_name, count(f.actor_id) actors_in_film_count
  from actor a
       inner join film_actor f
           on a.id = f.actor_id
 group by f.actor_id, a.first_name, a.last_name
 order by actors_in_film_count desc
 fetch first 1 row only;
-- !! needed to add all selected to group by columns, compare with "Which actor has the most films?" above (essentially the same Q)
-- !! can't have the count expression in order by

\! echo find the full name of the actor who has acted in the third most number of movies;
select a.first_name, a.last_name, count(f.actor_id) actors_in_film_count
  from actor a
       inner join film_actor f
           on a.id = f.actor_id
 group by f.actor_id, a.first_name, a.last_name
 order by actors_in_film_count desc
 offset 2 rows
 fetch first 1 row only;

/*\! echo find the film which grossed the highest revenue for the video renting organisation;
select film.title
  from film
       inner join inventory
           on (inventory.film_id = film.id)
       inner join rental
           on (rental.inventory_id = inventory.id)
       inner join payment
           on (payment.rental_id = rental.id)
 group by film.title
-- order by sum(amount) desc
 fetch first 1 row only;*/
-- !! requires cast for sum

/*\! echo find the city which generated the maximum revenue for the organisation;
select city.city
  from city
       inner join address
           on (address.city_id = city.id)
       inner join customer
           on (customer.address_id = address.id)
       inner join payment
           on (payment.customer_id = customer.id)
 group by city.city
-- order by sum(amount) desc
 fetch first 1 row only;*/
-- !! requires cast for sum

\! echo find out how many times a particular movie category is rented. Arrange these categories in the decreasing order of the number of times they are rented;
select category.name, count(rental.id) Rental_count
  from category
       inner join film_category
           on (film_category.category_id = category.id)
       inner join film
           on (film.id = film_category.film_id)
       inner join inventory
           on (inventory.film_id = film.id)
       inner join rental
           on (rental.inventory_id = inventory.id)
 group by category.name
 order by Rental_count desc;
-- 22 results but slowest query yet (possibly/seemingly)

\! echo find the full names of customers who have rented sci-fi movies more than 2 times. Arrange these names in the alphabetical order;
select customer.first_name, customer.last_name
  from category
       inner join film_category
           on (film_category.category_id = category.id)
       inner join film
           on (film_category.film_id = film.id)
       inner join inventory
           on (inventory.film_id = film.id)
       inner join rental
           on (rental.inventory_id = inventory.id)
       inner join customer
           on (rental.customer_id = customer.id)
 where category.name = 'Sci-Fi'
 group by customer.first_name, customer.last_name
 having count(rental.id) > 2
 order by customer.first_name, customer.last_name;

\! echo find the full names of those customers who have rented at least one movie and belong to the city Arlington;
select customer.first_name, customer.last_name
  from rental
       inner join customer
           on (rental.customer_id = customer.id)
       inner join address
           on (customer.address_id = address.id)
       inner join city
           on (address.city_id = city.id)
 where city.city = 'Arlington'
 group by customer.first_name, customer.last_name;

\! echo find the number of movies rented across each country. Display only those countries where at least one movie was rented. Arrange these countries in the alphabetical order;
select country.country, count(rental.id) as Rental_count
  from rental
       inner join customer
           on (rental.customer_id = customer.id)
       inner join address
           on (customer.address_id = address.id)
       inner join city
           on (address.city_id = city.id)
       inner join country
           on (city.country_id = country.id)
 group by country.country
 order by country.country;
-- !! had to turn Country to country.country instead of country.Country
/*\! echo alternatively;
select e.country, count(a.rental_id) as rental_count
  from rental a
       left outer join customer b ON   (a.customer_id=b.id)
       left outer join address c ON    (b.address_id=c.id)
       left outer join city d ON       (c.city_id=d.id)
       left outer join country e ON    (d.country_id=e.id)
 group by e.country
having rental_count >=1
 order by e.country asc;*/
-- !! having can't refer to the alias, again

\! echo https://www.oreilly.com/library/view/high-performance-mysql/9780596101718/ch04.html;

\! echo find each casting by each actor starring across all movies along with release year (example is for discussing MySQL join optimization);
SELECT film.id, film.title, film.release_year, actor.id,
       actor.first_name, actor.last_name
  FROM film
       INNER JOIN film_actor ON(film_actor.film_id = film.id)
       INNER JOIN actor ON(film_actor.actor_id = actor.id);
-- 11k rows, returns quickly, example intended to illustrate different join order optimization possibilities

\! echo  find all films whose casts include the actress Penelope Guiness (example is for discussing lack of subquery decorrelation in MySQL);
SELECT film.title FROM film
WHERE film.id IN(
  SELECT film_actor.film_id FROM film_actor WHERE film_actor.actor_id = '1');
-- !! would be great to confirm that XT does handle this correctly/ideally
\! echo according to the source, MySQL effectively rewrites the above to the following (EXPLAIN shows the result as DEPENDENT SUBQUERY), whereas XTDB should not;
SELECT film.title FROM film
 WHERE EXISTS (
   SELECT film_actor.id
     FROM film_actor
    WHERE film_actor.actor_id = '1'
      AND film_actor.film_id = film.id);
\! echo users of MySQL should rewrite such queries to use a JOIN instead, but XTDB should handle this transformation automatically;
SELECT film.title FROM film
                       INNER JOIN film_actor ON(film_actor.film_id = film.id)
 WHERE film_actor.actor_id = '1';

\! echo another example of a correlated subquery for MySQL designed to show it is more optimal than any other rewrite;
-- MySQL doesn’t always optimize correlated subqueries badly. If you hear advice to always avoid them, don’t listen! Instead, benchmark and make your own decision. Sometimes a correlated subquery is a perfectly reasonable, or even optimal, way to get a result
SELECT film.id, film.language_id FROM film
 WHERE NOT EXISTS(
   SELECT film_actor.film_id FROM film_actor
    WHERE film_actor.film_id = film.id
 );
-- !! returns no rows, might just be due to lack of such data, so will perhaps need to add DML insert;

\! echo the standard advice for the above query is to write it as a LEFT OUTER JOIN instead of using a subquery. In theory, MySQL’s execution plan will be essentially the same either way. In theory, MySQL will execute the queries almost identically. In reality, benchmarking is the only way to tell which approach is really faster;
SELECT film.id, film.language_id
  FROM film
       LEFT OUTER JOIN film_actor ON(film_actor.film_id = film.id)
 WHERE film_actor.film_id IS NULL;
-- !! this returns 1000 rows, should be the same output as before though according to the source, weird TODO

\! echo Sometimes a subquery can be faster. For example, it can work well when you just want to see rows from one table that match rows in another table. Although that sounds like it describes a join perfectly, it’s not always the same thing. The following join, which is designed to find every film that has an actor, will return duplicates because some films have multiple actors;
SELECT film.id
  FROM film
       INNER JOIN film_actor ON(film_actor.film_id = film.id);
-- 67747 rows, slowest
\! echo We need to use DISTINCT or GROUP BY to eliminate the duplicates;
SELECT DISTINCT film.id
  FROM film
       INNER JOIN film_actor ON(film_actor.film_id = film.id);
-- 1000 rows, slow
\! echo But what are we really trying to express with this query, and is it obvious from the SQL? The EXISTS operator expresses the logical concept of “has a match” without producing duplicated rows and avoids a GROUP BY or DISTINCT operation, which might require a temporary table. Here’s the query written as a subquery instead of a join, which performs much faster than the join;
SELECT film.id FROM film
 WHERE EXISTS(SELECT film_actor.id FROM film_actor
               WHERE film.id = film_actor.film_id);
-- 6173 rows, fast

-- \! echo MySQL sometimes can’t “push down” conditions from the outside of a UNION to the inside, where they could be used to limit results or enable additional optimizations.;
--If you think any of the individual queries inside a UNION would benefit from a LIMIT, or if you know they’ll be subject to an ORDER BY clause once combined with other queries, you need to put those clauses inside each part of the UNION. For example, if you UNION together two huge tables and LIMIT the result to the first 20 rows, MySQL will store both huge tables into a temporary table and then retrieve just 20 rows from it. You can avoid this by placing LIMIT 20 on each query inside the UNION;
-- no example given

\! echo MySQL Index merge optimizations - much earlier versions of MySQL could use only a single index, so when no single index was good enough to help with all the restrictions in the WHERE clause, MySQL often chose a table scan. For example, the film_actor table has an index on film_id and an index on actor_id, but neither is a good choice for both WHERE conditions in this query. In MySQL 5.0 and newer, however, the query can use both indexes, scanning them simultaneously and merging the results. There are three variations on the algorithm: union for OR conditions, intersection for AND conditions, and unions of intersections for combinations of the two;
SELECT film_actor.film_id, film_actor.actor_id
  FROM film_actor
 WHERE film_actor.actor_id = '1' OR film_actor.film_id = '1';
-- 28 rows
\!echo In older MySQL versions, that query would produce a table scan unless you wrote it as the UNION of two queries;
SELECT film_actor.film_id, film_actor.actor_id
  FROM film_actor
 WHERE film_actor.actor_id = '1'
 UNION ALL
SELECT film_actor.film_id, film_actor.actor_id
  FROM film_actor WHERE film_actor.film_id = '1'
                    AND film_actor.actor_id <> '1';
-- also 28 rows, LGTM
-- MySQL can use this technique on complex WHERE clauses, so you may see nested operations in the Extra column for some queries. This often works very well, but sometimes the algorithm’s buffering, sorting, and merging operations use lots of CPU and memory resources. This is especially true if not all of the indexes are very selective, so the parallel scans return lots of rows to the merge operation. Recall that the optimizer doesn’t account for this cost—it optimizes just the number of random page reads. This can make it “underprice” the query, which might in fact run more slowly than a plain table scan. The intensive memory and CPU usage also tends to impact concurrent queries, but you won’t see this effect when you run the query in isolation. This is another reason to design realistic benchmarks.
-- If your queries run more slowly because of this optimizer limitation, you can work around it by disabling some indexes with IGNORE INDEX, or just fall back to the old UNION tactic.

\! echo equality propagation - in MySQL this can have unexpected costs sometimes. For example, consider a huge IN() list on a column the optimizer knows will be equal to some columns on other tables, due to a WHERE, ON, or USING clause that sets the columns equal to each other. The optimizer will “share” the list by copying it to the corresponding columns in all related tables.;
-- This is normally helpful, because it gives the query optimizer and execution engine more options for where to actually execute the IN() check. But when the list is very large, it can result in slower optimization and execution. There’s no built-in workaround for this problem at the time of this writing (2008)—you’ll have to change the source code if it’s a problem for you. (It’s not a problem for most people.);
-- no example given

/*\! echo Beginning in MySQL 5.0, loose index scans are possible in certain limited circumstances, such as queries that find maximum and minimum values in a grouped query. This is a good optimization for this special purpose, but it is not a general-purpose loose index scan. It might be better termed a “loose index probe.”;
SELECT film_actor.actor_id, MAX(film_actor.film_id)
  FROM film_actor
 GROUP BY film_actor.actor_id*/
-- requires cast
