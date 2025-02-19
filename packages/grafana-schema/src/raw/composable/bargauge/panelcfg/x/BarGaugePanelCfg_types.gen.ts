// Code generated - EDITING IS FUTILE. DO NOT EDIT.
//
// Generated by:
//     public/app/plugins/gen.go
// Using jennies:
//     TSTypesJenny
//     PluginTsTypesJenny
//
// Run 'make gen-cue' from repository root to regenerate.

import * as common from '@grafana/schema';

export const pluginVersion = "11.5.3";

export interface Options extends common.OptionsWithLegend, common.SingleStatBaseOptions {
  displayMode: common.BarGaugeDisplayMode;
  maxVizHeight: number;
  minVizHeight: number;
  minVizWidth: number;
  namePlacement: common.BarGaugeNamePlacement;
  showUnfilled: boolean;
  sizing: common.BarGaugeSizing;
  valueMode: common.BarGaugeValueMode;
}

export const defaultOptions: Partial<Options> = {
  displayMode: common.BarGaugeDisplayMode.Gradient,
  maxVizHeight: 300,
  minVizHeight: 16,
  minVizWidth: 8,
  namePlacement: common.BarGaugeNamePlacement.Auto,
  showUnfilled: true,
  sizing: common.BarGaugeSizing.Auto,
  valueMode: common.BarGaugeValueMode.Color,
};
