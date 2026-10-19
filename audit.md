# Audit report — Tasky demo (fictional vibe-coded app)

**Date:** 2026-10-19 · **Brand:** Nyyo Automation  
**Scope:** `/before` (broken) vs `/after` (rescued)

| Check | Before | After |
|---|---|---|
| Secret / API key in HTML or JS | ❌ Fake key visible in DOM + JS | ✅ None |
| XSS via task input | ❌ `innerHTML` concatenates raw input | ✅ `textContent` / escape |
| Accessible name on controls | ❌ No labels | ✅ Label + aria-live list |
| Clear destructive action | ❌ Wipes all storage silently | ✅ Clears only app key |
| Mobile layout | ❌ Fixed comic styling | ✅ Responsive card |
| Console noise / key logging | ❌ Logs key | ✅ Quiet |

**Estimated Lighthouse-style notes (manual):** Before would fail Best Practices (secrets) and Accessibility. After is ship-ready for a static demo.

**Client deliverable pattern:** fix list + PR/diff + optional deploy to Pages/Vercel.
