import {Config} from '@remotion/cli/config';

// Source art lives in assets/ (assets/icon/icon-default.jpg etc.), served via staticFile().
Config.setPublicDir('./assets');
Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
