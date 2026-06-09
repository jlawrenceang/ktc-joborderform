-- 0011_broker_irr_acceptance.sql
-- Record that a broker accepted the IRR at registration: which version, and when.
-- Acceptance is also written to auth user metadata at sign-up (works without this
-- migration); these columns make it queryable from the admin side.

alter table public.brokers add column if not exists irr_version text;
alter table public.brokers add column if not exists irr_accepted_at timestamptz;

comment on column public.brokers.irr_version is 'IRR version the broker agreed to at registration (e.g. v1).';
comment on column public.brokers.irr_accepted_at is 'Timestamp the broker accepted the IRR.';
