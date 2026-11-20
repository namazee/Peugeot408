import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {IconTile, type RevealState} from './IconArt';

export type IconRevealProps = {format: 'square' | 'vertical'};

export const REVEAL_FPS = 30;
export const REVEAL_FRAMES = Math.round(3.5 * REVEAL_FPS); // 105

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const out = Easing.out(Easing.cubic);
const inOut = Easing.inOut(Easing.cubic);

/** Black → light strips draw top-to-bottom → headlights flash with bloom → glow sweep → settled icon. */
export const IconReveal: React.FC<IconRevealProps> = () => {
	const frame = useCurrentFrame();
	const {width} = useVideoConfig();
	const s = (sec: number) => sec * REVEAL_FPS;

	const reveal: RevealState = {
		strips: interpolate(frame, [s(0.25), s(1.25)], [0, 1], {...clamp, easing: out}),
		flash:
			frame < s(1.45)
				? interpolate(frame, [s(1.2), s(1.45)], [0, 1], {...clamp, easing: out})
				: interpolate(frame, [s(1.45), s(2.3)], [1, 0], {...clamp, easing: inOut}),
		background: interpolate(frame, [s(1.0), s(2.4)], [0, 1], {...clamp, easing: inOut}),
		body: interpolate(frame, [s(1.3), s(2.5)], [0, 1], {...clamp, easing: inOut}),
		sweep: frame >= s(1.9) && frame <= s(2.85) ? interpolate(frame, [s(1.9), s(2.85)], [0, 1], {...clamp, easing: inOut}) : null,
		finish: interpolate(frame, [s(2.2), s(2.9)], [0, 1], clamp),
	};

	// A slight settle-in scale over the clip.
	const scale = interpolate(frame, [0, s(2.9)], [1.04, 1], {...clamp, easing: out});
	const size = Math.round(width * 0.82);

	return (
		<AbsoluteFill style={{background: '#000', alignItems: 'center', justifyContent: 'center'}}>
			<div style={{transform: `scale(${scale})`}}>
				<IconTile variant="default" size={size} reveal={reveal} />
			</div>
		</AbsoluteFill>
	);
};
