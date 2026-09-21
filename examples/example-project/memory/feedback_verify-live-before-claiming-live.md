# Verify live before claiming live
<!-- Last updated: 2026-09-08 -->

**The lesson.** A change was reported as "deployed" when it was only committed; the server
still served the previous build for two days because the deploy script had not been run.

**Why:** the repository is evidence of intent, not of deployment. A reader who trusts the word
"deployed" stops checking.

**How to apply:** after any deploy, fetch the live file and compare its bytes to the built
one (`curl -s URL | cmp - dist/file`); write "deployed" only after the comparison passes, and
never follow redirects when verifying — a redirect to the homepage is a 200 too.
