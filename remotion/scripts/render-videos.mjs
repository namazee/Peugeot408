#!/usr/bin/env node
// npm run videos
//  Renders the Phase 9 assets into remotion/out:
//   - WidgetShowcase.mp4 (1920×720), AppPreview.mp4 (886×1920)
//   - Onboarding{Welcome,Setup,Flash}.mp4 (720×900) for the app's first-run pages
//   - seasonal-<occasion>.png (600×600, transparent) for the seasonal packs
//  Then copies the onboarding clips to Peugeot408/Resources/Onboarding and the seasonal art to
//  Resources/Seasonal (bundled in the app and the widget). Pass --no-copy to skip copying.
import {spawnSync} from 'node:child_process';
import {copyFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'out');
const onboardingDir = resolve(root, '..', 'Peugeot408', 'Resources', 'Onboarding');
const seasonalDir = resolve(root, '..', 'Resources', 'Seasonal');
const copy = !process.argv.includes('--no-copy');
const occasions = ['ramadan', 'hariRaya', 'aidiladha', 'merdeka', 'chineseNewYear', 'deepavali', 'christmas', 'newYear'];

mkdirSync(out, {recursive: true});

function remotion(args) {
	console.log(`\n> remotion ${args.join(' ')}`);
	const r = spawnSync('npx', ['remotion', ...args], {cwd: root, stdio: 'inherit', shell: process.platform === 'win32'});
	if (r.status !== 0) {
		console.error(`remotion ${args[0]} failed (exit ${r.status}).`);
		process.exit(r.status ?? 1);
	}
}

const video = (id, crf = 20) => remotion(['render', id, join(out, `${id}.mp4`), '--codec=h264', `--crf=${crf}`]);

video('WidgetShowcase');
video('AppPreview');
for (const id of ['OnboardingWelcome', 'OnboardingSetup', 'OnboardingFlash']) video(id, 24);

for (const occasion of occasions) {
	const props = join(out, `.props-${occasion}.json`);
	writeFileSync(props, JSON.stringify({occasion}));
	remotion(['still', 'SeasonalArt', join(out, `seasonal-${occasion}.png`), `--props=${props}`, '--image-format=png']);
}

if (copy) {
	mkdirSync(onboardingDir, {recursive: true});
	mkdirSync(seasonalDir, {recursive: true});
	for (const id of ['OnboardingWelcome', 'OnboardingSetup', 'OnboardingFlash']) {
		copyFileSync(join(out, `${id}.mp4`), join(onboardingDir, `${id}.mp4`));
	}
	for (const occasion of occasions) {
		copyFileSync(join(out, `seasonal-${occasion}.png`), join(seasonalDir, `seasonal-${occasion}.png`));
	}
	console.log(`\nCopied onboarding clips to ${onboardingDir} and seasonal art to ${seasonalDir}.`);
}
