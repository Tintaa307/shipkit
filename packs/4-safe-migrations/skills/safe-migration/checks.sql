-- Post-migration checks (run against the TEST database).
-- Replace <table> and <function> with the objects in the migration.

-- 1. RLS is on for new or touched tables.
select relname, relrowsecurity as rls
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in ('<table>');

-- 2. Grants per role: anon and authenticated only get what is needed.
select grantee, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public' and table_name = '<table>'
group by grantee
order by grantee;

-- 3. Policies on the table.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = '<table>';

-- 4. Functions: security definer, fixed search_path and who can execute them.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       p.proconfig as config,
       has_function_privilege('anon', p.oid, 'execute') as anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('<function>');

-- 5. Foreign keys to a tenant table without an explicit on delete (confdeltype 'a' = no action).
-- Replace public.organizations with your tenant table.
select conname, conrelid::regclass as table_name
from pg_constraint
where contype = 'f'
  and confrelid = 'public.organizations'::regclass
  and confdeltype = 'a';
