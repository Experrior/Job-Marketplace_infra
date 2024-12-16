ALTER SYSTEM SET logging_collector = 'on';
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_directory = 'log';
ALTER SYSTEM SET log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log';
ALTER SYSTEM SET log_destination = 'stderr';
SELECT pg_reload_conf();