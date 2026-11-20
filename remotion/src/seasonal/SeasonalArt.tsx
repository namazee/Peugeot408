import React from 'react';
import {AbsoluteFill} from 'remotion';

/** Original seasonal-pack artwork (spec §4b + §8 Phase 9), rendered as transparent 600×600 PNGs. */
export type Occasion = 'ramadan' | 'hariRaya' | 'aidiladha' | 'merdeka' | 'chineseNewYear' | 'deepavali' | 'christmas' | 'newYear';
export type SeasonalArtProps = {occasion: Occasion};

export const OCCASIONS: Occasion[] = ['ramadan', 'hariRaya', 'aidiladha', 'merdeka', 'chineseNewYear', 'deepavali', 'christmas', 'newYear'];

const Glow: React.FC<{id: string; color: string}> = ({id, color}) => (
	<radialGradient id={id}>
		<stop offset="0%" stopColor={color} stopOpacity={0.55} />
		<stop offset="100%" stopColor={color} stopOpacity={0} />
	</radialGradient>
);

const Star: React.FC<{x: number; y: number; r: number; fill: string; points?: number}> = ({x, y, r, fill, points = 5}) => {
	const pts: string[] = [];
	for (let i = 0; i < points * 2; i++) {
		const radius = i % 2 === 0 ? r : r * 0.45;
		const a = (Math.PI * i) / points - Math.PI / 2;
		pts.push(`${x + radius * Math.cos(a)},${y + radius * Math.sin(a)}`);
	}
	return <polygon points={pts.join(' ')} fill={fill} />;
};

const Sparkle: React.FC<{x: number; y: number; s: number; fill?: string}> = ({x, y, s, fill = '#FFE9A8'}) => (
	<path d={`M ${x} ${y - s} Q ${x} ${y} ${x + s} ${y} Q ${x} ${y} ${x} ${y + s} Q ${x} ${y} ${x - s} ${y} Q ${x} ${y} ${x} ${y - s} Z`} fill={fill} />
);

const Crescent: React.FC<{cx: number; cy: number; r: number; fill: string; bite?: number}> = ({cx, cy, r, fill, bite = 0.32}) => (
	<g>
		<defs>
			<mask id={`m-${cx}-${cy}`}>
				<rect x={0} y={0} width={600} height={600} fill="#fff" />
				<circle cx={cx + r * bite * 1.6} cy={cy - r * bite * 0.6} r={r * 0.86} fill="#000" />
			</mask>
		</defs>
		<circle cx={cx} cy={cy} r={r} fill={fill} mask={`url(#m-${cx}-${cy})`} />
	</g>
);

const Ketupat: React.FC<{x: number; y: number; s: number; tint: string}> = ({x, y, s, tint}) => {
	const lines: React.ReactNode[] = [];
	for (let i = -3; i <= 3; i++) {
		const o = (i * s) / 3.5;
		lines.push(<line key={`a${i}`} x1={x - s + o} y1={y - s * 0} x2={x + o} y2={y + s} stroke="#0B4D2A" strokeWidth={s * 0.08} opacity={0.5} />);
		lines.push(<line key={`b${i}`} x1={x + s + o} y1={y} x2={x + o} y2={y + s} stroke="#E8F5C8" strokeWidth={s * 0.05} opacity={0.5} />);
	}
	const diamond = `M ${x} ${y - s} L ${x + s} ${y} L ${x} ${y + s} L ${x - s} ${y} Z`;
	return (
		<g>
			<defs>
				<clipPath id={`k-${x}-${y}`}>
					<path d={diamond} />
				</clipPath>
				<linearGradient id={`kg-${x}-${y}`} x1="0" y1="0" x2="1" y2="1">
					<stop offset="0%" stopColor="#B7E36A" />
					<stop offset="100%" stopColor={tint} />
				</linearGradient>
			</defs>
			<path d={diamond} fill={`url(#kg-${x}-${y})`} />
			<g clipPath={`url(#k-${x}-${y})`}>
				{[-6, -4, -2, 0, 2, 4, 6].map((i) => (
					<React.Fragment key={i}>
						<line x1={x - s * 2} y1={y + (i * s) / 4 - s * 2} x2={x + s * 2} y2={y + (i * s) / 4 + s * 2} stroke="#0B4D2A" strokeWidth={s * 0.07} opacity={0.45} />
						<line x1={x + s * 2} y1={y + (i * s) / 4 - s * 2} x2={x - s * 2} y2={y + (i * s) / 4 + s * 2} stroke="#F2FFD6" strokeWidth={s * 0.05} opacity={0.45} />
					</React.Fragment>
				))}
			</g>
			<path d={`M ${x} ${y - s} q ${s * 0.15} ${-s * 0.5} ${s * 0.55} ${-s * 0.75}`} stroke={tint} strokeWidth={s * 0.09} fill="none" strokeLinecap="round" />
			<path d={`M ${x} ${y - s} q ${-s * 0.25} ${-s * 0.45} ${-s * 0.15} ${-s * 0.9}`} stroke="#8CC63F" strokeWidth={s * 0.07} fill="none" strokeLinecap="round" />
		</g>
	);
};

const Lantern: React.FC<{x: number; y: number; s: number}> = ({x, y, s}) => (
	<g>
		<line x1={x} y1={0} x2={x} y2={y - s * 0.75} stroke="#D4A537" strokeWidth={4} />
		<rect x={x - s * 0.35} y={y - s * 0.78} width={s * 0.7} height={s * 0.16} rx={4} fill="#E3B341" />
		<ellipse cx={x} cy={y} rx={s * 0.85} ry={s * 0.68} fill="#C8202F" />
		{[-0.55, -0.2, 0.2, 0.55].map((k) => (
			<path key={k} d={`M ${x + k * s * 0.9} ${y - s * 0.6} Q ${x + k * s * 1.25} ${y} ${x + k * s * 0.9} ${y + s * 0.6}`} stroke="#8E1420" strokeWidth={4} fill="none" />
		))}
		<ellipse cx={x - s * 0.25} cy={y - s * 0.2} rx={s * 0.22} ry={s * 0.3} fill="#fff" opacity={0.18} />
		<rect x={x - s * 0.35} y={y + s * 0.62} width={s * 0.7} height={s * 0.16} rx={4} fill="#E3B341" />
		{[-0.18, -0.06, 0.06, 0.18].map((k) => (
			<line key={k} x1={x + k * s} y1={y + s * 0.78} x2={x + k * s * 1.3} y2={y + s * 1.35} stroke="#E3B341" strokeWidth={5} strokeLinecap="round" />
		))}
	</g>
);

const Art: React.FC<{occasion: Occasion}> = ({occasion}) => {
	switch (occasion) {
		case 'ramadan':
			return (
				<>
					<defs><Glow id="g" color="#F5C542" /></defs>
					<circle cx={300} cy={260} r={250} fill="url(#g)" />
					<Crescent cx={290} cy={270} r={170} fill="#F5C542" />
					<Star x={420} y={170} r={34} fill="#FFE9A8" />
					<Sparkle x={150} y={120} s={18} />
					<Sparkle x={470} y={430} s={14} />
					<Sparkle x={120} y={420} s={10} />
				</>
			);
		case 'hariRaya':
			return (
				<>
					<defs><Glow id="g" color="#8CC63F" /></defs>
					<circle cx={300} cy={320} r={260} fill="url(#g)" />
					<Ketupat x={230} y={330} s={130} tint="#2E8B3E" />
					<Ketupat x={420} y={260} s={95} tint="#3FA34D" />
					<Sparkle x={130} y={140} s={20} fill="#FFE08A" />
					<Sparkle x={500} y={480} s={16} fill="#FFE08A" />
				</>
			);
		case 'aidiladha':
			return (
				<>
					<defs><Glow id="g" color="#F5C542" /></defs>
					<circle cx={300} cy={300} r={260} fill="url(#g)" />
					<Crescent cx={300} cy={190} r={90} fill="#F5C542" />
					{/* A generic dome and two minarets, not any particular building. */}
					<path d="M 180 470 L 180 380 Q 300 230 420 380 L 420 470 Z" fill="#1E6B45" />
					<path d="M 300 255 L 300 228" stroke="#F5C542" strokeWidth={6} />
					<rect x={110} y={300} width={36} height={170} rx={6} fill="#1E6B45" />
					<path d="M 104 300 L 128 250 L 152 300 Z" fill="#F5C542" />
					<rect x={454} y={300} width={36} height={170} rx={6} fill="#1E6B45" />
					<path d="M 448 300 L 472 250 L 496 300 Z" fill="#F5C542" />
					<rect x={80} y={468} width={440} height={24} rx={8} fill="#145234" />
				</>
			);
		case 'merdeka': {
			const stripes = Array.from({length: 14}, (_, i) => i);
			const wave = (y: number) => `M 70 ${y} C 200 ${y - 30}, 330 ${y + 30}, 530 ${y}`;
			return (
				<>
					<defs>
						<clipPath id="flag">
							<path d="M 70 130 C 200 100, 330 160, 530 130 L 530 450 C 330 480, 200 420, 70 450 Z" />
						</clipPath>
					</defs>
					<g clipPath="url(#flag)">
						{stripes.map((i) => (
							<path key={i} d={`${wave(130 + i * 23)} L 530 ${153 + i * 23} C 330 ${183 + i * 23}, 200 ${123 + i * 23}, 70 ${153 + i * 23} Z`} fill={i % 2 === 0 ? '#CC0001' : '#FFFFFF'} />
						))}
						<rect x={60} y={100} width={240} height={200} fill="#010066" />
						<Crescent cx={150} cy={205} r={62} fill="#FFCC00" bite={0.36} />
						<Star x={232} y={205} r={44} fill="#FFCC00" points={14} />
					</g>
					<rect x={56} y={110} width={10} height={420} rx={5} fill="#C9CED6" />
				</>
			);
		}
		case 'chineseNewYear':
			return (
				<>
					<defs><Glow id="g" color="#FF5A4E" /></defs>
					<circle cx={300} cy={320} r={260} fill="url(#g)" />
					<Lantern x={200} y={300} s={120} />
					<Lantern x={410} y={250} s={95} />
					{[[110, 480], [480, 470], [520, 120]].map(([cx, cy]) => (
						<g key={`${cx}`}>
							{[0, 72, 144, 216, 288].map((a) => (
								<circle key={a} cx={cx + 14 * Math.cos((a * Math.PI) / 180)} cy={cy + 14 * Math.sin((a * Math.PI) / 180)} r={11} fill="#F7A8C4" />
							))}
							<circle cx={cx} cy={cy} r={6} fill="#F5C542" />
						</g>
					))}
				</>
			);
		case 'deepavali':
			return (
				<>
					<defs>
						<Glow id="g" color="#FFB238" />
						<linearGradient id="bowl" x1="0" y1="0" x2="0" y2="1">
							<stop offset="0%" stopColor="#E58A2B" />
							<stop offset="100%" stopColor="#9B3E12" />
						</linearGradient>
					</defs>
					<circle cx={300} cy={300} r={260} fill="url(#g)" />
					{Array.from({length: 24}, (_, i) => {
						const a = (i / 24) * Math.PI * 2;
						return <circle key={i} cx={300 + 230 * Math.cos(a)} cy={330 + 160 * Math.sin(a)} r={7} fill={i % 2 ? '#F7A8C4' : '#FFE08A'} opacity={0.85} />;
					})}
					<path d="M 160 360 Q 300 520 440 360 Z" fill="url(#bowl)" />
					<path d="M 150 360 L 450 360" stroke="#F5C542" strokeWidth={10} strokeLinecap="round" />
					<path d="M 300 190 Q 360 280 300 345 Q 240 280 300 190 Z" fill="#FFB238" />
					<path d="M 300 250 Q 325 295 300 335 Q 275 295 300 250 Z" fill="#FFF3C4" />
				</>
			);
		case 'christmas':
			return (
				<>
					<defs><Glow id="g" color="#4ADE80" /></defs>
					<circle cx={300} cy={300} r={260} fill="url(#g)" />
					{[0, 1, 2].map((tier) => {
						const top = 120 + tier * 95;
						const half = 95 + tier * 55;
						return <path key={tier} d={`M 300 ${top} L ${300 + half} ${top + 150} L ${300 - half} ${top + 150} Z`} fill={['#1F9D55', '#188A49', '#12763D'][tier]} />;
					})}
					<rect x={276} y={460} width={48} height={60} rx={6} fill="#7A4A23" />
					<Star x={300} y={112} r={40} fill="#F5C542" />
					{[[260, 220, '#E5484D'], [345, 280, '#F5C542'], [230, 330, '#60A5FA'], [370, 380, '#E5484D'], [300, 405, '#F5C542'], [200, 420, '#F5C542']].map(([cx, cy, c]) => (
						<circle key={`${cx}-${cy}`} cx={cx as number} cy={cy as number} r={14} fill={c as string} />
					))}
				</>
			);
		case 'newYear':
			return (
				<>
					{[[200, 220, 150, '#F5C542'], [410, 190, 120, '#60A5FA'], [330, 400, 110, '#F7A8C4']].map(([cx, cy, r, c]) => (
						<g key={`${cx}`}>
							{Array.from({length: 16}, (_, i) => {
								const a = (i / 16) * Math.PI * 2;
								const x1 = (cx as number) + (r as number) * 0.25 * Math.cos(a);
								const y1 = (cy as number) + (r as number) * 0.25 * Math.sin(a);
								const x2 = (cx as number) + (r as number) * Math.cos(a);
								const y2 = (cy as number) + (r as number) * Math.sin(a);
								return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke={c as string} strokeWidth={7} strokeLinecap="round" />;
							})}
							<circle cx={cx as number} cy={cy as number} r={10} fill="#fff" />
						</g>
					))}
					<Sparkle x={110} y={430} s={18} />
					<Sparkle x={520} y={350} s={14} />
				</>
			);
	}
};

export const SeasonalArt: React.FC<SeasonalArtProps> = ({occasion}) => (
	<AbsoluteFill style={{background: 'transparent'}}>
		<svg width={600} height={600} viewBox="0 0 600 600">
			<Art occasion={occasion} />
		</svg>
	</AbsoluteFill>
);
