import { Battery, BatteryLow } from 'lucide-react';
import { cn } from '../lib/cn.ts';

export function HarnessBattery({percent, reportedAt, offline = false}: {
  percent: number | null | undefined; reportedAt?: string | null; offline?: boolean;
}) {
  const valid = typeof percent === 'number' && Number.isFinite(percent) && percent >= 0 && percent <= 100;
  const low = valid && percent <= 15;
  const Icon = low ? BatteryLow : Battery;
  const time = reportedAt && !Number.isNaN(Date.parse(reportedAt)) ? new Date(reportedAt).toLocaleString() : null;
  const text = `Harness battery: ${valid ? `${Math.round(percent)}%${low ? ' · Low' : ''}` : 'Unavailable'}${offline ? ' · Offline' : ''}`;
  return <span role="status" aria-label={text} title={valid ? `Last reported${time ? `: ${time}` : ' battery value'}. ${offline ? 'Harness is offline; this is not a live reading.' : ''}` : 'No valid battery reading has been received from this harness.'} className={cn('inline-flex max-w-full items-center gap-1.5 text-xs', low ? 'text-high-fg font-semibold' : 'text-ink-muted')}><Icon size={15} aria-hidden="true" className="shrink-0"/><span>{text}</span></span>;
}
