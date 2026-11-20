import tokens from '../../../theme/tokens.json';
import {loadFont as loadInter} from '@remotion/google-fonts/Inter';
import {loadFont as loadNunito} from '@remotion/google-fonts/Nunito';

/** Same palette as the app: theme/tokens.json is also compiled into CarKit/Theme/ThemeTokens.swift. */
export const colors = tokens.colors;
export const aqi = tokens.aqi;
export const radius = tokens.radius;

const inter = loadInter('normal', {weights: ['400', '500', '600', '700'], subsets: ['latin']});
const nunito = loadNunito('normal', {weights: ['600', '700', '800', '900'], subsets: ['latin']});

/** UI text (the app uses SF Pro). */
export const textFont = inter.fontFamily;
/** Big rounded numbers (the app uses SF Pro Rounded). */
export const numberFont = nunito.fontFamily;

export type Urgency = 'ok' | 'dueSoon' | 'urgent';

export const urgencyColor = (urgency: Urgency, fallback: string = colors.primaryText) =>
	urgency === 'dueSoon' ? colors.dueSoon : urgency === 'urgent' ? colors.overdue : fallback;
