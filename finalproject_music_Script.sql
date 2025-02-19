-- create the dim_playlist table, with the relevant columns:
create table Dim_playlist(
playlist_id INT not null,
playlist_name VARCHAR(255) not null,
track_id INT not null,
last_update date,
primary key(playlist_id, track_id)
);

-- insert data from the stg tables into Dim_playlist table:
insert into dim_playlist (playlist_id, playlist_name, track_id, last_update)
select
	pt.playlistid as playlist_id,
	p."name" as playlist_name,
	pt.trackid,
	pt.last_update
from stg.playlisttrack as pt
left join stg.playlist as p -- using left join in order to load only the playlists that have relevant data for them on the stg.playlistttrack table, empty playlist won't load
	on pt.playlistid = p.playlistid
;

-- checking the table consists all 14 relavant playlists (4 playlists didn't load because of join type):
select playlist_id, playlist_name, count(track_id)
from dwh.dim_playlist
group by playlist_id, playlist_name
order by playlist_id asc
;

-- delete duplicated playlists (music & TV shows):
delete from dim_playlist
where playlist_id in (8, 10)
;

-- clear all the data if needed:
delete from dim_playlist
;

-- delete the table if needed:
drop table dim_playlist
;

-- fetch the table:
select *
from dim_playlist
;
------------------------------------------------------------------------------------------------------------------

-- create the Dim_customer table, using the stg customer table structure + extra column according to client request:
create table dwh.Dim_customer (
								like stg.customer including all, 
								email_domain varchar(255)
								)
;

-- insert data from the stg table into Dim_customer table:
insert into Dim_customer
select *
from stg.customer
;

-- update the table according to client request:
update Dim_customer
set email_domain = substring(email, position('@' in email)),
firstname = upper(left(firstname, 1)) || lower(substring(firstname, 2)),
lastname = upper(left(lastname, 1)) || lower(substring(lastname, 2))
;

-- fetch the table:
select *
from dwh.Dim_customer
;


-- clear the data if needed:
delete from Dim_customer;

-- delete the table if needed:
drop table Dim_customer;

---------------------------------------------------------------------------------------------------------------------

-- create the Dim_employee table, using the stg employee table structure + extra columns according to client request:
create table dwh.Dim_employee (
								like stg.employee including all, 
								department_name varchar(255),
								department_budget int,
								years_employed varchar(255),
								is_manager int,
								email_domain varchar(255)
								)
;

-- insert data from the stg tables into Dim_employee table:
insert into Dim_employee
select e.*,
		d.department_name,
		d.budget as department_budget
from stg.employee as e
left join stg.department as d
	on d.department_id = e.departmentid 
;

-- update the table according to client request:
update Dim_employee
set email_domain = substring(email, position('@' in email)),
years_employed = extract(year from age(now(), hiredate)),
is_manager = case 
	when employeeid in (select distinct reportsto from stg.employee) then 1
	else 0
end
;

-- fetch the table:
select *
from Dim_employee
;


-- clear the data if needed:
delete from Dim_employee;

-- delete the table if needed:
drop table Dim_employee;

----------------------------------------------------------------------------------------------------------------------------

CREATE TABLE dim_track (
  trackid INT PRIMARY KEY,
  track_name VARCHAR(255) NOT NULL,
  albumid INT,
  mediatypeid INT,
  mediatype_name VARCHAR(255),
  last_update DATE,
  genreid INT,
  genre_last_update DATE,
  composer VARCHAR(255),
  unitprice INT,
  mediatype_last_update DATE,
  seconds INT,
  track_duration VARCHAR(5) NOT NULL,  -- Ensure format is always MM:SS
  genre_name VARCHAR(255),
  album_name VARCHAR(255),
  album_last_update DATE,
  artistid INT,
  artist_name VARCHAR(255),
  artist_last_update DATE
);

INSERT INTO dim_track (
  trackid,
  track_name,
  albumid,
  mediatypeid,
  mediatype_name,
  last_update,
  genreid,
  genre_last_update,
  composer,
  mediatype_last_update,
  seconds,
  track_duration,
  genre_name,
  album_name,
  album_last_update,
  artistid,
  artist_name,
  artist_last_update
)
select t.trackid,
       t.name as track_name,
       a.albumid,
       m.mediatypeid,
       m.name as mediatype_name,
       t.last_update,
       g.genreid,
       g.last_update,
       t.composer,
       m.last_update,
       t.milliseconds / 1000 as seconds,
       CONCAT(
        RIGHT('0' || FLOOR(t.milliseconds / 1000 / 60), 2),
        ':',
        RIGHT('0' || MOD(t.milliseconds / 1000, 60), 2)
       ) AS track_duration,
       g.name as ganre_name,
       a.title  as album_name,
       a.last_update,
       art.artistid,
       art."name" as artist_name,
       art.last_update 
from stg.track t 
  left join stg.genre g 
   on t.genreid  = g.genreid 
  left join stg.mediatype m 
   on t.mediatypeid  = m.mediatypeid 
  left join stg.album a
   on t.albumid  = a.albumid
  left join stg.artist art 
   on a.artistid  = art.artistid
 ;
 

alter table dwh.dim_track
add column unitprice decimal(10, 2)
;
update dwh.dim_track
set unitprice = st.unitprice
from stg.track st
where dim_track.trackid = st.trackid
;


select *
from dwh.dim_track dt 

select *
from stg.track t 

--2 סיבות למה להביא את השדות של הכתובת :
--1: אינדיקציה נוספת בתוך החשבונית, לדעת מאיפה שולם
--2: הבאת השדות של הכתובת תעזור לי לבצע אנליזה מול טבלת customers


-- delete the table if needed:
drop table public.fact_invoice;

---------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE dwh.fact_invoice (
  invoiceid INT PRIMARY KEY,
  customerid INT,
  invoicedate DATE,
  billingaddress VARCHAR(70),
  billingcity VARCHAR(40),
  billingstate VARCHAR(40),
  billingcountry VARCHAR(40),
  billingpostalcode VARCHAR(10),
  total NUMERIC(10,2),
  last_update DATE
);
insert into fact_invoice (
invoiceid,
customerid,
invoicedate,
billingaddress,
billingcity,
billingstate,
billingcountry,
billingpostalcode,
total,
last_update
)
SELECT
  i.invoiceid AS invoiceid,
  i.customerid AS customerid,
  i.invoicedate AS invoicedate,
  i.billingaddress AS billingaddress,
  i.billingcity AS billingcity,
  i.billingstate AS billingstate,
  i.billingcountry AS billingcountry,
  i.billingpostalcode AS billingpostalcode,
  i.total AS total,
  i.last_update AS last_update
FROM stg.invoice i
;

select *
from dwh.fact_invoice fi 
;



select *
from fact_invoice fi 
;


----------------------------------------------------------------------------------------------------------------
CREATE TABLE dwh.fact_invoiceline (
    invoiceline_id INT PRIMARY KEY,
    invoice_id INT,
    track_id INT,
    unitprice DECIMAL(10,2),
    quantity INT,
    last_update DATE,
    line_total DECIMAL(10,2)
)
;

INSERT INTO dwh.fact_invoiceline 
	select il.*,
    	i.total as line_total
FROM stg.invoiceline il
left join stg.invoice i
	on il.invoiceid = i.invoiceid
;

-- fetch the table:
select *
from dwh.fact_invoiceline
;


-- clear the data if needed:
delete from dwh.fact_invoiceline;

-- delete the table if needed:
drop table dwh.fact_invoiceline;
------------------------------------------------------------------------------------------------------

-- create the Dim_currencies table, using the stg currencies table structure:
create table dwh.Dim_currencies (like stg.currencies including all)
;

-- insert data from the stg table into Dim_currencies table:
insert into Dim_currencies
select *
from stg.currencies
;


-- fetch the table:
select *
from dwh.Dim_currencies
;

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- SQL ANALYSIS:

-- fetch the number of tracks on the playlist with the most tracks on it, the playlist with the least tracks on it + the average amount of tracks on a playlist: 
with PlaylistTrackCounts as (
  select
        playlist_name,
        COUNT(track_id) as total_tracks
    from dwh.dim_playlist dp
    group by playlist_name
    )
select
	max(total_tracks) as max_tracks_plalist,
    min(total_tracks) as min_tracks_plalist,
	(
	select avg(total_tracks) as avg_tracks_on_playlist 
	from PlaylistTrackCounts 
	)
from PlaylistTrackCounts


---- we were asked to find the max&mun playlists, not their tracks count:
(
with PlaylistTrackCounts as (
  select
        playlist_name,
        COUNT(track_id) as total_tracks
    from dwh.dim_playlist dp
    group by playlist_name
    )
	select
        playlist_name,
        COUNT(track_id) as total_tracks,
        (
		select round(avg(total_tracks),2) as avg_tracks_on_playlist 
		from PlaylistTrackCounts 
		)
    from dwh.dim_playlist dp
    group by playlist_name
    order by COUNT(track_id)
    limit 2
    )
union all
(
with PlaylistTrackCounts as (
  select
        playlist_name,
        COUNT(track_id) as total_tracks
    from dwh.dim_playlist dp
    group by playlist_name
    )
	select
        playlist_name,
        COUNT(track_id) as total_tracks,
        (
		select round(avg(total_tracks),2) as avg_tracks_on_playlist 
		from PlaylistTrackCounts 
		)
    from dwh.dim_playlist dp
    group by playlist_name
    order by COUNT(track_id) desc
    limit 1
	)
	

-- fetch 4 quarters of sales + show total amount of sales in each quarter:
with sales_quarters as (
select
	case
		when count(fil.track_id) >= 10 then 1
		when count(fil.track_id) in (5, 6, 7, 8 ,9) then 2
		when count(fil.track_id) in (1, 2, 3, 4) then 3
		else 4
	end as track_sales_quarter,
	trackid
from dwh.dim_track dt 
left join dwh.fact_invoiceline fil on fil.track_id = dt.trackid
group by trackid
)
select
	track_sales_quarter,
	count(trackid) as total_tracks_per_quartr
from sales_quarters
group by track_sales_quarter
order by track_sales_quarter
;


-- showing total revenue of sales from each of the 5 top & bottom countries:
(
select
	'Top' as country_tier,
	billingcountry as country,
	sum(total) as total_revenue
from fact_invoice fi
group by billingcountry 
order by total_revenue desc
limit 5
)
union all
(
select
	'Bottom' as country_tier,
	billingcountry as country,
	sum(total) as total_revenue
from fact_invoice fi
group by billingcountry 
order by total_revenue asc
limit 5
)


-- showing genre split for each of the former countries + sales precentege per genre from total sales of the country:
with top_bottom_countries as (
	(select
		'Top' as country_tier,
		billingcountry as country,
		sum(total) as total_revenue
	from dwh.fact_invoice fi
	group by billingcountry 
	order by total_revenue desc
	limit 5)
	union all
	(select
		'Bottom' as country_tier,
		billingcountry as country,
		sum(total) as total_revenue
	from dwh.fact_invoice fi
	group by billingcountry 
	order by total_revenue asc
	limit 5)
	)
,genre_rev as (
	select 
		tbc.country,
		tbc.total_revenue, 
		dt.genre_name,
		sum(fil.unitprice) over (partition by tbc.country, dt.genre_name) as total_rev_per_genre -- sum calculation made on unitprice so there won't be no duplications
	from top_bottom_countries tbc
	left join dwh.fact_invoice fi
		on fi.billingcountry = tbc.country
	left join dwh.fact_invoiceline fil
		on fil.invoice_id = fi.invoiceid
	left join dwh.dim_track dt
		on dt.trackid = fil.track_id
	order by total_revenue desc, genre_name
	)
, final_tab as (
select
	country,
	dense_rank() over (partition by country order by (total_rev_per_genre * 100 / total_revenue)) as rank_by_presentege,
	genre_name,
	round((total_rev_per_genre * 100 / total_revenue), 2)||'%' as presentege_from_total_country_rev
from genre_rev
)
select *
from final_tab
group by
	rank_by_presentege,
	country,
	genre_name,
	presentege_from_total_country_rev
order by
	country,
	rank_by_presentege	


-- showing total customers, avg orders per customer, avg revenue per customer - for each country.
-- using multiple CTE queries we combine all countries with only one customer into one row on which the above calculations are performed.
(
with basic_country_pop as (
							select
								country,
								count(distinct dc.customerid) as total_customers,
								count(fi.invoiceid) as total_orders_per_country,
								sum(fi.total) as total_revenue_per_country
							from dwh.dim_customer dc
							left join dwh.fact_invoice fi
								on fi.customerid = dc.customerid
							group by country
							having count(distinct dc.customerid) > 1
							order by country
								)
select
	country,
	total_customers,
	total_orders_per_country / total_customers as avg_orders_per_customer,
	round((total_revenue_per_country / total_customers), 2) as avg_revenue_per_customer
from basic_country_pop
)
union all
(
with basic_country_pop as (
							select
								country,
								count(distinct dc.customerid) as total_customers_per_country,
								count(fi.invoiceid) as total_orders_per_country,
								sum(fi.total) as total_revenue_per_country
							from dwh.dim_customer dc
							left join dwh.fact_invoice fi
								on fi.customerid = dc.customerid
							group by country
							having count(distinct dc.customerid) = 1
							order by country
								)
, country_sum as (
select
	'Other' as country,
	sum(total_customers_per_country) as total_customers,
	sum(total_orders_per_country) as total_orders,
	sum(total_revenue_per_country) as total_revenue
from basic_country_pop
)
select
	country,
	total_customers,
	floor(total_orders / total_customers) as avg_orders_per_customer,
	round((total_revenue / total_customers), 2) as avg_revenue_per_customer
from country_sum
)
	
	
-- showing seniority, total customers served per year, and growth precentege of sales - for each employee.
with basic_employee_pop as (
	select
		employeeid,
		de.firstname||' '||de.lastname as name,
		years_employed,
		extract(year from invoicedate) as year,
		count(dc.customerid) as total_customers_served_per_year,
		sum(fi.total) as total_rev
	from dim_employee de
	left join dim_customer dc
		on dc.supportrepid = de.employeeid
	left join fact_invoice fi
		on fi.customerid = dc.customerid
	group by 
		employeeid,
		de.firstname||' '||de.lastname,
		years_employed,
		extract(year from invoicedate)
	order by employeeid, extract(year from invoicedate)
)
, last_year_total as (
						select *,
							lag(total_rev) over (partition by employeeid) as last_year_rev
						from basic_employee_pop
						)
select employeeid,
		name,
		years_employed,
		year,
		total_customers_served_per_year,
		round(((total_rev - last_year_rev) *100 / last_year_rev), 2)||'%' as growth_percentege
from last_year_total


-- extra analisys - (playlist breakdown) percentege of selling tracks from playlists, top genre on playlist & main media type featured on playlist.
with playlist_genres as ( 	-- fetch top genre per playlist
						select *
						from (
								select
									dp.playlist_name,
									dt.genre_name,
									count(dt.genre_name) as genres_count,
									rank() over (partition by dp.playlist_name order by count(dt.genre_name) desc) as genre_rank
								from dwh.dim_playlist dp
								left join dwh.dim_track dt on dp.track_id = dt.trackid
								group by dp.playlist_name, dt.genre_name
								order by dp.playlist_name, genres_count desc
							) as basic_pop
						where genre_rank = 1
						),
playlist_media_type as (	-- fetch main media type per playlist
						select *
						from (
								select
									dp.playlist_name,
									dt.mediatype_name,
									count(dt.mediatype_name) as mediatype_count,
									rank() over (partition by dp.playlist_name order by count(dt.mediatype_name) desc) as media_rank
								from dwh.dim_playlist dp
								left join dwh.dim_track dt on dp.track_id = dt.trackid
								group by dp.playlist_name, dt.mediatype_name
								order by dp.playlist_name, mediatype_count desc
							) as basic_pop
						where media_rank = 1
						),
playlist_sales as (		-- calculates persentege of sold tracks per playlist
	select
		dp.playlist_name,
		count(fil.track_id) * 100 / count(dp.track_id)||'%' as percentege_of_sold_tracks
	from dwh.dim_playlist dp
	left join dwh.fact_invoiceline fil
		on dp.track_id = fil.track_id
	group by dp.playlist_name
	order by count(fil.track_id) * 100 / count(dp.track_id) desc
)
select		-- combining data from all 3 CTEs to fetch playlist breakdown
	ps.playlist_name,
	ps.percentege_of_sold_tracks,
	pg.genre_name as top_genre_on_playlist,
	pmt.mediatype_name as main_media_type_on_playlist
from playlist_sales ps
join playlist_genres pg
	on ps.playlist_name = pg.playlist_name
join playlist_media_type pmt
	on ps.playlist_name = pmt.playlist_name
