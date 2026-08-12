import test from 'node:test';
import assert from 'node:assert/strict';
import {initDisclosure} from '../src/disclosure.mjs';

function fixture() {
  const handlers = {};
  const button = {attrs: {}, setAttribute(k,v){this.attrs[k]=v}, getAttribute(k){return this.attrs[k]}, addEventListener(k,v){handlers[k]=v}};
  const panel = {hidden:false};
  return {document:{getElementById:id=>id==='toggle'?button:panel},button,panel,click:()=>handlers.click()};
}
test('initializes and toggles both contracts',()=>{const f=fixture();initDisclosure(f.document);assert.equal(f.panel.hidden,true);assert.equal(f.button.attrs['aria-expanded'],'false');f.click();assert.equal(f.panel.hidden,false);assert.equal(f.button.attrs['aria-expanded'],'true');});
