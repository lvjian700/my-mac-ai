import chalk from 'chalk';

const caliColor = chalk.rgb(240, 160, 112);

const avatar = [
  '  ★',
  '╭─────╮',
  '│ · · │',
  '│  ‿  │',
  '╰──┬──╯',
  '  ─┴─',
];

const wordmark = [
  '   ____      _ _     ',
  '  / ___|__ _| (_)    ',
  ' | |   / _` | | |   ',
  ' | |__| (_| | | |   ',
  '  \\____\\__,_|_|_|   ',
];

export function printWelcome() {
  const badge =
    caliColor.dim('[') +
    chalk.bgHex('#1e1208').hex('#f0a070').bold(' calendar bestie ') +
    caliColor.dim(']');

  const tagline1 =
    chalk.bold('your calendar has a ') +
    caliColor.bold('brain') +
    chalk.bold(' now') +
    chalk.hex('#888888')('  ·  ') +
    badge;

  const tagline2 =
    chalk.hex('#555555')('looks after your time, your focus, ') +
    caliColor('and you') +
    chalk.hex('#555555')('  ·  v0.1.0');

  // Right column: wordmark immediately followed by taglines (no blank row)
  const rightCol = [...wordmark, tagline1, tagline2];
  const lines = Math.max(avatar.length, rightCol.length);

  for (let i = 0; i < lines; i++) {
    const left  = (avatar[i] ?? '').padEnd(10);
    const right = rightCol[i] ?? '';
    if (i < wordmark.length) {
      console.log(caliColor(left + '  ' + right));
    } else {
      // Subtitle rows: color left (avatar) and right (tagline) independently
      console.log(caliColor(left) + '  ' + right);
    }
  }

  console.log();
}
