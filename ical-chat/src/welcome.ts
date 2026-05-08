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
  const lines = Math.max(avatar.length, wordmark.length);

  for (let i = 0; i < lines; i++) {
    const left  = (avatar[i]   ?? '').padEnd(10);
    const right = wordmark[i] ?? '';
    console.log(caliColor(left + '  ' + right));
  }

  // Bordered badge to match the design's outlined box style
  const badge =
    caliColor.dim('[') +
    chalk.bgHex('#1e1208').hex('#f0a070').bold(' calendar bestie ') +
    caliColor.dim(']');

  console.log();
  const indent = ' '.repeat(12);
  console.log(
    chalk.bold(indent + 'your calendar has a ') +
    caliColor.bold('brain') +
    chalk.bold(' now') +
    chalk.hex('#888888')('  ·  ') +
    badge
  );
  console.log(
    chalk.hex('#555555')(indent + 'looks after your time, your focus, ') +
    caliColor('and you') +
    chalk.hex('#555555')('  ·  v0.1.0')
  );
  console.log();
}
