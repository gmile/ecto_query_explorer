with
records as (
  select 'queries' name, count(1) total_records from queries
  union
  select 'samples' name, count(1) total_records from samples
  union
  select 'functions' name, count(1) total_records from functions
  union
  select 'locations' name, count(1) total_records from locations
  union
  select 'stacktraces' name, count(1) total_records from stacktraces
  union
  select 'stacktrace_entries' name, count(1) total_records from stacktrace_entries
),
sizes as (
    select SUM(pgsize) bytes,
           name
      from dbstat
     where name in ('queries', 'samples', 'functions', 'locations', 'stacktrace_entries', 'stacktraces')
  group by name
)
  select r.name,
         total_records,
         bytes
    from records r
    join sizes s on s.name = r.name
order by bytes desc
