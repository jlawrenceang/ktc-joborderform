# Seed-data import templates

Fill these CSVs and import them with the matching script. Both importers are
**re-runnable** (safe to import the same file twice).

> Run the scripts from the repo root; they read `DATABASE_URL` from `.env.local`
> automatically only if you export it — otherwise pass it inline (session pooler
> `:5432`, or transaction pooler `:6543` for large files).

## 1. Consignees — `consignees-template.csv`

The master list customers pick from when filing a Job Order.

| column | required | notes |
|---|---|---|
| `name` | ✅ | the consignee/company name (dedup is by name, case-insensitive) |
| `code` | optional | leave **blank** to auto-generate `CN-#####`; or set your own (must be unique) |

Import:

```
DATABASE_URL="postgresql://...:6543/postgres" node scripts/import-consignees.mjs "C:/path/consignees.csv"
```

(Address / TIN / approval status also exist on the table but are managed later
in the admin **Consignees** screen — the quick importer loads name + code. Ask
if you want those columns loaded from the CSV too.)

## 2. Vessel schedule — `vessel-schedule-template.csv`

The vessel/voyage list operations monitors and customers reference.

| column | required | notes |
|---|---|---|
| `vessel_visit` | ✅ | unique key (a re-import updates the matching visit) |
| `vessel_name` | ✅ | |
| `voyage_number` | ✅ | |
| `shipping_line` | optional | |
| `actual_arrival` | optional | date `YYYY-MM-DD` |
| `finish_discharging` | optional | date `YYYY-MM-DD` (drives import free-storage timing) |
| `berth` | optional | |
| `remarks` | optional | |

Import:

```
DATABASE_URL="postgresql://...:6543/postgres" node scripts/import-vessels.mjs "C:/path/vessels.csv"
```

Delete the `SAMPLE …` rows before importing.
