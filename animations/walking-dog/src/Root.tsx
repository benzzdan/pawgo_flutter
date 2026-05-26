import "./index.css";
import { Composition } from "remotion";
import { WalkingDog } from "./WalkingDog";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="WalkingDog"
        component={WalkingDog}
        // 30 frames @ 30fps = 1.0s per stride. The exported GIF loops natively.
        durationInFrames={30}
        fps={30}
        // 400×400 — Flutter scales the GIF down on the loader screen.
        width={400}
        height={400}
        defaultProps={{}}
      />

      {/* Alternate palette previews — useful for A/B in Remotion Studio.
          Not exported; uncomment / re-arrange as desired. */}
      <Composition
        id="WalkingDogGolden"
        component={WalkingDog}
        durationInFrames={30}
        fps={30}
        width={400}
        height={400}
        defaultProps={{
          bodyColor: "#D9A76A",
          bellyColor: "#F2C795",
          earColor: "#2A2A2A",
        }}
      />

      <Composition
        id="WalkingDogSpotted"
        component={WalkingDog}
        durationInFrames={30}
        fps={30}
        width={400}
        height={400}
        defaultProps={{
          bodyColor: "#FFFFFF",
          bellyColor: "#F2F2F2",
          earColor: "#1A1A1A",
        }}
      />
    </>
  );
};
