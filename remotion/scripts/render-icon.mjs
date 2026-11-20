#!/usr/bin/env node
// npm run icon
//  1. Renders AppIcon (default, dark, tinted) as 1024 stills and flattens them to opaque RGB PNGs.
//  2. Fails if the default PNG has an alpha channel.
//  3. Renders IconPreview.png and the IconReveal MP4s (1080×1080, 1080×1920).
//  4. Copies the three PNGs into the app's AppIcon.appiconset (Any / Dark / Tinted) with Contents.json,
//     and the square IconReveal MP4 into the app's resources for the first-run screen.
// Everything lands in remotion/out. Pass --no-copy to skip step 4.
import {spawnSync} from 'node:child_process';
import {copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {PNG} from 'pngjs';
import {alphaProblem} from './check-icon-alpha.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'out');
const appResources = resolve(root, '..', 'Peugeot408', 'Resources');
const iconSet = join(appResources, 'Assets.xcassets', 'AppIcon.appiconset');
const copy = !process.argv.includes('--no-copy');

mkdirSync(out, {recursive: true});

function remotion(args) {
	console.log(`\n> remotion ${args.join(' ')}`);
	const r = spawnSync('npx', ['remotion', ...args], {cwd: root, stdio: 'inherit', shell: process.platform === 'win32'});
	if (r.status !== 0) {
		console.error(`remotion ${args[0]} failed (exit ${r.status}).`);
		process.exit(r.status ?? 1);
	}
}

function propsFile(name, props) {
	const file = join(out, `.props-${name}.json`);
	writeFileSync(file, JSON.stringify(props));
	return file;
}

/** Re-encode as 8-bit RGB (colour type 2): drops the alpha channel Chrome screenshots always carry. */
function flattenToRgb(src, dest) {
	const png = PNG.sync.read(readFileSync(src));
	for (let i = 0; i < png.data.length; i += 4) {
		if (png.data[i + 3] !== 255) {
			throw new Error(`${src} has transparent pixels; the icon must be fully opaque.`);
		}
	}
	writeFileSync(dest, PNG.sync.write(png, {colorType: 2, inputHasAlpha: true}));
}

// 1. App icon stills.
const variants = [
	{variant: 'default', file: 'AppIcon-1024.png'},
	{variant: 'dark', file: 'AppIcon-1024-dark.png'},
	{variant: 'tinted', file: 'AppIcon-1024-tinted.png'},
];
for (const {variant, file} of variants) {
	const raw = join(out, `.raw-${file}`);
	remotion(['still', 'AppIcon', raw, `--props=${propsFile(variant, {variant})}`, '--image-format=png']);
	flattenToRgb(raw, join(out, file));
	rmSync(raw);
}

// 2. Alpha check (the build fails here if the default icon has alpha).
for (const {file} of variants) {
	const problem = alphaProblem(join(out, file));
	if (problem) {
		console.error(`✗ out/${file} ${problem}. The app icon must be opaque.`);
		process.exit(1);
	}
	console.log(`✓ out/${file}: no alpha channel`);
}

// 3. Preview sheet and reveal videos.
remotion(['still', 'IconPreview', join(out, 'IconPreview.png'), '--image-format=png']);
remotion(['render', 'IconReveal', join(out, 'IconReveal-1080x1080.mp4'), `--props=${propsFile('square', {format: 'square'})}`, '--codec=h264', '--crf=18']);
remotion(['render', 'IconReveal', join(out, 'IconReveal-1080x1920.mp4'), `--props=${propsFile('vertical', {format: 'vertical'})}`, '--codec=h264', '--crf=18']);
for (const name of ['default', 'dark', 'tinted', 'square', 'vertical']) rmSync(join(out, `.props-${name}.json`), {force: true});

// 4. Into the app.
if (copy) {
	if (!existsSync(appResources)) {
		console.error(`App resources folder not found: ${appResources}`);
		process.exit(1);
	}
	mkdirSync(iconSet, {recursive: true});
	rmSync(join(iconSet, 'AppIcon.png'), {force: true}); // the old shape-drawn icon
	for (const {file} of variants) copyFileSync(join(out, file), join(iconSet, file));
	const contents = {
		images: [
			{filename: 'AppIcon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024'},
			{
				appearances: [{appearance: 'luminosity', value: 'dark'}],
				filename: 'AppIcon-1024-dark.png',
				idiom: 'universal',
				platform: 'ios',
				size: '1024x1024',
			},
			{
				appearances: [{appearance: 'luminosity', value: 'tinted'}],
				filename: 'AppIcon-1024-tinted.png',
				idiom: 'universal',
				platform: 'ios',
				size: '1024x1024',
			},
		],
		info: {author: 'xcode', version: 1},
	};
	writeFileSync(join(iconSet, 'Contents.json'), JSON.stringify(contents, null, 2) + '\n');
	copyFileSync(join(out, 'IconReveal-1080x1080.mp4'), join(appResources, 'IconReveal.mp4'));
	console.log(`\nCopied icons to ${iconSet}\nCopied IconReveal.mp4 to ${appResources}`);
}

console.log('\nDone. Outputs in remotion/out.');
