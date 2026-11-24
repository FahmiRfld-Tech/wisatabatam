# Release checklist — Hallo Batam AI

Scope: portfolio cleanup PR #3. The proposed changes organize assets and documentation and track the existing serverless source. No backend deployment or database changes are required by this PR.

## Verified evidence (November 24, 2026)

- The original cleanup commit `b2cc01719f4d0698c04296ebd846aba5234a0fec` passed [GitHub Actions](https://github.com/fahmifaldi61-tech/wisatabatam/actions/runs/45326952817) and the Vercel preview deployment check.
- The original frontend HTML and Vercel configuration retain the same Git blobs as main. All 46 public asset names and corresponding bytes were preserved by the move.
- The integration checker validated 69 destination/photo mappings (39 local, 30 remote).
- Read-only comparison against the active Supabase Edge Function confirmed version 31, identical index.ts content, equivalent deno.json (trailing whitespace only), and matching verify_jwt=false. The function uses custom session validation.
- The current database contents could not be rechecked due to a database authentication failure. The database counts in the historical audit are not current measurements.
- The superseded PR #2 was closed without deleting its branch or history.

## Required review before merge

- [ ] Check the newest PR commit, latest successful workflow, Vercel preview check and mergeability; the historical CI above does not automatically certify later commits.
- [ ] Open the [PR #3 preview](https://batamtes-git-refactor-portfolio-cleanup-fahmifaldi61-2558.vercel.app/) with authorized Vercel access. Public retrieval could not access the preview during this review.
- [ ] Check the homepage, navigation, destination cards, detail views, branding and both local/remote photos. Test a narrow mobile viewport and inspect the browser console for CSP or asset errors.
- [ ] In an authorized environment, check an Indonesian and English text question; confirm source links, destination image rendering, and a short itinerary response.
- [ ] With consent, check microphone capture, transcription and speech output. Do not use personal or sensitive audio.
- [ ] If the preview origin is not authorized by the existing backend CORS settings, use an already authorized test origin (such as local port 8000 if configured). Do not weaken CORS or modify live secrets merely for preview testing.
- [ ] Review photo redistribution rights separately; attribution alone is not a license.
- [ ] Approve the merge explicitly. Confirm the production Vercel root directory stays wisata_batam_project and record the previous successful deployment.

## Merge and post-merge

Use a reviewed merge commit or squash merge from PR #3 into main, with the checked head unchanged. The branch only tracks backend source; do not run any Supabase deployment commands as part of this merge.

After merging, check Vercel production deployment status and repeat the smoke checks at https://batamtes.vercel.app/. If a frontend regression occurs, use Vercel's previous known-good deployment or revert the merge via a separate reviewed PR. Do not roll back or overwrite the Supabase function solely because a frontend check fails.

Database migrations, full historical secret scanning, image licensing review and comprehensive end-to-end/load testing remain separate tasks.
