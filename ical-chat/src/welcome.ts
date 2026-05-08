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

  console.log();
  console.log(
    caliColor.bold('your calendar has a brain now') +
    chalk.hex('#333333')(' · ') +
    chalk.bgHex('#1e1208').hex('#f0a070')(' calendar bestie ')
  );
  console.log(
    chalk.hex('#555555')(`looks after your time, your focus, `) +
    caliColor('and you') +
    chalk.hex('#555555')('  ·  v0.1.0')
  );
  console.log();
}
