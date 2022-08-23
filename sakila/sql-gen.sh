sed -z \
       -e 's/language\n (language_id/language\n (id/g' \
       -e 's/country\n (country_id/country\n (id/g' \
       -e 's/city\n (city_id/city\n (id/g' \
       -e 's/address\n (address_id/address\n (id/g' \
       -e 's/into actor\n (actor_id/into actor\n (id/g' \
       -e 's/staff\n (staff_id/staff\n (id/g' \
       -e 's/store\n (store_id/store\n (id/g' \
       -e 's/into category\n (category_id/into category\n (id/g' \
       -e 's/film\n (film_id/film\n (id/g' \
       -e 's/inventory\n (inventory_id/inventory\n (id/g' \
       -e 's/customer\n (customer_id/customer\n (id/g' \
       -e 's/rental\n (rental_id/rental\n (id/g' \
       -e 's/payment\n (payment_id/payment\n (id/g' \
       -e 's/film_actor\n (act/film_actor\n (id,act/g' \
       -e 's/film_category\n (fil/film_category\n (id,fil/g' \
       sqlite-sakila-insert-data.sql > sakila-tmp.sql;
sed -i '1,46d' sakila-tmp.sql;
rm sakila-final.sql;
bb sql-gen.clj;
