# SHADOW HUNTER — Business & Go-to-Market Plan
*Living plan, maintained by "the CEO." Sits alongside the design bible. Not financial or legal advice — where flagged, get a real professional.*

---

## 0. Honest positioning (read this first)
We have a working core loop on a real device and a clean, IP-safe design — further than most projects ever reach. But this is **pre-alpha**: no art, no UI polish, one gameplay layer of several, untested with players. **Revenue is realistically 4–8 months out.** The job is to get there without wasting our one first impression. We do not monetize a placeholder game.

## 1. The product, tagline & our edge
**Tagline (official):** **"Build your character by building your body."** Six words, two meanings, both true — captures the whole concept and bridges both audiences.
**Mission:** *Productive play — where progress in the game **is** progress in your life.* Nearly every game is time you'll wish you'd spent better; ours makes you better. Anti-escapism is the emotional hook, and a press-/creator-friendly story ("a game that's actually good for you") = free reach.
**The hook:** a Solo-Leveling-style fitness RPG where your real workouts level up your hunter.

**Dual audience — this is the edge; it doubles the market:**
- **A — "I'd rather game than train."** Self-improvers / gamers who know they should move. The game is a **motivation engine** that hijacks the reward loop they already love to make them healthier. *Message: "a game that levels up your real life."*
- **B — the heavy fitness crowd** (gym rats, runners, athletes). They already grind; they want it to **count and be respected**. Their Garmin already tracks it — we turn it into power. *Message: "the game that respects the grind you're already doing."* Our **"you can't buy strength — only training earns it"** rule is a **values-match with fitness culture** — a marketing weapon, not just a monetization line.

Most fitness games only catch Audience A. We catch both — and B are the most engaged, loyal users you can get. That combo is what nobody else owns, and it goes in *everything* we say and show.

## 2. Revenue model
Free-to-play with in-app purchases + optional ads. Non-predatory by design.
- **IAP — sell:** Essence (build acceleration), gate tickets (convenience), cosmetics.
- **Never sell:** EXP / hunter level — exercise-only. This is both our integrity and a marketing line ("you can't buy your way fit").
- **Rewarded ads (opt-in):** monetize free players who never spend (see §3).
- **Supporter / no-ads one-time purchase:** a cheap "remove ads + a cosmetic" pack — reliable indie revenue.

## 3. Rewarded ads — implementation & payment
**Money chain:** optional "watch for a reward" → ad network serves a video → advertiser pays network → network pays us.
**Implementation:**
1. Free **AdMob account**, linked to a **Google Payments/AdSense** profile (this is how we get paid).
2. Register app → create a **Rewarded ad unit** → get the ad-unit ID.
3. Add the **Poing Studios AdMob plugin for Godot** (Godot 4, Android, rewarded ads, GDScript, built-in **UMP/GDPR consent**). Slots into our existing native-plugin pipeline.
4. In-game: a "Watch for +Essence" button plays the video; on completion callback → grant reward.

**Getting paid:** revenue = impressions × **eCPM**; rewarded video has the highest eCPM (~$10–40+ tier-1). Need AdMob account + **tax info (W-8BEN if non-US)** + bank. AdMob pays **monthly once balance passes ~$100** (net-30-ish). **Mediation** later raises eCPM at volume.
**Rules:** opt-in only, never forced; **cap ~3–5/day**; rewards = Essence / ticket / small boost, never level. Disclose the ad SDK in privacy policy + Data Safety; keep **13+**; never pass health data to the ad SDK.
**Reality:** small per-user (pennies/DAU/day); meaningful only at volume, but passive and stacks on IAP.

## 4. Road to revenue (phases)
1. **Finish core gameplay** — the patches (grades → the Nadir → stationary play). *Weeks.*
2. **Art + UI pass** — the single biggest lever on whether anyone pays. Placeholder boxes convert nobody. Main investment of effort/money.
3. **Closed beta** — 20–100 real users from our niche. Find what's broken; measure **retention** (the whole ballgame).
4. **Soft launch** — 1–2 smaller English markets to test monetization/retention with real spend before global.
5. **Global launch + marketing push.**
6. **Live ops** — content, events, seasons. F2P earns over *years*, not at launch.

## 5. Pre-launch gates (non-negotiables)
- **Google Play Developer account** ($25 one-time). Android first (cheaper, matches our build). Apple ($99/yr) later.
- **Privacy policy + health-data compliance** (§27 of design bible) — a hard legal gate because we touch health data. **Lawyer review before launch.** CEO preps requirements; a professional signs off.
- **IAP wired** (Google Play Billing) + accurate **Play Data Safety** declaration + **AdMob UMP consent**.
- **Age-gate 13+** to avoid the minors/health-data + child-ad minefield.
- **Store listing + ASO** — title, icon, screenshots, trailer, keyword-optimized description. Screenshots are the #1 conversion driver → they wait for the art pass.

## 6. Go-to-market / marketing
Paid user-acquisition is a money-pit for solo devs — we don't play that early. Strategy = **build-in-public + community**:
- **Devlog content** (TikTok / Reels / YouTube Shorts): *"I'm building a Solo Leveling fitness game solo."* Inherently shareable; builds an audience *before* launch. Cheapest, highest-leverage channel. **Start now — long lead time.**
- **Communities:** anime-game + fitness-gaming spaces, r/gamedev, our own **Discord** for early fans/beta.
- **Landing page + email/waitlist:** convert hype into day-one installs.
- **ASO:** catch organic "fitness RPG / walking game" searches.
- **Micro-influencers** in the fitness-anime niche later > expensive ads.

## 7. Costs & funding (bootstrappable)
- Google Play $25 (one-time); Apple $99/yr (later).
- Infra: near-zero by design — OSM/PMTiles on Cloudflare R2 (~free maps), Supabase free tier for backend. Real bills only at real scale.
- Biggest "cost" is **time + the art pass** (DIY with AI tooling, or a modest commission).
- No outside funding needed to launch. Keep it lean.

## 8. Honest numbers & risks
- **Most indie mobile games make very little** — median near zero. No projections with a number on them; anyone who gives you one is guessing.
- Success needs: (a) it **looks good**, (b) real **retention**, (c) an **audience we build ourselves**. Our niche + build-in-public give a genuine shot, but it's earned.
- **Top risks:** retention (do they come back?), the **art bar** (mobile is visual-first), **health-data compliance**.
- When revenue arrives: **get an accountant** (tax/entity). Consider a simple business entity before you're taking real money.

## 9. Immediate priorities — longest-lead-time first
*(Start these now, in parallel with dev — they can't be rushed later.)*
1. **Build-in-public content — START THIS WEEK.** Audiences take months to grow; the clock starts the day you post. Even rough behind-the-scenes clips. **#1 highest-leverage, longest-lead move.**
2. **Stand up a landing page + email waitlist + Discord** to capture the interest that content generates.
3. **Begin compliance/privacy-policy work + register the Google Play dev account** — bureaucratic lead time; start early.
4. **Lock art direction & plan the art pass** — the make-or-break for monetization.
5. **Keep shipping gameplay patches** (already in a good rhythm — don't stop).

## 10. Live checklist (tick as we go)
- [ ] Pick channels + post first build-in-public clip
- [ ] Landing page live with email capture
- [ ] Discord server created
- [ ] Google Play developer account registered
- [ ] Privacy policy drafted → lawyer review booked
- [ ] Art direction locked; art-pass plan
- [ ] AdMob account + rewarded-ads plugin integrated (test mode)
- [ ] IAP catalogue defined + Google Play Billing wired
- [ ] Closed beta group recruited
- [ ] Store listing assets (needs art) drafted

---
*Sequence everything behind the art pass except the longest-lead items in §9 — those start today.*
