import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  Easing,
} from "remotion";

/**
 * Pawgo Walking Dog
 * --------------------------------------------------------------------------
 * Side-profile illustrated walking dog. Loops in 30 frames @ 30fps = 1.0s
 * for one full stride. Inspired by the Dribbble references (Weekly Warm-up
 * #4 and Pet Playlist Frontline Spotify Basic Walk Cycle).
 *
 * Motion model:
 *   - Diagonal-pair walk: front-left + back-right move together; the other
 *     diagonal pair counter-phases.
 *   - Body bob — 2 bobs per stride (one per pair contact).
 *   - Tail wag — slow sine, period = stride.
 *   - Ear lag — small ear sway, phase-shifted 5 frames behind the body bob,
 *     so the ear "follows" the head with springy delay.
 *
 * Palette:
 *   Defaults to Pawgo brand (warmCaramel body, lighter belly, cacaoBrown
 *   ear, near-black nose). Override via props.
 */

export type WalkingDogProps = {
  bodyColor?: string; // body fill (warm tone)
  bellyColor?: string; // belly fill (lighter)
  earColor?: string; // ear fill (dark accent)
  noseColor?: string; // nose + eye fill
  shadowColor?: string; // ground shadow
  backgroundColor?: string; // canvas background
};

export const WalkingDog: React.FC<WalkingDogProps> = ({
  bodyColor = "#C07D4D", // AppColors.warmCaramel
  bellyColor = "#E8C9A6", // lighter warm
  earColor = "#4A2C2A", // AppColors.cacaoBrown
  noseColor = "#1A1A1A",
  shadowColor = "rgba(74, 44, 42, 0.18)",
  backgroundColor = "transparent",
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Normalized loop position 0..1
  const t = (frame % durationInFrames) / durationInFrames;

  // ---- Leg swing ---------------------------------------------------------
  // Front-left + back-right move together; front-right + back-left counter.
  // Easing.bezier gives a slightly weighted swing, more natural than pure sine.
  const swingAmplitude = 18; // degrees
  const legPhaseA = interpolate(
    Math.sin(t * Math.PI * 2),
    [-1, 1],
    [-swingAmplitude, swingAmplitude],
    {
      easing: Easing.bezier(0.5, 0, 0.5, 1),
    },
  );
  const legPhaseB = -legPhaseA;

  // ---- Body bob ----------------------------------------------------------
  // Two contact points per stride → two micro-bobs. Use abs(sin) to get a
  // bounce-up-and-settle motion. Amplitude in px.
  const bobAmplitude = 4;
  const bodyBob = -Math.abs(Math.sin(t * Math.PI * 2)) * bobAmplitude;

  // ---- Tail wag ----------------------------------------------------------
  // Period = 1 stride. Amplitude moderate.
  const tailAmplitude = 14; // degrees
  const tailRotation = Math.sin(t * Math.PI * 2) * tailAmplitude;

  // ---- Ear lag -----------------------------------------------------------
  // Ear follows the head bob with a small phase lag (≈ 5 frames behind).
  const earLag = 5 / durationInFrames;
  const earSway =
    Math.sin((t - earLag) * Math.PI * 2) * 6; // degrees

  // ---- Eye blink ---------------------------------------------------------
  // Occasional blink: closed during a tiny window each loop.
  const isBlinking = t > 0.92 && t < 0.97;

  return (
    <AbsoluteFill
      style={{
        backgroundColor,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <svg viewBox="0 0 400 400" width="400" height="400">
        {/* Ground shadow — narrows slightly when body lifts */}
        <ellipse
          cx="200"
          cy="330"
          rx={90 + bodyBob * 1.5}
          ry={9 + bodyBob * 0.3}
          fill={shadowColor}
        />

        {/* Everything that moves with the body bob */}
        <g transform={`translate(0, ${bodyBob})`}>
          {/* ---- Back legs (behind body) ---- */}
          {/* Back-left (the further leg, phase B) */}
          <g
            transform={`rotate(${legPhaseB} 145 248)`}
          >
            <rect
              x="138"
              y="248"
              width="14"
              height="60"
              rx="7"
              fill={bodyColor}
            />
            <ellipse cx="145" cy="312" rx="10" ry="5" fill={bodyColor} />
          </g>

          {/* Back-right (the nearer leg, phase A) */}
          <g
            transform={`rotate(${legPhaseA} 168 248)`}
          >
            <rect
              x="161"
              y="248"
              width="14"
              height="60"
              rx="7"
              fill={bodyColor}
            />
            <ellipse cx="168" cy="312" rx="10" ry="5" fill={bodyColor} />
          </g>

          {/* ---- Tail (behind body, anchored to body rear) ---- */}
          <g
            transform={`rotate(${tailRotation} 130 215)`}
          >
            <path
              d="M 130 215 Q 105 195 90 165"
              stroke={bodyColor}
              strokeWidth="12"
              strokeLinecap="round"
              fill="none"
            />
          </g>

          {/* ---- Body (rounded torso) ---- */}
          <ellipse cx="205" cy="225" rx="85" ry="42" fill={bodyColor} />

          {/* Belly patch (slightly lighter overlay) */}
          <ellipse cx="220" cy="245" rx="55" ry="20" fill={bellyColor} />

          {/* ---- Front legs (in front of body) ---- */}
          {/* Front-left (the further leg, phase B) */}
          <g
            transform={`rotate(${legPhaseB} 240 248)`}
          >
            <rect
              x="233"
              y="248"
              width="14"
              height="60"
              rx="7"
              fill={bodyColor}
            />
            <ellipse cx="240" cy="312" rx="10" ry="5" fill={bodyColor} />
          </g>

          {/* Front-right (the nearer leg, phase A) */}
          <g
            transform={`rotate(${legPhaseA} 263 248)`}
          >
            <rect
              x="256"
              y="248"
              width="14"
              height="60"
              rx="7"
              fill={bodyColor}
            />
            <ellipse cx="263" cy="312" rx="10" ry="5" fill={bodyColor} />
          </g>

          {/* ---- Head (facing right) ---- */}
          <g transform="translate(295, 178)">
            {/* Head silhouette */}
            <ellipse cx="0" cy="0" rx="42" ry="36" fill={bodyColor} />

            {/* Snout extension */}
            <ellipse cx="28" cy="6" rx="22" ry="18" fill={bodyColor} />

            {/* Ear (floppy, dark) — slightly behind head, lags body */}
            <g
              transform={`rotate(${earSway} -18 -8)`}
              style={{ transformBox: "fill-box" }}
            >
              <ellipse
                cx="-18"
                cy="14"
                rx="14"
                ry="28"
                fill={earColor}
              />
              {/* Inner ear highlight */}
              <ellipse
                cx="-18"
                cy="18"
                rx="6"
                ry="14"
                fill="#3A1F1E"
              />
            </g>

            {/* Eye */}
            {isBlinking ? (
              <line
                x1="6"
                y1="-8"
                x2="14"
                y2="-8"
                stroke={noseColor}
                strokeWidth="2"
                strokeLinecap="round"
              />
            ) : (
              <>
                <circle cx="10" cy="-8" r="3.5" fill={noseColor} />
                <circle cx="11" cy="-9" r="1" fill="#FFFFFF" />
              </>
            )}

            {/* Nose */}
            <ellipse cx="46" cy="2" rx="7" ry="5.5" fill={noseColor} />

            {/* Mouth — gentle smile */}
            <path
              d="M 32 16 Q 38 22 44 16"
              stroke={noseColor}
              strokeWidth="2"
              fill="none"
              strokeLinecap="round"
            />
          </g>
        </g>
      </svg>
    </AbsoluteFill>
  );
};
