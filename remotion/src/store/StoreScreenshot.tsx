import React from 'react';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {colors, textFont} from '../shared/theme';

// App Store screenshot frame (spec §10 Store listing): 1320×2868 (6.9-inch iPhone).
// A headline above the app's own screen, on a dark background in the theme colours. No device artwork.
export const STORE_WIDTH = 1320;
export const STORE_HEIGHT = 2868;

export type StoreScreenshotProps = {
	/** Raw screenshot in assets/store-raw/ (from ci/screenshots.sh). */
	file: string;
	headline: string;
	subline: string;
};

export const StoreScreenshot: React.FC<StoreScreenshotProps> = ({file, headline, subline}) => {
	const screenWidth = 940;
	const screenHeight = Math.round((screenWidth * STORE_HEIGHT) / STORE_WIDTH);
	return (
		<AbsoluteFill
			style={{
				background: 'radial-gradient(ellipse 90% 45% at 50% 8%, rgba(31,79,216,0.45) 0%, rgba(5,7,13,0) 70%), #05070D',
				alignItems: 'center',
				fontFamily: textFont,
			}}
		>
			<div style={{marginTop: 150, padding: '0 90px', textAlign: 'center'}}>
				<div style={{fontSize: 84, fontWeight: 800, lineHeight: 1.08, color: colors.primaryText, letterSpacing: '-0.01em'}}>{headline}</div>
				<div style={{fontSize: 46, fontWeight: 500, lineHeight: 1.3, color: '#9AA4B8', marginTop: 28}}>{subline}</div>
			</div>
			<div
				style={{
					position: 'absolute',
					top: 600,
					width: screenWidth,
					height: screenHeight,
					borderRadius: 84,
					overflow: 'hidden',
					border: '6px solid #1C2433',
					boxShadow: '0 40px 120px rgba(31,79,216,0.35), 0 0 0 2px rgba(127,212,255,0.12)',
				}}
			>
				<Img src={staticFile(`store-raw/${file}`)} style={{width: '100%', height: '100%'}} />
			</div>
		</AbsoluteFill>
	);
};
