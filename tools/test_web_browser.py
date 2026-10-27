#!/usr/bin/env python3
"""Browser checks for CI/portable development; managed preview uses cua_repl."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading


def main():
    if os.environ.get('SITES_MANAGED_LINUX_CONTAINER') == '1':
        raise SystemExit('Managed preview must be inspected with the cloud browser; this runner is for CI or portable development.')
    from playwright.sync_api import sync_playwright, expect
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, default=Path('dist/web'))
    parser.add_argument('--output', type=Path, default=Path('dist/web-checks'))
    args = parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    handler = partial(SimpleHTTPRequestHandler,directory=str(args.bundle.resolve()))
    server = ThreadingHTTPServer(('127.0.0.1',0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}/'
    report = {'cases': [], 'scope':'Software WebGL on the CI runner; no physical mobile device or performance claim.'}
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(args=['--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
            for name,options in [('desktop',{'viewport':{'width':1280,'height':720}}),('touch',{'viewport':{'width':960,'height':600},'has_touch':True,'is_mobile':True})]:
                context = browser.new_context(**options)
                page = context.new_page()
                errors, logs = [], []
                page.on('pageerror',lambda error:errors.append(str(error)))
                page.on('console',lambda message:logs.append(message.text))
                page.goto(url)
                page.get_by_role('button',name='Hrát',exact=True).click()
                try:
                    expect(page.locator('body')).to_have_attribute('data-game-state','ready',timeout=120000)
                except Exception:
                    page.screenshot(path=str(args.output/f'{name}-failure.png'))
                    (args.output/f'{name}-console.json').write_text(json.dumps({'errors':errors,'logs':logs},ensure_ascii=False,indent=2))
                    raise
                frames = int(page.locator('body').get_attribute('data-scene-frames'))
                assert frames > 0
                assert not errors, errors
                assert not any('SCRIPT ERROR' in text or 'Parse Error' in text for text in logs), logs
                expect(page.locator('#canvas')).to_be_visible()
                values = page.locator('#capabilities dd').all_text_contents()
                assert values[0] == ('dostupné' if name=='touch' else 'nezjištěno'), values
                page.screenshot(path=str(args.output/f'{name}.png'))
                report['cases'].append({'name':name,'passed':True,'scene_frames':frames,'capabilities':values,'page_errors':errors,'logs':logs})
                context.close()
            for name,setup,route,message in [
                ('no-webgl',"const original=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(kind,...args){return kind==='webgl2'?null:original.call(this,kind,...args)}",None,'nepodporuje potřebnou 3D grafiku'),
                ('no-wasm',"Object.defineProperty(window,'WebAssembly',{value:undefined})",None,'nepodporuje spuštění hry'),
                ('missing-engine',None,'**/index.js','Hru se nepodařilo načíst'),
                ('missing-pack',None,'**/index.pck','Hru se nepodařilo načíst'),
            ]:
                context = browser.new_context()
                if setup: context.add_init_script(setup)
                page = context.new_page()
                if route: page.route(route,lambda request:request.abort())
                page.goto(url)
                page.get_by_role('button',name='Hrát',exact=True).click()
                expect(page.locator('body')).to_have_attribute('data-game-state','error',timeout=120000)
                expect(page.locator('#status')).to_contain_text(message)
                expect(page.get_by_role('button',name='Zkusit znovu',exact=True)).to_be_enabled()
                page.screenshot(path=str(args.output/f'{name}.png'))
                report['cases'].append({'name':name,'passed':True,'status':page.locator('#status').inner_text()})
                context.close()
            browser.close()
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        server.shutdown()
        (args.output/'browser-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__': main()
