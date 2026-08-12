import fs from 'node:fs';
import path from 'node:path';
const root=process.argv[2], html=fs.readFileSync(path.join(root,'src/index.html'),'utf8'), css=fs.readFileSync(path.join(root,'src/styles.css'),'utf8'), test=fs.readFileSync(path.join(root,'tests/disclosure.test.mjs'),'utf8');
const need=(ok,msg)=>{if(!ok)throw new Error(`QUALITY FAIL: ${msg}`)};
need(/<button[^>]+id="toggle"[^>]+aria-controls="details"[^>]+aria-expanded="false"/i.test(html),'semantic controlled button');
need(/<section[^>]+id="details"[^>]+hidden/i.test(html),'initially hidden panel');
need(/focus-visible/.test(css),'visible keyboard focus');need(/@media[^{}]*max-width\s*:\s*600px/s.test(css),'600px responsive rule');
need(!/test\(['"]placeholder/.test(test),'placeholder test removed');need(/assert\./.test(test),'behavioral assertion present');
console.log('FRONTEND QUALITY PASS');
