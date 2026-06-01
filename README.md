# ChroniQ

ChroniQ is a precision timing game where you stop the timer as close as possible to a hidden target. It blends clean neon UI, high‑pressure audio feedback, and multiple game modes to test timing accuracy.

## Core Gameplay

- A target time is generated (1.00–9.99 seconds, excluding .00 and .50).
- You start a countdown, then tap to stop the timer.
- Your result is graded by precision tier and visual feedback.

## Game Modes

- **Precision (Solo):** Single‑player timing challenge with escalating heartbeat feedback.
- **Battle (Local Pass‑and‑Play):** 2–4 players take turns; results are ranked by precision.
- **Online (Simulated Matchmaking):** Fake matchmaking, bot lobby chat, and a round against AI players.
- **Daily Challenge:** One attempt per day with a deterministic target and a fake global leaderboard.

## Scoring & Progression

- **Precision tiers:** GODLIKE → PERFECT → GREAT → GOOD → OK → BAD based on absolute error.
- **Ranks:** Bronze → Silver → Gold → Diamond → Master → Chrono God based on average precision.
- **Stats:** Total games, best precision, streaks, and accuracy history.
- **Abilities:** Unlockable focus abilities tied to rank.

## Visual & Audio Features

- Neon cyber UI theme with custom glow components.
- Heartbeat audio that accelerates as you approach the target.
- Reveal animations with tier cards, timeline replay, and battle/online leaderboards.
- Optional video background on the main menu.

## Tech Stack

- **Flutter** (Dart)
- **SharedPreferences** for local storage
- **audioplayers** for procedural audio tones
- **fl_chart** for profile charts
- **video_player** for menu background video

## Project Structure

- `lib/screens/` — UI for all modes and flows
- `lib/models/` — Game result, ranks, bot definitions
- `lib/services/` — Storage, audio, bot logic
- `lib/widgets/` — Reusable UI components
- `lib/utils/` — Target time generation and daily seed

## Setup

1. Install Flutter SDK.
2. Fetch dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Assets

- `assets/bg_video.mp4` — Menu background video (optional).

## Notes

- iOS builds require CocoaPods (`pod install` in the `ios/` folder) after dependency changes.
- The “Online” mode is simulated with AI bots and fake matchmaking.
