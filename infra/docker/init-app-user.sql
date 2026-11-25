-- Crea el rol de aplicación sin privilegios de SUPERUSER para desarrollo local.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vecinda_app') THEN
        CREATE ROLE vecinda_app
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            PASSWORD 'vecinda_app_local_pass';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE vecinda_dev TO vecinda_app;
GRANT USAGE ON SCHEMA public TO vecinda_app;
ALTER DEFAULT PRIVILEGES FOR ROLE vecinda_admin IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vecinda_app;
ALTER DEFAULT PRIVILEGES FOR ROLE vecinda_admin IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO vecinda_app;
