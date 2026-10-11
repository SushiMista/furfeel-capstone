import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(path.resolve('apps/dashboard/package.json'));
const { createServer } = require('vite');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const { chromium } = require('C:/Users/j3mal/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const server = await createServer({ root: path.resolve('apps/dashboard'), server: { middlewareMode: true } });
let browser;
try {
  const { Dialog } = await server.ssrLoadModule('/src/components/ui/dialog.tsx');
  const assets = await fs.readdir('apps/dashboard/dist/assets');
  const css = await fs.readFile(path.join('apps/dashboard/dist/assets', assets.find(f => f.endsWith('.css'))), 'utf8');
  const children = React.createElement('form', { className: 'flex flex-col gap-4' },
    ...Array.from({ length: 16 }, (_, i) => React.createElement('label', { key: i }, `Report field ${i + 1}`,
      React.createElement('textarea', { className: 'w-full rounded border p-3', rows: 3 }))),
    React.createElement('div', { className: 'sticky bottom-0 flex flex-wrap justify-end gap-2 bg-surface py-3' },
      React.createElement('button', { type: 'button' }, 'Cancel'),
      React.createElement('button', { type: 'submit' }, 'Submit Report to Admin')));
  const markup = renderToStaticMarkup(React.createElement(Dialog, { open: true, title: 'Help & Issue Reporting', onClose() {}, className: 'max-w-2xl' }, children));
  browser = await chromium.launch({ headless: true, channel: 'msedge' });
  const page = await browser.newPage();
  for (const [width, height] of [[320,568],[390,844],[768,1024],[1366,768],[844,390]]) {
    await page.setViewportSize({ width, height });
    await page.setContent(`<style>${css}\n.opacity-0 {opacity:1!important} .scale-95 {transform:none!important}</style>${markup}`);
    const result = await page.evaluate(() => {
      const dialog = document.querySelector('[role="dialog"]');
      const scroll = dialog.lastElementChild;
      const bounds = dialog.getBoundingClientRect();
      const close = dialog.querySelector('[aria-label="Close"]').getBoundingClientRect();
      const submit = dialog.querySelector('[type="submit"]');
      scroll.scrollTop = scroll.scrollHeight;
      const action = submit.getBoundingClientRect();
      return { fits: bounds.x >= 0 && bounds.y >= 0 && bounds.right <= innerWidth && bounds.bottom <= innerHeight,
        closeVisible: close.y >= 0 && close.bottom <= innerHeight,
        submitVisible: action.y >= 0 && action.bottom <= innerHeight,
        noHorizontalOverflow: scroll.scrollWidth <= scroll.clientWidth + 1,
        scrollable: scroll.scrollHeight > scroll.clientHeight };
    });
    if (Object.values(result).some(value => !value)) throw new Error(`${width}x${height}: ${JSON.stringify(result)}`);
    console.log(`${width}x${height}: viewport fit, close/submit visible, vertical scrolling, no horizontal overflow`);
  }
} finally {
  await browser?.close();
  await server.close();
}
