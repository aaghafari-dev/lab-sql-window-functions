-- 			Challenge 1
# 1- Rank films by their length and create an output table that includes the title, length, and rank columns only. 
#			Filter out any rows with null or zero values in the length column.

		USE Sakila;

		SELECT 
			title,
			length,
			RANK() OVER (ORDER BY length DESC) AS ranking
		FROM film
        WHERE length IS NOT NULL 
			AND length > 0
		ORDER BY ranking;

# 2- Rank films by length within the rating category and create an output table that includes the title, length, 
#	rating and rank columns only. Filter out any rows with null or zero values in the length column.
		SELECT 
			title,
			length,
			rating,
			RANK() OVER (
				PARTITION BY rating 
				ORDER BY length DESC
			) AS ranking
		FROM film
		WHERE length IS NOT NULL 
			AND length > 0
		ORDER BY rating, ranking;

# 3- Produce a list that shows for each film in the Sakila database, the actor or actress who has acted in 
#	the greatest number of films, as well as the total number of films in which they have acted. 
#	Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.

		
		WITH actor_film_counts AS (
			SELECT 
				fa.actor_id,
				a.first_name,
				a.last_name,
				COUNT(fa.film_id) AS film_count
			FROM film_actor fa
			JOIN actor a ON fa.actor_id = a.actor_id
			GROUP BY fa.actor_id, a.first_name, a.last_name
		),
		film_actor_ranks AS (
			SELECT 
				f.film_id,
				f.title,
				fa.actor_id,
				afc.first_name,
				afc.last_name,
				afc.film_count,
				RANK() OVER (
					PARTITION BY f.film_id 
					ORDER BY afc.film_count DESC
				) AS actor_rank
			FROM film f
			JOIN film_actor fa ON f.film_id = fa.film_id
			JOIN actor_film_counts afc ON fa.actor_id = afc.actor_id
		)
		SELECT 
			title AS film_title,
			CONCAT(first_name, ' ', last_name) AS top_actor,
			film_count AS films_acted_in
		FROM film_actor_ranks
		WHERE actor_rank = 1
		ORDER BY film_count DESC, title;


-- 					Challenge 2

# Step 1. Retrieve the number of monthly active customers, i.e., the number of unique customers who rented a movie in each month.
   
		WITH monthly_active_customers AS (
			SELECT 
				DATE_FORMAT(rental_date, '%Y-%m') AS activity_month, 
				COUNT(DISTINCT customer_id) AS active_customers
			FROM rental
			GROUP BY DATE_FORMAT(rental_date, '%Y-%m')
		)
		SELECT 
			activity_month,
			active_customers
		FROM monthly_active_customers
		ORDER BY activity_month;
# Step 2. Retrieve the number of active users in the previous month.
		
		WITH monthly_customers AS (
			SELECT 
				DATE_FORMAT(rental_date, '%Y-%m') AS month,
				COUNT(DISTINCT customer_id) AS active_customers
			FROM rental
			GROUP BY DATE_FORMAT(rental_date, '%Y-%m')
		)
		SELECT 
			month,
			active_customers,
			LAG(active_customers) OVER (ORDER BY month) AS prev_month_active
		FROM monthly_customers;

# Step 3. Calculate the percentage change in the number of active customers between the current and previous month.


		WITH monthly_active_customers AS (
			SELECT 
				DATE_FORMAT(rental_date, '%Y-%m') AS activity_month,
				COUNT(DISTINCT customer_id) AS active_customers
			FROM rental
			GROUP BY DATE_FORMAT(rental_date, '%Y-%m')
		),
		monthly_comparison AS (
			SELECT 
				activity_month,
				active_customers,
				LAG(active_customers) OVER (ORDER BY activity_month) AS previous_month_active
			FROM monthly_active_customers
		)
		SELECT 
			activity_month,
			active_customers,
			previous_month_active,
			ROUND(
				((active_customers - previous_month_active) * 100.0 / 
				NULLIF(previous_month_active, 0)), 
				2
			) AS percentage_change
		FROM monthly_comparison
		ORDER BY activity_month;

# Step 4. Calculate the number of retained customers every month, i.e., customers who rented movies in the current and previous months.

-- Step 4: Retained customers each month
		WITH customer_monthly_activity AS (
			SELECT 
				customer_id,
				DATE_FORMAT(rental_date, '%Y-%m') AS activity_month
			FROM rental
			GROUP BY customer_id, DATE_FORMAT(rental_date, '%Y-%m')
		),
		retained_customers AS (
			SELECT 
				cma1.activity_month AS current_month,
				COUNT(DISTINCT cma1.customer_id) AS retained_customers_count
			FROM customer_monthly_activity cma1
			JOIN customer_monthly_activity cma2 ON cma1.customer_id = cma2.customer_id
			WHERE cma2.activity_month = DATE_FORMAT(
				DATE_SUB(STR_TO_DATE(CONCAT(cma1.activity_month, '-01'), '%Y-%m-%d'), 
				INTERVAL 1 MONTH), 
				'%Y-%m'
			)
			GROUP BY cma1.activity_month
		),
		all_months AS (
			SELECT DISTINCT 
				DATE_FORMAT(rental_date, '%Y-%m') AS activity_month
			FROM rental
			ORDER BY activity_month
		)
		SELECT 
			am.activity_month,
			COALESCE(rc.retained_customers_count, 0) AS retained_customers
		FROM all_months am
		LEFT JOIN retained_customers rc ON am.activity_month = rc.current_month
		ORDER BY am.activity_month;
