-- ============================================================
-- 0033 — lower the upload cap to 5 MB across all buckets.
-- (Was 10 MB in 0032.) The client now auto-compresses oversized images
-- before upload (src/lib/validation.ts compressImage); PDFs over 5 MB are
-- rejected with a friendly message. MIME allowlist unchanged.
-- ============================================================

update storage.buckets
set file_size_limit = 5242880 -- 5 MB
where id in ('valid-ids', 'consignee-docs');
