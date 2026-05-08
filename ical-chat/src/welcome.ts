import chalk from "chalk";

const ORANGE = chalk.hex("#e0af68");
const DIM_COLOR = chalk.hex("#565f89");

const ROBOT = [
  "  ★     ",
  " ┌────┐ ",
  " │ ·· │ ",
  " └────┘ ",
  "   ╷╷   ",
  " ──┘└── ",
];

// Pre-composed "Cali" ASCII art — C + a + l + i (26 chars per row)
const CALI = [
  " /─────╮           │   ·  ",
  " │        ╭────╮   │   │  ",
  " │        ╰────┤   │   │  ",
  " │              │  │   │  ",
  " │        ╰────╯   │   ╰─ ",
  " ╰─────╯            ╰──   ",
];

export function printWelcome(): void {
  for (let i = 0; i < ROBOT.length; i++) {
    console.log(ORANGE(ROBOT[i] + "  " + CALI[i]));
  }
  console.log();
  const badge = DIM_COLOR("[ ") + "calendar bestie" + DIM_COLOR(" ]");
  console.log("  your calendar has a " + ORANGE.bold("brain") + " now  ·  " + badge);
  console.log(
    "  looks after your time, your focus, " +
      ORANGE.bold("and you") +
      "  ·  " +
      DIM_COLOR("v0.1.0"),
  );
  console.log();
  console.log(DIM_COLOR("─".repeat(process.stdout.columns ?? 80)));
}
