-- ============================================================
-- Isolate uploaded attachments (slips/invoices) per club
-- Run this ONCE in the SQL Editor, after the multi-club migration.
--
-- Attachments are now uploaded to a path like:
--   <club_id>/1720000000000_receipt.pdf
-- This replaces the old "any signed-in user can touch any file"
-- policies with ones that check the folder name matches a club
-- the signed-in user actually belongs to.
-- ============================================================

drop policy if exists "Allow authenticated uploads to receipts" on storage.objects;
drop policy if exists "Allow authenticated read of receipts" on storage.objects;
drop policy if exists "Allow authenticated delete of receipts" on storage.objects;

create policy "Club members can upload their own club's receipts"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1]::uuid in (
    select club_id from club_members where user_id = auth.uid()
  )
);

create policy "Club members can list/read their own club's receipts"
on storage.objects for select
to authenticated
using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1]::uuid in (
    select club_id from club_members where user_id = auth.uid()
  )
);

create policy "Club members can delete their own club's receipts"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1]::uuid in (
    select club_id from club_members where user_id = auth.uid()
  )
);

-- ============================================================
-- IMPORTANT — one manual step for Fish Hoek's EXISTING attachments
-- ============================================================
-- Any files uploaded before this change live at the bucket's root
-- (no club folder), so the new policies above won't match them —
-- they'll effectively become inaccessible through the app.
--
-- To fix this, move Fish Hoek's existing files into their folder:
-- 1. Go to Storage → receipts in the Supabase dashboard
-- 2. Note the file names sitting at the top level (not in a folder)
-- 3. Run this to find Fish Hoek's club_id:
--      select id from clubs where slug = 'fish-hoek';
-- 4. For each existing file, use the Storage UI to move/rename it
--    into a folder named after that club_id, e.g. drag
--    "1720000000000_receipt.pdf" into a new folder called
--    "<that-uuid>" so its new path becomes
--    "<that-uuid>/1720000000000_receipt.pdf"
--
-- If there are only a handful of files, this only takes a minute
-- via drag-and-drop in the dashboard's Storage browser. If you'd
-- rather not deal with this right now, it's low-risk to leave for
-- later — those specific old attachment links will just stop
-- opening until moved, everything else keeps working.
-- ============================================================

-- ============================================================
-- Note on the bucket's public setting
-- ============================================================
-- The "receipts" bucket is still marked as a public bucket. This
-- means the RLS policies above control uploading, listing, and
-- deleting through the app — but anyone who already has the exact,
-- long, random URL to a specific file could still open it directly,
-- signed out entirely, bypassing these rules. This is a low-risk,
-- "obscure link" style exposure (URLs aren't guessable or listed
-- anywhere public), not an open directory. If you want this closed
-- completely too, the bucket would need to switch to private with
-- expiring signed links — a bigger change, since every place that
-- currently shows a permanent attachment link would need to fetch a
-- fresh temporary one instead. Let Claude know if you'd like that
-- done as a follow-up.
-- ============================================================
