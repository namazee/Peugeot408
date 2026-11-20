#!/usr/bin/env node
// Fails (exit 1) if any given PNG has an alpha channel or a tRNS transparency chunk.
// App Store Connect rejects an app icon with alpha. No dependencies, so the iOS CI can run it too.
// Usage: node check-icon-alpha.mjs <file.png> [more.png ...]
import {readFileSync} from 'node:fs';

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const COLOR_TYPES = {0: 'grayscale', 2: 'RGB', 3: 'palette', 4: 'grayscale+alpha', 6: 'RGBA'};

export function alphaProblem(file) {
	const buf = readFileSync(file);
	if (!buf.subarray(0, 8).equals(SIGNATURE)) return 'not a PNG file';
	let colorType = null;
	for (let pos = 8; pos + 8 <= buf.length; ) {
		const length = buf.readUInt32BE(pos);
		const type = buf.toString('ascii', pos + 4, pos + 8);
		if (type === 'IHDR') colorType = buf[pos + 8 + 9];
		if (type === 'tRNS') return 'has a tRNS (transparency) chunk';
		if (type === 'IEND') break;
		pos += 12 + length;
	}
	if (colorType === null) return 'no IHDR chunk';
	if (colorType === 4 || colorType === 6) return `has an alpha channel (${COLOR_TYPES[colorType]})`;
	return null;
}

if (import.meta.url === `file://${process.argv[1].replace(/\\/g, '/')}` || process.argv[1]?.endsWith('check-icon-alpha.mjs')) {
	const files = process.argv.slice(2);
	if (files.length === 0) {
		console.error('usage: check-icon-alpha.mjs <file.png> [...]');
		process.exit(2);
	}
	let failed = false;
	for (const f of files) {
		let problem;
		try {
			problem = alphaProblem(f);
		} catch (e) {
			problem = `cannot read (${e.message})`;
		}
		if (problem) {
			console.error(`✗ ${f}: ${problem}. The app icon must be opaque — no alpha channel.`);
			failed = true;
		} else {
			console.log(`✓ ${f}: no alpha channel`);
		}
	}
	process.exit(failed ? 1 : 0);
}
