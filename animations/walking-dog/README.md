# Pawgo Walking-Dog Loader

Side-profile illustrated walking-dog loop, used on `/finding-walkers` (the owner-onboarding loading screen). Authored in [Remotion](https://www.remotion.dev/) and exported to an optimized GIF that the Flutter app ships as an asset.

## Why Remotion + GIF (not Lottie)

- Remotion gives us React-based authoring with live preview — fast iteration on the walk cycle.
- Remotion has no native Lottie export; its output formats are MP4, WebM, GIF, and PNG sequences.
- GIF is the lightest runtime story for a single 1-second loop: Flutter's `Image.asset` plays animated GIFs natively, no extra dep, no playback runtime.
- After `gifsicle -O3 --colors 32 --lossy=30` the asset comes out around 65–70 kB at 200×200, which is fine for a one-time loader.

## Repository layout

```
animations/walking-dog/
├── src/
│   ├── Root.tsx              # Composition registrations
│   ├── WalkingDog.tsx        # The walk-cycle composition
│   ├── index.ts              # Entry point — registers <RemotionRoot />
│   └── index.css             # Empty (Remotion scaffold default)
├── out/                      # Render outputs — gitignored
└── package.json              # npm scripts (see below)
```

## One-time setup

```bash
cd animations/walking-dog
npm install
# Optional but recommended for the GIF post-processing step:
brew install gifsicle
```

## Preview the animation

```bash
npm run dev
# → Remotion Studio opens at http://localhost:3000
# Pick "WalkingDog" (or "WalkingDogGolden" / "WalkingDogSpotted" for palette previews)
```

Iterate on `src/WalkingDog.tsx` — the file is the source of truth for the motion model. See its module-level docstring for the model (diagonal-pair walk, body bob, tail wag, ear lag, blink).

## Re-export the GIF for Flutter

After any change to the composition, regenerate the asset:

```bash
npm run export-gif
```

This runs the Remotion render at 200×200 (via `--scale=0.5`) and then `gifsicle -O3 --colors 32 --lossy=30` to produce the optimized GIF. The optimized output is written **directly into `pawgo_flutter/lib/assets/animations/walking_dog.gif`** — so the next `flutter run` picks it up immediately.

If `gifsicle` isn't installed, you'll get the larger un-optimized GIF only; install it via `brew install gifsicle` for the size win.

## Composition parameters

The default Pawgo palette is baked into `WalkingDog`'s prop defaults:

| Prop           | Default     | Comment |
|----------------|-------------|---------|
| `bodyColor`    | `#C07D4D`   | AppColors.warmCaramel |
| `bellyColor`   | `#E8C9A6`   | lighter warm tone |
| `earColor`     | `#4A2C2A`   | AppColors.cacaoBrown |
| `noseColor`    | `#1A1A1A`   | near-black for nose/eye |
| `shadowColor`  | `rgba(74,44,42,0.18)` | soft brown ground shadow |
| `backgroundColor` | `transparent` | so the GIF blends with whatever loader bg is used |

Alternate palettes registered as separate compositions in `Root.tsx`:
- `WalkingDogGolden` — golden body, dark ear (style of Dribbble Weekly Warm-up #4)
- `WalkingDogSpotted` — white body, black ear (style of Dribbble Spotify Pet Playlist walk cycle)

To export an alternate palette, swap the composition id in the `export-gif` script.

## Flutter consumer

`pawgo_flutter/lib/widgets/walking_dog_animation.dart` is a thin `Image.asset` wrapper around the GIF. It respects `MediaQuery.disableAnimations` (reduce-motion) and falls back to `PawProgressIndicator` for users who've opted out of motion.
