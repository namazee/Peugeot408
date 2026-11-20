import React, {useId} from 'react';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {getStaticFiles} from '@remotion/studio';

export type IconVariant = 'default' | 'dark' | 'tinted';

/** Animation state of the icon. FINAL is the settled icon (what AppIcon renders). */
export type RevealState = {
	/** Background (#05070D + blue glow) visibility, 0–1. */
	background: number;
	/** Car body visibility, 0–1. */
	body: number;
	/** Light strips / headlights drawn top-to-bottom, 0–1. */
	strips: number;
	/** Extra headlight bloom on top of the normal glow, 0–1+. */
	flash: number;
	/** Position of the glow sweep, 0–1 across the icon; null = no sweep. */
	sweep: number | null;
	/** Vignette + glass highlight visibility, 0–1. */
	finish: number;
};

export const FINAL: RevealState = {background: 1, body: 1, strips: 1, flash: 0, sweep: null, finish: 1};

export const ICON_SIZE = 1024;

// Spec §3 App icon.
const BG = '#05070D';
const ACCENT_RGB = '31, 79, 216'; // #1F4FD8
const GLOW_TINT = '#7FD4FF';

// Source art placement: scale + shift so the headlights, light strips and grille sit inside the
// central 80% safe area (x/y 102…922). In the 1024 source the light strips span x≈115…910 and
// y≈470…700; after this transform they span x≈131…894, y≈448…668.
const ART_SCALE = 0.96;
const ART_SHIFT_Y = -24;

const sourceFor = (variant: IconVariant): {src: string; provided: boolean} => {
	if (variant !== 'default') {
		const name = `icon/icon-${variant}.jpg`;
		const provided = getStaticFiles().some((f) => f.name === name);
		if (provided) return {src: staticFile(name), provided: true};
	}
	return {src: staticFile('icon/icon-default.jpg'), provided: variant === 'default'};
};

/**
 * The layered app icon at 1024×1024 logical pixels. Wrap it in a scaled box for other sizes.
 * Layers: 1 background + radial glow, 2 source art, 3 glow boost, 4 vignette + glass highlight.
 */
export const IconArt: React.FC<{variant: IconVariant; reveal?: RevealState}> = ({variant, reveal = FINAL}) => {
	const id = useId().replace(/[^a-zA-Z0-9]/g, '');
	const brightId = `bright${id}`;
	const glowId = `glow${id}`;
	const {src, provided} = sourceFor(variant);

	// A provided dark/tinted image is used as-is (only placement + glow + finish are added).
	const generated = !provided && variant !== 'default';
	const isTinted = variant === 'tinted';

	const bodyFilter = !generated
		? undefined
		: variant === 'dark'
			? 'brightness(0.85)'
			: // Brighten first so the blue body doesn't sink into black, then strong contrast.
				'grayscale(1) brightness(1.55) contrast(1.45)';

	// Bright-pixels-only copy of the art: keeps the lights at full brightness on top of the
	// darkened (dark) or grayscale (tinted) body, and is what the reveal draws on.
	const lightsFilter = isTinted ? `url(#${brightId}) grayscale(1) brightness(1.25)` : `url(#${brightId})`;

	const artStyle: React.CSSProperties = {
		position: 'absolute',
		left: 0,
		top: 0,
		width: ICON_SIZE,
		height: ICON_SIZE,
		transform: `translateY(${ART_SHIFT_Y}px) scale(${ART_SCALE})`,
		transformOrigin: '50% 50%',
		// Soften the edges of the art into the background.
		WebkitMaskImage: 'radial-gradient(ellipse 58% 58% at 50% 50%, #000 78%, transparent 100%)',
		maskImage: 'radial-gradient(ellipse 58% 58% at 50% 50%, #000 78%, transparent 100%)',
	};

	// Light strips draw on from the top of the lights band (~y 42%) to the bottom of the icon.
	const stripsBottomInset = 100 - (42 + 58 * reveal.strips);
	const stripsClip = `inset(0 0 ${Math.max(0, stripsBottomInset)}% 0)`;

	const glowOpacity = (0.4 + 2.2 * reveal.flash) * Math.min(1, reveal.strips * 1.5);

	return (
		<AbsoluteFill style={{width: ICON_SIZE, height: ICON_SIZE, background: '#000', isolation: 'isolate', overflow: 'hidden'}}>
			<svg width={0} height={0} style={{position: 'absolute'}} aria-hidden>
				<defs>
					<filter id={brightId} colorInterpolationFilters="sRGB">
						<feColorMatrix in="SourceGraphic" type="luminanceToAlpha" result="lum" />
						{/* Luminance threshold: below ~0.62 → transparent, above ~0.85 → opaque. */}
						<feComponentTransfer in="lum" result="mask">
							<feFuncA type="linear" slope={4.4} intercept={-2.75} />
						</feComponentTransfer>
						<feComposite in="SourceGraphic" in2="mask" operator="in" />
					</filter>
					<filter id={glowId} colorInterpolationFilters="sRGB" x="-25%" y="-25%" width="150%" height="150%">
						<feColorMatrix in="SourceGraphic" type="luminanceToAlpha" result="lum" />
						<feComponentTransfer in="lum" result="mask">
							<feFuncA type="linear" slope={4.4} intercept={-2.75} />
						</feComponentTransfer>
						<feGaussianBlur in="mask" stdDeviation={10} result="b1" />
						<feGaussianBlur in="mask" stdDeviation={34} result="b2" />
						<feMerge result="blur">
							<feMergeNode in="b2" />
							<feMergeNode in="b1" />
						</feMerge>
						<feFlood floodColor={isTinted ? '#FFFFFF' : GLOW_TINT} />
						<feComposite in2="blur" operator="in" />
					</filter>
				</defs>
			</svg>

			{/* Layer 1: background + soft radial blue glow behind the car (dark/tinted: pure black). */}
			<AbsoluteFill
				style={{
					opacity: reveal.background,
					background:
						variant === 'default'
							? `radial-gradient(ellipse 62% 52% at 50% 54%, rgba(${ACCENT_RGB},0.25) 0%, rgba(${ACCENT_RGB},0.12) 45%, rgba(${ACCENT_RGB},0) 100%), ${BG}`
							: '#000',
				}}
			/>

			{/* Layer 2: the master art. */}
			<Img src={src} style={{...artStyle, filter: bodyFilter, opacity: reveal.body}} />

			{/* Lights at full brightness (drawn on during the reveal). */}
			<AbsoluteFill style={{clipPath: stripsClip, opacity: reveal.strips > 0 ? 1 : 0}}>
				<Img src={src} style={{...artStyle, filter: lightsFilter}} />
			</AbsoluteFill>

			{/* Layer 3: glow boost — bright areas, blurred, tinted #7FD4FF, screen-blended at ~40%. */}
			<AbsoluteFill style={{clipPath: stripsClip, mixBlendMode: 'screen', opacity: glowOpacity}}>
				<Img src={src} style={{...artStyle, WebkitMaskImage: undefined, maskImage: undefined, filter: `url(#${glowId})`}} />
			</AbsoluteFill>

			{/* Reveal only: a soft glow band sweeping across. */}
			{reveal.sweep !== null ? (
				<AbsoluteFill style={{mixBlendMode: 'screen', overflow: 'hidden'}}>
					<div
						style={{
							position: 'absolute',
							top: -200,
							bottom: -200,
							width: 360,
							left: -360 + (ICON_SIZE + 720) * reveal.sweep,
							transform: 'rotate(18deg)',
							background: `linear-gradient(90deg, rgba(127,212,255,0) 0%, ${isTinted ? 'rgba(255,255,255,0.32)' : 'rgba(127,212,255,0.32)'} 50%, rgba(127,212,255,0) 100%)`,
						}}
					/>
				</AbsoluteFill>
			) : null}

			{/* Layer 4: vignette + faint Liquid Glass highlight along the top edge. */}
			<AbsoluteFill
				style={{
					opacity: reveal.finish,
					background: 'radial-gradient(ellipse 75% 75% at 50% 52%, rgba(0,0,0,0) 62%, rgba(0,0,0,0.42) 100%)',
				}}
			/>
			<AbsoluteFill
				style={{
					opacity: reveal.finish * (variant === 'default' ? 1 : 0.7),
					background:
						'radial-gradient(ellipse 70% 14% at 50% 0%, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0) 100%), linear-gradient(180deg, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0) 9%)',
				}}
			/>
		</AbsoluteFill>
	);
};

/** The icon shown at `size` px, optionally with the iOS corner mask (the PNGs themselves are square). */
export const IconTile: React.FC<{
	variant: IconVariant;
	size: number;
	masked?: boolean;
	reveal?: RevealState;
	tint?: string;
	style?: React.CSSProperties;
}> = ({variant, size, masked = true, reveal, tint, style}) => {
	const scale = size / ICON_SIZE;
	return (
		<div
			style={{
				width: size,
				height: size,
				position: 'relative',
				overflow: 'hidden',
				borderRadius: masked ? size * 0.2237 : 0,
				flexShrink: 0,
				isolation: 'isolate',
				...style,
			}}
		>
			<div style={{width: ICON_SIZE, height: ICON_SIZE, transform: `scale(${scale})`, transformOrigin: '0 0', position: 'absolute'}}>
				<IconArt variant={variant} reveal={reveal} />
			</div>
			{tint ? <div style={{position: 'absolute', inset: 0, background: tint, mixBlendMode: 'color', opacity: 0.9}} /> : null}
		</div>
	);
};
