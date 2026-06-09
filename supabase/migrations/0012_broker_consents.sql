-- 0012_broker_consents.sql
-- Record the broker's Terms & Conditions acceptance and Data Privacy Act consent
-- captured at registration (version + timestamp). Like 0011, acceptance is also
-- written to auth user metadata at sign-up; these columns make it queryable.

alter table public.brokers add column if not exists terms_version text;
alter table public.brokers add column if not exists terms_accepted_at timestamptz;
alter table public.brokers add column if not exists privacy_consent_version text;
alter table public.brokers add column if not exists privacy_consented_at timestamptz;

comment on column public.brokers.terms_version is 'Terms & Conditions version the broker agreed to at registration.';
comment on column public.brokers.terms_accepted_at is 'Timestamp the broker accepted the Terms & Conditions.';
comment on column public.brokers.privacy_consent_version is 'Privacy Notice version the broker consented to (Data Privacy Act of 2012).';
comment on column public.brokers.privacy_consented_at is 'Timestamp the broker gave data-privacy consent.';
