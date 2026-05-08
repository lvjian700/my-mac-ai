import chalk from 'chalk';

const caliColor = chalk.rgb(240, 160, 112);

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

  for (const line of wordmark) {
    console.log(caliColor(line));
  }

  console.log(
    chalk.bold('your calendar has a ') +
    caliColor.bold('brain') +
    chalk.bold(' now') +
    chalk.hex('#888888')('  ·  ') +
    badge,
  );
  console.log(
    chalk.hex('#555555')('looks after your time, your focus, ') +
    caliColor('and you') +
    chalk.hex('#555555')('  ·  v0.1.0'),
  );

  console.log();
}
