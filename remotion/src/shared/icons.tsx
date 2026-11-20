import React from 'react';

/**
 * Small original line/solid icons for the videos (SF Symbols aren't available on the web).
 * Drawn on a 24×24 grid; colour via `color`.
 */
export type IconName =
	| 'moon'
	| 'calendar'
	| 'wrench'
	| 'fuel'
	| 'cloud'
	| 'parking'
	| 'gauge'
	| 'card'
	| 'photo'
	| 'car'
	| 'plus'
	| 'check'
	| 'chevron'
	| 'music'
	| 'route';

export const Icon: React.FC<{name: IconName; size?: number; color?: string}> = ({name, size = 24, color = '#fff'}) => {
	const stroke = {fill: 'none', stroke: color, strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const};
	const solid = {fill: color};
	let body: React.ReactNode;
	switch (name) {
		case 'moon':
			body = (
				<>
					<path d="M15 3.5a8.5 8.5 0 1 0 5.5 14.4A7 7 0 0 1 15 3.5z" {...solid} />
					<path d="M19 4l.6 1.6L21 6.2l-1.4.6L19 8.4l-.6-1.6L17 6.2l1.4-.6z" {...solid} />
				</>
			);
			break;
		case 'calendar':
			body = (
				<>
					<rect x="3.5" y="5" width="17" height="15" rx="3" {...stroke} />
					<path d="M3.5 10h17M8 3v4M16 3v4" {...stroke} />
					<circle cx="12" cy="15" r="1.6" {...solid} />
				</>
			);
			break;
		case 'wrench':
			body = <path d="M14.5 4a5 5 0 0 0-4.7 6.7L4 16.5 7.5 20l5.8-5.8A5 5 0 0 0 20 9.5l-3 3-3.5-1-1-3.5 3-3a5 5 0 0 0-1-.5z" {...solid} />;
			break;
		case 'fuel':
			body = (
				<>
					<rect x="4" y="3.5" width="10" height="17" rx="2" {...solid} />
					<rect x="6" y="6" width="6" height="4.5" rx="1" fill="#000" opacity={0.35} />
					<path d="M14 9h2.5a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 0 3 0V8l-3-3" {...stroke} />
				</>
			);
			break;
		case 'cloud':
			body = (
				<>
					<circle cx="9" cy="8" r="3.2" fill="#F5C542" />
					<path d="M7 19h10a4 4 0 0 0 .4-8A5.5 5.5 0 0 0 7 12.5 3.3 3.3 0 0 0 7 19z" {...solid} />
				</>
			);
			break;
		case 'parking':
			body = (
				<>
					<circle cx="12" cy="12" r="9" {...solid} />
					<path d="M9.5 17V7.5h3.2a3 3 0 0 1 0 6H9.5" fill="none" stroke="#000" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" opacity={0.75} />
				</>
			);
			break;
		case 'gauge':
			body = (
				<>
					<path d="M4 16a8 8 0 1 1 16 0" {...stroke} />
					<path d="M12 16l4.5-5" {...stroke} />
					<circle cx="12" cy="16" r="1.8" {...solid} />
				</>
			);
			break;
		case 'card':
			body = (
				<>
					<rect x="3" y="5.5" width="18" height="13" rx="2.5" {...solid} />
					<rect x="3" y="8.5" width="18" height="2.5" fill="#000" opacity={0.35} />
				</>
			);
			break;
		case 'photo':
			body = (
				<>
					<rect x="3.5" y="5" width="17" height="14" rx="2.5" {...stroke} />
					<path d="M5 17l4.5-5 3.5 3.5 2.5-2.5L19 16.5" {...stroke} />
					<circle cx="15.5" cy="9" r="1.5" {...solid} />
				</>
			);
			break;
		case 'car':
			body = (
				<path d="M3 15.5l1.5-4.2A3 3 0 0 1 7.3 9.3h7.5c1 0 2 .5 2.6 1.3L19.5 13l1.2.4A1.5 1.5 0 0 1 21.8 15v1.5h-2.3a2.3 2.3 0 0 1-4.5 0H9a2.3 2.3 0 0 1-4.5 0H3z" {...solid} />
			);
			break;
		case 'plus':
			body = <path d="M12 5v14M5 12h14" {...stroke} strokeWidth={2.6} />;
			break;
		case 'check':
			body = <path d="M5 12.5l4.5 4.5L19 7.5" {...stroke} strokeWidth={2.8} />;
			break;
		case 'chevron':
			body = <path d="M9 5l7 7-7 7" {...stroke} />;
			break;
		case 'music':
			body = (
				<>
					<path d="M9 17V5l11-2v12" {...stroke} />
					<circle cx="6.5" cy="17" r="2.5" {...solid} />
					<circle cx="17.5" cy="15" r="2.5" {...solid} />
				</>
			);
			break;
		case 'route':
			body = (
				<>
					<circle cx="6" cy="18" r="2.2" {...solid} />
					<circle cx="18" cy="6" r="2.2" {...solid} />
					<path d="M8 18h7a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h7" {...stroke} />
				</>
			);
			break;
	}
	return (
		<svg width={size} height={size} viewBox="0 0 24 24" style={{display: 'block', flexShrink: 0}}>
			{body}
		</svg>
	);
};
