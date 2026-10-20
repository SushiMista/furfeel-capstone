import {render, screen} from '@testing-library/react';
import {expect, it} from 'vitest';
import {HarnessBattery} from '../src/components/HarnessBattery.tsx';
it('shows a measured percentage and identifies the harness', () => {
 render(<HarnessBattery percent={82}/>); expect(screen.getByRole('status')).toHaveTextContent('Harness battery: 82%');
});
it('keeps zero distinct from unavailable and marks low battery', () => {
 render(<HarnessBattery percent={0} offline/>); expect(screen.getByRole('status')).toHaveTextContent('0% · Low · Offline');
});
it.each([null, undefined, NaN, 101, -1])('does not display invalid or missing battery %s as zero', (percent) => {
 render(<HarnessBattery percent={percent}/>); expect(screen.getByRole('status')).toHaveTextContent('Unavailable');
});
