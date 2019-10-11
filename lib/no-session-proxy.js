import { JWProxy } from 'appium-base-driver';


class NoSessionProxy extends JWProxy {
  constructor (opts = {}) {
    super(opts);
  }

  getUrlForProxy (url) {
    if (url === '') {
      url = '/';
    }
    const proxyBase = `${this.scheme}://${this.server}:${this.port}${this.base}`;
    let remainingUrl = '';
    if ((new RegExp('^/')).test(url)) {
      remainingUrl = url;
    } else {
      throw new Error(`Did not know what to do with url '${url}'`);
    }
    remainingUrl = remainingUrl.replace(/\/$/, ''); // can't have trailing slashes
    return proxyBase + remainingUrl;
  }
}

export { NoSessionProxy };
export default NoSessionProxy;
