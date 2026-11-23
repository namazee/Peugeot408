#!/usr/bin/env node
// npm run store
//  App Store screenshots (spec §10): frames the raw simulator shots in assets/store-raw/
//  (from ci/screenshots.sh) with a headline, for English and Malay, into out/store/<locale>/.
import {spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const raw = join(root, 'assets', 'store-raw');
const out = join(root, 'out', 'store');

const shots = {
	'1-slots': {
		'en-GB': ['Your car screen, your way', 'Five slots you design on your iPhone'],
		ms: ['Skrin kereta, cara anda', 'Lima slot yang anda reka di iPhone'],
	},
	'2-neon': {
		'en-GB': ['Bold or Neon', 'Two looks for every card, any colour'],
		ms: ['Bold atau Neon', 'Dua gaya untuk setiap kad, apa-apa warna'],
	},
	'3-panorama': {
		'en-GB': ['One picture, three columns', 'Your car, a greeting and the clock'],
		ms: ['Satu gambar, tiga lajur', 'Kereta anda, ucapan dan jam'],
	},
	'4-templates': {
		'en-GB': ['Ready-made templates', 'Or build your own from scratch'],
		ms: ['Templat siap sedia', 'Atau bina sendiri dari awal'],
	},
	'5-car': {
		'en-GB': ['Never miss a service', 'Service, fuel, road tax and more'],
		ms: ['Jangan terlepas servis', 'Servis, minyak, cukai jalan dan lagi'],
	},
	'6-sounds': {
		'en-GB': ['Start with a roar', 'Engine and EV sounds when CarPlay connects'],
		ms: ['Mula dengan deruman', 'Bunyi enjin dan EV bila CarPlay disambung'],
	},
};

let rendered = 0;
for (const [name, locales] of Object.entries(shots)) {
	if (!existsSync(join(raw, `${name}.png`))) {
		console.warn(`Skipping ${name}: assets/store-raw/${name}.png is missing.`);
		continue;
	}
	for (const [locale, [headline, subline]] of Object.entries(locales)) {
		const dir = join(out, locale);
		mkdirSync(dir, {recursive: true});
		const props = join(out, `.props-${name}-${locale}.json`);
		writeFileSync(props, JSON.stringify({file: `${name}.png`, headline, subline}));
		const args = ['remotion', 'still', 'StoreScreenshot', join(dir, `${name}.png`), `--props=${props}`, '--image-format=png'];
		console.log(`\n> npx ${args.join(' ')}`);
		const r = spawnSync('npx', args, {cwd: root, stdio: 'inherit', shell: process.platform === 'win32'});
		if (r.status !== 0) process.exit(r.status ?? 1);
		rendered++;
	}
}
if (rendered === 0) {
	console.error('No raw screenshots found in assets/store-raw.');
	process.exit(1);
}
console.log(`\nDone: ${rendered} screenshots in out/store.`);
