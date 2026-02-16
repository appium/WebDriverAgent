import {JWProxy} from '@appium/base-driver';
import type {ProxyOptions} from '@appium/types';

export class NoSessionProxy extends JWProxy {
  constructor(opts: ProxyOptions = {}) {
    super(opts);
  }

  override getUrlForProxy(url: string): string {
    if (url === '') {
      url = '/';
    }
    const proxyBase = `${this.scheme}://${this.server}:${this.port}${this.base}`;
    let remainingUrl = '';
    if (new RegExp('^/').test(url)) {
      remainingUrl = url;
    } else {
      throw new Error(`Did not know what to do with url '${url}'`);
    }
    remainingUrl = remainingUrl.replace(/\/$/, ''); // can't have trailing slashes
    return proxyBase + remainingUrl;
  }
}
